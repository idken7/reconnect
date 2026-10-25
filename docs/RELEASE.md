# Releasing the Reconnect mobile app

## Environments and API hosts

The environment is chosen at build time:

| Build | Default flavor | API base URL |
|-------|----------------|--------------|
| `flutter run` (debug/profile) | `dev` | `http://localhost:8080` (`http://10.0.2.2:8080` on the Android emulator) |
| `flutter build ... --release` | `prod` (automatic) | `https://api.reconnect.app` |
| `--dart-define=FLAVOR=staging` | `staging` | `https://staging-api.reconnect.app` |

Overrides: `--dart-define=FLAVOR=dev|staging|prod` and
`--dart-define=RECONNECT_API_BASE_URL=https://...`. Release builds refuse
`FLAVOR=dev` and any non-https URL and fail at startup with a clear error.

**`api.reconnect.app` and `staging-api.reconnect.app` are placeholders.**
Replace `kProductionApiBaseUrl` / `kStagingApiBaseUrl` in
`lib/config/environment.dart` (or always pass `RECONNECT_API_BASE_URL`) with the
real deployed hosts before any store build.

Demo data: the "Try demo" button and its sample contacts exist only when
`kReleaseMode` is false. Release builds never show them; if the backend is
unreachable the app shows an offline state with Retry.

## Android

1. Create an upload keystore once, outside the repo, and back it up:

   ```sh
   keytool -genkey -v -keystore ~/reconnect-upload.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (gitignored, never commit it):

   ```properties
   storePassword=<store password>
   keyPassword=<key password>
   keyAlias=upload
   storeFile=/Users/you/reconnect-upload.jks
   ```

3. Build the bundle: `./scripts/build_release_android.sh 0.1.0 1`
   (optionally `FLAVOR=staging` or `RECONNECT_API_BASE_URL=...`). The script and
   Gradle both fail without `key.properties`. A plain `flutter run --release`
   without it falls back to the debug key and prints a warning; never upload that.

R8/minify and resource shrinking are on; rules are in
`android/app/proguard-rules.pro`. Keep `build/app/outputs/mapping` and
`build/symbols/android` for each uploaded build. Release manifests have the
INTERNET permission and cleartext HTTP is blocked (only debug/profile manifests
allow it for the local server). Play Console: enrol in Play App Signing; fill
the Data safety form and the `READ_CONTACTS` permission declaration.

**Not verified here:** this machine has no Android SDK, so the Gradle changes
(signing, R8 and the ProGuard rules) have not been built. Run
`./scripts/build_release_android.sh` and install the result on a device before
trusting them.

## iOS

`./scripts/build_testflight.sh 0.1.0 1` builds with `FLAVOR=prod`
(`FLAVOR=staging` supported), then archive in Xcode or use
`scripts/upload_to_testflight.sh`.

Needs your Apple account (not done in the repo):

- Team ID and automatic/manual signing in Xcode (Runner target > Signing).
- Confirm `com.reconnect.reconnect` is a bundle id you own (or change it).
- Create the App Store Connect record, privacy nutrition labels (Contacts,
  Location, Name, Email, Phone, User ID, User Content: linked to the user, not
  used for tracking), account-deletion path, and review notes.
- Export compliance: `ITSAppUsesNonExemptEncryption` is deliberately not set;
  decide the answer (HTTPS-only is normally exempt) and add it if you want to skip
  the prompt on every upload.

Privacy manifest: `ios/Runner/PrivacyInfo.xcprivacy` is registered in the Runner
target's resources. It declares the collected data types and the required-reason
API categories used by Flutter and the plugins (UserDefaults CA92.1, file
timestamp C617.1, system boot time 35F9.1, disk space E174.1). Location is
declared as coarse because the app requests low accuracy; add precise location
if that changes. In Xcode Organizer, "Generate Privacy Report" on the archive and
check it matches. There is no `NSAppTransportSecurity` override; ATS is at
defaults. The iOS deployment target was raised to 15.0 because current Xcode
rejects 13.0.

## Dependencies

Upgraded: geolocator 12 > 14, google_fonts 6 > 8, share_plus 13.3, shared_preferences
2.5.6, flutter_lints 6. Added `flutter_secure_storage` 11. Removed
`permission_handler` (declared but never imported; permissions are requested
through `flutter_contacts` and `geolocator`).

Left behind: `cupertino_icons` 2.0 (the Flutter SDK constraint holds it at 1.x),
`flutter_contacts` (vendored, below), mockito 5.8 and build_runner 2.17 (dev only,
`flutter pub outdated` lists them as newer than what resolves), and transitive
packages that are not direct dependencies. Pin the Flutter version in CI
(`flutter-version:` in the workflow; `.github/` was out of scope here).

### Why `third_party/flutter_contacts` is vendored

It is upstream `flutter_contacts` 1.1.9+2 with one change, in
`ios/Classes/SwiftFlutterContactsPlugin.swift`: the root view controller is resolved
through `UIApplication.connectedScenes` instead of
`UIApplication.shared.delegate!.window!!`. The app uses `SceneDelegate`, where the
app delegate's `window` is nil, so upstream crashes force-unwrapping it when the
contact picker is shown. Upstream (QuisApp/flutter_contacts) 1.1.9+2 is the last
1.x release; drop the fork if a newer release handles scenes, then remove the
`dependency_overrides` entry. The generated `doc/api` HTML (2.7 MB, nothing
referenced it) was deleted.

## Checks before a release

```sh
flutter analyze --fatal-infos
flutter test
flutter build ios --debug --no-codesign
flutter build apk --debug
```

Run a release build against staging and walk through sign up, verify, import,
log out, log in, and delete account.
