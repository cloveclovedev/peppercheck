# PepperCheck Flutter client

The Flutter application targets iOS and Android and uses Riverpod, Freezed,
GoRouter, slang, Dio, Firebase Authentication, and the shared project UI
foundations.

The client is in a staged migration. Authentication and the internal-user
boundary use Firebase and the Go API. Several feature repositories still use
Supabase until their Go API phases land. Do not add new direct Supabase access.

## Run locally

The repository-level launcher starts the backend and selected device:

```sh
scripts/dev-run.sh --ios
scripts/dev-run.sh --android
```

For a client-only session with an already running backend:

```sh
cd peppercheck_flutter
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart
```

Platform Firebase configuration is local and must not be committed. See the
[repository getting-started guide](../docs/getting-started.md) for the complete
path and port overrides.

## Verify changes

```sh
flutter analyze
flutter test
```

Generated Riverpod, Freezed, JSON, slang, and asset files must be regenerated
with the project's pinned dependencies when their sources change.
