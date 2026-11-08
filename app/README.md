# Spending Tracker (native app)

One Flutter codebase for **Android, Windows and macOS**. It reads your Wise MYR balance and transactions with a read-only API token and shows where your money goes. There's no server: each device talks to Wise directly, and the token stays in that device's secure storage.

## Get the app

Open the repo's **Actions** tab, pick the latest **App** run, and download from **Artifacts**:

| Platform | File | First run |
|---|---|---|
| Android | `SpendingTracker-android-arm64.apk` (almost every phone; `arm32` is for very old ones) | Allow installing from your browser or file manager when Android asks. |
| Windows | `SpendingTracker-windows.zip` | Unzip anywhere and run `SpendingTracker.exe`. If SmartScreen warns, choose **More info**, then **Run anyway**. |
| macOS | `SpendingTracker-macos.zip` (version tags and manual runs only) | The app isn't signed, so the first time, right-click it and choose **Open**. |

Pushing a tag such as `v1.0.0` builds all three and attaches them to a GitHub release.

## First run

1. On wise.com, go to **Settings**, then **Integrations and tools**, then **API tokens**, and add a token with **Read only** access.
2. Paste it into the app and tap **Connect**.

The app checks the token with Wise before saving it. To change or remove it later, use the **⋮** menu.

## How it behaves

- **Opens instantly:** it shows the last data it saved while fresh data loads.
- **Refreshing:** it refreshes when it opens and when you come back to it (if the data is over 5 minutes old). You can also pull down, tap ↻, or press F5 / Ctrl+R on a computer.
- **Pay cycles:** "Left" counts down to the next payday (the 7th or the 22nd). The month summary runs from the 7th to the 6th. Both are set in `lib/src/domain/cycles.dart`.
- **Categories:** keywords in the merchant name pick the category, in `lib/src/domain/categories.dart`.

## Develop

Needs Flutter 3.47.9 (stable). CI uses the same version.

```bash
flutter pub get
flutter run                                  # pick a device
flutter run --dart-define=FAKE_DATA=true     # made-up data, no token needed
flutter test                                 # unit and widget tests
flutter analyze
```

To test against the fake Wise server from a desktop build, run `python3 ../dev/mockwise.py`, then start the app with `--dart-define=WISE_API=http://127.0.0.1:9999` and use the token `good`.

### Code layout

| Path | What's there |
|---|---|
| `lib/src/domain/` | Pure Dart: models (money in sen), Wise JSON parsing, categories, pay cycles, summaries, formatting |
| `lib/src/data/` | The Wise API client, secure token storage, the on-device cache, fake data |
| `lib/src/app_controller.dart` | App state (`ChangeNotifier`), with derived numbers worked out once per change |
| `lib/src/ui/` | Theme, shared widgets, dashboard, full-list pages, setup, settings |
| `test/` | Domain unit tests, controller tests, and widget tests on three screen sizes |

### Android signing (optional, recommended)

Without your own key, each CI build is signed with a throwaway debug key, so installing a newer APK over an older one fails and you have to uninstall first (and paste the token again). To fix that once:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload-keystore.jks   # on a Mac: base64 -i upload-keystore.jks
```

Then add four repository secrets (**Settings**, then **Secrets and variables**, then **Actions**): `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`), and `ANDROID_KEY_PASSWORD`. Keep the `.jks` file somewhere safe and never commit it.

### Icons

The source images are in `assets/icon/`; they aren't bundled into the app. Regenerate the platform icons with `dart run flutter_launcher_icons`.
