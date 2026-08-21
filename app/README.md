# yukitas

YUKITAS snow removal matching app

## Firebase

The default development build connects to the Firebase project `yukitas-app`.
Email/password and Google authentication are enabled through the checked-in
`firebase.json`. Android development signing fingerprints are registered and
`android/app/google-services.json` configures the native SDK.

Firebase client identifiers are public app configuration, not server secrets.
For a future staging or production project, override them with
`--dart-define-from-file=firebase_options.local.json` using
`firebase_options.example.json` as the template.

### Request photos

Before/after request photos are stored as private Firebase Storage objects.
The Firestore document contains the authenticated Storage path rather than a
public download URL. Uploads accept JPEG, PNG, or WebP images up to 10 MB.

Cloud Storage is initialized for `yukitas-app`, and the checked-in rules are
deployed to its default bucket. Firebase-connected builds therefore enable
request photos by default:

```powershell
firebase deploy --only storage
flutter run
```

For an offline/demo build, pass `--dart-define=YUKITAS_STORAGE_ENABLED=false`
to keep using the bundled photos instead of Firebase Storage.

### Open requests and the public board

A request lives in two places. `requests/{id}` holds everything — the exact
coordinate, the address, the photo paths — and Firestore rules restrict it to
the request's owner and its assigned worker. `requestBoard/{id}` is the
public projection every signed-in user may read, written only by the
`syncRequestBoard` Cloud Function.

The split exists because Firestore rules grant or deny a *whole document*:
a request that every worker can read is a request whose address and photos
every worker can read. The board therefore carries a geohash cell center
(roughly a kilometre of blur) instead of a coordinate, and no address, no
photos and no SOS reason — satisfying acceptance criterion AC-08,
"未受注ユーザーは正確な住所・画像へアクセスできない".

Two consequences worth knowing:

- **Distance is computed, not stored.** It is measured from the worker's own
  position to the published cell center, so it is always shown as 約N km.
  There is deliberately no `distanceKm` field on a request.
- **Accepting does not require reading.** `accept()` is a blind `update()`;
  the `workerAccepts()` rule evaluates `status == 'waiting' && workerId ==
  null` server-side, so two workers racing still leaves exactly one winner.

### Request lifecycle

Beyond the main flow, a request can leave `waiting` or an assignment without
being completed:

| Transition | Who | When |
| --- | --- | --- |
| → `cancelled` | 依頼者 | Any time up to `arrived`, with a reason |
| → `waiting` | 担当ワーカー | From `matched`/`moving` — hands the job back |
| → `expired` | サーバー | `waiting` for over 6 hours (`expireStaleRequests`) |
| `disputed` → `completed`/`cancelled` | 運営のみ | Via the `resolveDispute` callable |

`resolveDispute` requires an `admin: true` custom claim and is the only way
out of `disputed`; no client rule permits that transition, so a payment can
never be left frozen with nobody able to settle it.

To grant (or revoke) that claim:

```powershell
gcloud auth application-default login   # once per machine
cd functions
npm run set-admin -- someone@example.com           # grant
npm run set-admin -- someone@example.com --revoke  # revoke
npm run set-admin -- --list                        # list current admins
```

The account must sign out and back in before the claim takes effect - it is
cached in the ID token.

### Snowfall forecast

The home screen's forecast card and the family heavy-snow push notification
(spec 06.2) are backed by `weatherSnapshots/niigata-shi`, refreshed every 3
hours by the `refreshWeatherSnapshot` Cloud Function from
[Open-Meteo](https://open-meteo.com/) (no API key required). Deploy it like
any other function:

```powershell
firebase deploy --only functions:refreshWeatherSnapshot,functions:notifyFamilyOnHeavySnowfall
```

Scheduled functions require the Blaze plan, same as `analyzeSnowPhoto`.
Without Firebase, the app falls back to the fixed demo forecast (-2℃, 30cm).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
