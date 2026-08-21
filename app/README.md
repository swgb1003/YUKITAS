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
