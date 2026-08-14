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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
