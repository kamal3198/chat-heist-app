# Flutter Firebase Client Setup

The app now uses Firebase SDK directly for auth.

## Required setup
1. Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```
2. Configure Firebase for this app:
```bash
cd flutter_app
flutterfire configure
```
3. This generates `lib/firebase_options.dart` and platform Firebase config files.

## Alternative (without generated file)
You can run the app with `--dart-define` values:
- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET` (optional)

Example:
```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=API_BASE_URL=http://YOUR_IP:3000
```

## Auth flow now
- Email/password signup and login use FirebaseAuth in Flutter.
- Google sign-in uses `google_sign_in` + FirebaseAuth.
- After Firebase sign-in, app calls backend `/auth/firebase` with ID token to create/update profile and device session.
