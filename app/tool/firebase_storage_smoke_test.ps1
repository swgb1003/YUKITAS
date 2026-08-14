Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectId = 'yukitas-app'
$bucket = 'yukitas-app.firebasestorage.app'
$firebaseOptionsPath = Join-Path $PSScriptRoot '..\firebase_options.local.json'
$photoPath = Join-Path $PSScriptRoot '..\assets\images\before_driveway.png'
$firebaseOptions = Get-Content -LiteralPath $firebaseOptionsPath -Raw -Encoding utf8 | ConvertFrom-Json
$apiKey = $firebaseOptions.YUKITAS_FIREBASE_API_KEY
$appId = $firebaseOptions.YUKITAS_FIREBASE_WEB_APP_ID

$suffix = "{0}-{1}" -f [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(), ([guid]::NewGuid().ToString('N').Substring(0, 8))
$requestId = "codex-storage-smoke-$suffix"
$email = "codex-storage-smoke-$suffix@example.com"
$password = "Yukitas!$([guid]::NewGuid().ToString('N'))Aa1"
$downloadPath = Join-Path ([System.IO.Path]::GetTempPath()) "$requestId.png"

$idToken = $null
$userId = $null
$objectPath = $null
$requestCreated = $false
$objectCreated = $false
$testError = $null
$cleanupErrors = @()

function Invoke-JsonRequest {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)]$Body,
    [hashtable]$Headers = @{}
  )

  Invoke-RestMethod `
    -Uri $Uri `
    -Method $Method `
    -Headers $Headers `
    -ContentType 'application/json; charset=utf-8' `
    -Body ($Body | ConvertTo-Json -Depth 30 -Compress)
}

function Get-WebErrorMessage {
  param([Parameter(Mandatory = $true)]$ErrorRecord)

  $details = $ErrorRecord.ErrorDetails.Message
  if (-not [string]::IsNullOrWhiteSpace($details)) {
    return "$($ErrorRecord.Exception.Message) Response: $details"
  }

  $response = $ErrorRecord.Exception.Response
  if ($null -ne $response) {
    try {
      $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
      try {
        $body = $reader.ReadToEnd()
        if (-not [string]::IsNullOrWhiteSpace($body)) {
          return "$($ErrorRecord.Exception.Message) Response: $body"
        }
      } finally {
        $reader.Dispose()
      }
    } catch {
      # Fall back to the exception message below.
    }
  }
  return $ErrorRecord.Exception.Message
}

function Remove-TestRequest {
  if (-not $requestCreated) { return }
  $output = & firebase firestore:delete "requests/$requestId" --force --project $projectId 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Could not delete the temporary Firestore request: $($output -join ' ')"
  }
  $script:requestCreated = $false
}

function Remove-TestObject {
  if (-not $objectCreated -or [string]::IsNullOrWhiteSpace($idToken)) { return }
  $encodedObjectPath = [System.Uri]::EscapeDataString($objectPath)
  $deleteUri = "https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedObjectPath"
  $headers = @{ Authorization = "Firebase $idToken" }
  $lastError = $null
  foreach ($attempt in 1..30) {
    try {
      Invoke-WebRequest -Uri $deleteUri -Method Delete -Headers $headers -UseBasicParsing | Out-Null
      $script:objectCreated = $false
      return
    } catch {
      $lastError = Get-WebErrorMessage $_
      Start-Sleep -Seconds 1
    }
  }
  throw $lastError
}

function Remove-TestUser {
  if ([string]::IsNullOrWhiteSpace($idToken)) { return }
  $deleteUserUri = "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$apiKey"
  Invoke-JsonRequest -Uri $deleteUserUri -Method Post -Body @{ idToken = $idToken } | Out-Null
  $script:idToken = $null
}

try {
  $signUpUri = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey"
  $signUp = Invoke-JsonRequest -Uri $signUpUri -Method Post -Body @{
    email = $email
    password = $password
    returnSecureToken = $true
  }
  $idToken = $signUp.idToken
  $userId = $signUp.localId
  if ([string]::IsNullOrWhiteSpace($idToken) -or [string]::IsNullOrWhiteSpace($userId)) {
    throw 'Firebase Authentication did not return the expected credentials.'
  }

  $objectPath = "requestMedia/$requestId/before/$userId/smoke.png"
  $metadata = @{
    name = $objectPath
    cacheControl = 'private,max-age=3600'
    contentType = 'image/png'
    metadata = @{
      requestId = $requestId
      kind = 'before'
      uploaderId = $userId
    }
  } | ConvertTo-Json -Depth 10 -Compress

  $boundary = "yukitas-$([guid]::NewGuid().ToString('N'))"
  $prefixText = "--$boundary`r`nContent-Type: application/json; charset=utf-8`r`n`r`n$metadata`r`n--$boundary`r`nContent-Type: image/png`r`n`r`n"
  $suffixText = "`r`n--$boundary--"
  $prefixBytes = [System.Text.Encoding]::UTF8.GetBytes($prefixText)
  $photoBytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $photoPath))
  $suffixBytes = [System.Text.Encoding]::UTF8.GetBytes($suffixText)
  $uploadBody = New-Object byte[] ($prefixBytes.Length + $photoBytes.Length + $suffixBytes.Length)
  [System.Array]::Copy($prefixBytes, 0, $uploadBody, 0, $prefixBytes.Length)
  [System.Array]::Copy($photoBytes, 0, $uploadBody, $prefixBytes.Length, $photoBytes.Length)
  [System.Array]::Copy($suffixBytes, 0, $uploadBody, $prefixBytes.Length + $photoBytes.Length, $suffixBytes.Length)

  $uploadUri = "https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=$([System.Uri]::EscapeDataString($objectPath))"
  $storageHeaders = @{
    Authorization = "Firebase $idToken"
    'X-Firebase-GMPID' = $appId
    'X-Firebase-Storage-Version' = 'webjs/yukitas-smoke'
    'X-Goog-Upload-Protocol' = 'multipart'
  }
  $uploadResponse = Invoke-RestMethod `
    -Uri $uploadUri `
    -Method Post `
    -Headers $storageHeaders `
    -ContentType "multipart/related; boundary=$boundary" `
    -Body $uploadBody
  if ($uploadResponse.name -ne $objectPath) {
    throw 'Firebase Storage returned an unexpected object path.'
  }
  $objectCreated = $true
  Write-Host 'STORAGE_UPLOAD=PASS'

  function Firestore-Value([string]$Type, $Value) {
    $result = @{}
    $result[$Type] = $Value
    return $result
  }

  $documentName = "projects/$projectId/databases/(default)/documents/requests/$requestId"
  $fields = @{
    schemaVersion = Firestore-Value 'integerValue' '1'
    ownerId = Firestore-Value 'stringValue' $userId
    placeName = Firestore-Value 'stringValue' 'Storage smoke test'
    approximateAddress = Firestore-Value 'stringValue' 'Niigata'
    workAreas = @{ arrayValue = @{ values = @((Firestore-Value 'stringValue' 'entrance')) } }
    areaSqm = Firestore-Value 'doubleValue' 18.0
    snowDepthCm = Firestore-Value 'integerValue' '25'
    difficulty = Firestore-Value 'integerValue' '3'
    estimatedMinutes = Firestore-Value 'integerValue' '45'
    priceYen = Firestore-Value 'integerValue' '3200'
    distanceKm = Firestore-Value 'doubleValue' 0.8
    isSos = Firestore-Value 'booleanValue' $false
    sosReason = Firestore-Value 'nullValue' $null
    beforeImageAsset = Firestore-Value 'stringValue' $objectPath
    status = Firestore-Value 'stringValue' 'waiting'
    workerId = Firestore-Value 'nullValue' $null
    workerName = Firestore-Value 'nullValue' $null
    acceptedAt = Firestore-Value 'nullValue' $null
    movingAt = Firestore-Value 'nullValue' $null
    arrivedAt = Firestore-Value 'nullValue' $null
    safetyConfirmedAt = Firestore-Value 'nullValue' $null
    startedAt = Firestore-Value 'nullValue' $null
    afterImageAsset = Firestore-Value 'nullValue' $null
    workMemo = Firestore-Value 'nullValue' $null
    submittedAt = Firestore-Value 'nullValue' $null
    completedAt = Firestore-Value 'nullValue' $null
    paymentStatus = Firestore-Value 'stringValue' 'authorized'
    rating = Firestore-Value 'nullValue' $null
    ratingComment = Firestore-Value 'nullValue' $null
  }
  $commitBody = @{
    writes = @(@{
      update = @{ name = $documentName; fields = $fields }
      currentDocument = @{ exists = $false }
      updateTransforms = @(
        @{ fieldPath = 'createdAt'; setToServerValue = 'REQUEST_TIME' },
        @{ fieldPath = 'updatedAt'; setToServerValue = 'REQUEST_TIME' }
      )
    })
  }
  $firestoreHeaders = @{ Authorization = "Bearer $idToken" }
  $commitUri = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:commit"
  Invoke-JsonRequest -Uri $commitUri -Method Post -Body $commitBody -Headers $firestoreHeaders | Out-Null
  $requestCreated = $true
  Write-Host 'FIRESTORE_LINK=PASS'

  $encodedObjectPath = [System.Uri]::EscapeDataString($objectPath)
  $metadataUri = "https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedObjectPath"
  $downloadUri = "https://firebasestorage.googleapis.com/v0/b/$bucket/o/${encodedObjectPath}?alt=media"
  $downloadHeaders = @{ Authorization = "Firebase $idToken" }
  try {
    Invoke-RestMethod -Uri $metadataUri -Method Get -Headers $downloadHeaders | Out-Null
    Write-Host 'STORAGE_AUTHENTICATED_METADATA_READ=PASS'
  } catch {
    throw "Authenticated metadata read failed. $(Get-WebErrorMessage $_)"
  }
  try {
    Invoke-WebRequest -Uri $downloadUri -Method Get -Headers $downloadHeaders -OutFile $downloadPath -UseBasicParsing
  } catch {
    throw "Authenticated media read failed. $(Get-WebErrorMessage $_)"
  }
  $downloadedBytes = [System.IO.File]::ReadAllBytes($downloadPath)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $sourceHash = [System.BitConverter]::ToString($sha256.ComputeHash($photoBytes)).Replace('-', '')
    $downloadHash = [System.BitConverter]::ToString($sha256.ComputeHash($downloadedBytes)).Replace('-', '')
  } finally {
    $sha256.Dispose()
  }
  if ($sourceHash -ne $downloadHash) {
    throw 'The downloaded photo did not match the uploaded photo.'
  }

  Write-Host 'AUTH_CREATE=PASS'
  Write-Host 'STORAGE_AUTHENTICATED_READ=PASS'
  Write-Host 'PHOTO_HASH_MATCH=PASS'
} catch {
  $testError = $_
} finally {
  if (Test-Path -LiteralPath $downloadPath) {
    [System.IO.File]::Delete($downloadPath)
  }

  # Remove the photo while the request is still waiting. Keep each cleanup
  # independent so one failure cannot leave the test user behind and make a
  # later run harder to diagnose.
  try {
    Remove-TestObject
  } catch {
    $cleanupErrors += "Storage object: $($_.Exception.Message)"
  }
  try {
    Remove-TestRequest
  } catch {
    $cleanupErrors += "Firestore request: $($_.Exception.Message)"
  }
  try {
    Remove-TestUser
  } catch {
    $cleanupErrors += "Authentication user: $($_.Exception.Message)"
  }

  if ($cleanupErrors.Count -eq 0) {
    Write-Host 'TEST_DATA_CLEANUP=PASS'
  }
}

if ($null -ne $testError) {
  throw "Storage smoke test failed: $($testError.Exception.Message)"
}
if ($cleanupErrors.Count -gt 0) {
  throw "Temporary test data cleanup failed: $($cleanupErrors -join ' | ')"
}
