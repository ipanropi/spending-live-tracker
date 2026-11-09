# Spending Tracker: handover for Claude Code

## What this is

**There are two versions.** `app/` is the **native Flutter app** (Android, Windows, macOS), which is where work is heading: Irfan asked for one native codebase, lightweight and fast. The Go app at the repo root is the original laptop and hosted-website version. It stays until the Flutter app has worked with a real Wise token; after that, it can be retired. Both share the same money model, described below. The Go dashboard keeps the original layout described under "How it works"; the Flutter app was redesigned on 2026-11-09 around the pay period, with three tabs (see "App structure" in the Flutter section).

Irfan's personal spending tracker (Malaysia, RM). A small Go app that pulls his MYR transactions from the Wise API and shows a dashboard in the browser. It runs either on his laptop or, in hosted mode, as a private password-protected website for his other devices (Android, Windows, sometimes a Mac). It's "somewhat live": he presses **Update** and it fetches fresh data from Wise.

Focus is **tracking**, not budgeting: a quick "where am I right now" view. Deeper monthly analysis is meant to happen with AI, not on the dashboard.

**Money model (agreed with Irfan):** Wise is his spending wallet. Paydays are the 7th and the 22nd. He tops up Wise with his spending money on both paydays, so **the Wise balance is what's left**, with no budget numbers to configure. There are two horizons:
- **"Left" and the per-day and per-week pace** count down to the next payday, whichever of the 22nd or the 7th comes first (`paydays` in `main.go`, sent to the page). On a payday itself, the countdown goes to the following one, because he tops up that day.
- **The summary** (spent, categories, places, transactions, cycle picker) uses a monthly cycle from the 7th to the 6th (`payDay`).

Weeks are normal calendar weeks, Monday to Sunday, and don't follow either.

## Status (2026-11-08)

- Laptop mode is complete. It has only been tested against `dev/mockwise.py`. **It has never been run against the real Wise API.**
- Hosted mode is built (login page, home-screen manifest and icons) and tested against the mock, including in a phone-sized headless browser. **It hasn't been deployed yet.** The next step is choosing a host (Render or Cloud Run were floated; check current free tiers first) and possibly adding a Dockerfile. Irfan wants to test the real Wise token on the laptop before deploying.
- The repo is `ipanropi/spending-live-tracker`, not `spending-tracker` as first planned. CI ran green on `main` (run 42447774794) and produced the exe artifact.
- Irfan has a Wise account and has seen Integrations and tools. He hasn't confirmed that he's created an API token yet.
- A Windows build (`SpendingTracker.exe`, about 6.5 MB, from before hosted mode) was sent to him. CI builds it too.

## Files

| File | Purpose |
|---|---|
| `main.go` | The whole backend, including login. Go standard library only. Avoid `html/template`: it added about 2.5 MB to the exe. |
| `web/index.html` | Dashboard UI. Vanilla JS with no external requests: Chart.js and both charts were removed on purpose. Dark only, by Irfan's choice, with 4px corners (he dislikes heavy rounding). Colours are CSS variables on `:root`. Category bars use one colour, because without the doughnut there's nothing for colour to identify. Colour is kept for the important numbers only: "left" is `--good` (green, or `--spend` if negative), the two spent figures are `--spend` (soft red), and money in within the list is green. Spending rows in the list stay neutral. Irfan asked for "some colour, not too much" and minimal text, so lists are plain rows in simple cards (no table headers), and the overview puts each number on its own line with one short phrase per line under it. |
| `main_test.go` | `go test ./...`: pay-cycle boundaries (payday, the day before, a UTC host, the new year). CI doesn't run it yet. |
| `web/login.html` | Login page (hosted mode). The server swaps `<!--ERROR-->` for a fixed message. |
| `web/manifest.webmanifest`, `web/icon-*.png` | Home-screen app manifest and icons (180 for Apple, 192, 512 as `any` plus `maskable`). |
| `.github/workflows/build.yml` | Builds the Windows exe on every push to `main` (as an artifact) and on `v*` tags (as a release). Verified on `main`; the tag/release path is untested. |
| `dev/mockwise.py` | Fake Wise API for testing. |
| `README.md` | User-facing setup instructions. |

## How it works

Everything in `web/` is embedded into the binary with `go:embed web`. There are two modes, and `PORT` decides which one runs.

**Laptop mode** (no `PORT`)
- It listens on `127.0.0.1:8765` (local only), opens the browser, and has no login.
- It runs as a single instance. If the port is already taken, it opens the browser and exits.
- **Token:** the app reads the `WISE_TOKEN` env var first, then `wise_token.txt` next to the exe. If neither exists, it asks for the token on stdin and saves it with mode 0600. The file is gitignored.

**Hosted mode** (`PORT` set)
- It listens on `:$PORT`, reads the token only from `WISE_TOKEN`, and refuses to start unless `APP_PASSWORD` is at least 12 characters. In this mode `fail()` exits without waiting for Enter.
- **Auth:** the `protect` middleware wraps every route. Requests without a valid session get a 303 to `/login`, or a 401 JSON error for `/api/*`, which the page answers by going to `/login`. Public paths: `/login`, `/logout`, the manifest and the icons.
- **Session:** the cookie `st_session` is `<expiry unix>.<HMAC-SHA256>`. The key is SHA-256 of a version tag plus `WISE_TOKEN` plus `APP_PASSWORD`, so sessions are stateless, survive restarts, and die when either secret changes. The cookie is HttpOnly, Secure and SameSite=Lax. With "Keep me logged in" it lasts 30 days via Max-Age. Without it, it's a browser-session cookie that also expires after 12 hours.
- **Brute force:** at most 20 wrong passwords per 15 minutes globally, after which the server answers 429. Each wrong password also waits 1 second. Existing sessions keep working during a lockout. Passwords are compared as SHA-256 digests in constant time.
- **Logout:** `POST /logout` clears the cookie. The button only shows when `/api/data` returns `canLogout: true`.
- Every response gets `nosniff`, `X-Frame-Options: DENY` and `Referrer-Policy: no-referrer`. The page and API also get `Cache-Control: no-store`.

**Both modes**
- Routes are `GET /` and `GET /api/data`, plus the manifest and icons.
- **`/api/data` flow:**
  1. `GET /v2/profiles` and pick the profile whose type is `PERSONAL`. This is cached in memory.
  2. `GET /v4/profiles/{pid}/balances?types=STANDARD` and pick the `MYR` balance. Also cached.
  3. `GET /v1/profiles/{pid}/balance-statements/{bid}/statement.json?currency=MYR&type=COMPACT&intervalStart=…&intervalEnd=…`. The window runs from the start of the pay cycle 5 cycles back (the 7th at midnight, **Malaysia time** via a fixed UTC+8 zone, because hosts run on UTC) to now. The payload also carries `cycleDay` so the page uses the same payday.
- **JSON parsing** is deliberately loose (`map[string]any` with `UseNumber`), so an unexpected field shape won't break decoding.
- **Each transaction** becomes `{date, amount, name, category, note}`:
  - **amount:** negative means money out. The sign is forced to match `DEBIT` or `CREDIT`.
  - **name:** the first one present of `details.merchant.name`, then `details.recipient.name`, then `details.senderName`, then `details.description`.
  - **category:** if the amount is positive, it's "Money in". Otherwise the first keyword match in `categories` wins. If nothing matches, it uses Wise's `merchant.category`, then `TRANSFER` becomes "Transfers" and `CONVERSION` becomes "Currency exchange", and anything left is "Other".
- **Balance** comes from `endOfStatementBalance`.
- **All the maths** happens client-side in `index.html`, in the browser's local time. The pieces, in page order:
  1. A **pay-cycle picker** ("7 Nov – 6 Dec").
  2. **Overview cards.** The **number is the focal point on its own line**. Under it, **each line says one thing**:
     - **RM 365.60** / "left until 22 Nov" / "14 days left": the hero, in green, counting down to `nextPayday()`.
     - **RM 26.11** / "per day": the balance ÷ days left.
     - **RM 144.30** / "spent this week": in soft red, counting from Monday.
     - **RM 47.40** / "spent this month" / "avg RM 23.70 a day": in soft red. A past cycle reads "spent in 7 Oct – 6 Nov".

     Only the spent-this-month card shows for past cycles. Per week was dropped at his request. Layout: on a laptop, the hero takes the full width and the other three sit in a row. On a phone, the hero is full width, per day and this week sit side by side, and this month is full width (class `wide`). `fitNumbers()` shrinks a number only when it would overflow its card. Test at 360px with four-digit amounts after any layout change.
  3. **By category:** name and amount, then a bar with its %.
  4. **Top places:** name and amount, then "N times".
  5. **Transactions:** name and amount, then the day and time ("Sun, 8 Nov, 2:15 pm"), then the category.

  **List rule (Irfan's): one piece of information per line.** The first line is the name with the amount on the right (`line1()`). Each line under it (`row()`) holds one thing. Don't combine date and category, or a name and a count, on one line. Spacing is deliberately generous: `--pad` is 22px (18px on phones), `--gap` is 16px, and rows have 16px of vertical padding. He asked for it to look less crowded.

  **Previews and full views.** Items 3–5 show their top 5 on the dashboard, with a "+N more" line when there are more. Tapping a card (it has a CSS-drawn chevron) opens a full-screen view (`#sheet`, built from `SHEETS` with the data in `VIEW`):
  - **By category:** each category is a `<details>` dropdown with name and amount, then the bar and %, then "N payments". Opening one lists its places, highest first, each with "N times".
  - **All places:** every place, highest first: name and amount, then "N times", then the category.
  - **All transactions:** name and amount, then the day and time, then the category, then Wise's note if it adds something. Boilerplate "Card transaction of …" notes are hidden.

  Opening a view pushes a history entry, so the Android back gesture, the ‹ button and Escape all close it without leaving the app. Irfan asked for this tap-to-see-all behaviour and for category dropdowns sorted highest to lowest with frequency.

  Past cycles show only the spent card, categories, places and transactions. Top-ups show in the list as "Money in" but don't count as spending. All text is HTML-escaped.
- **Errors** are returned as `{"error": "..."}` with HTTP 502 and shown in a red box on the page.

## The Flutter app (`app/`)

**Status (2026-11-09):** built and tested here (`flutter analyze` clean, 97 unit and widget tests passing, screenshots checked via a throwaway web build). **Android, Windows and macOS builds happen only in CI**: this sandbox can't reach `dl.google.com`, so there's no Android SDK, and Windows and macOS builds need those OSes. **It has never run against the real Wise API.**

**Why Flutter:** it was chosen over Compose Multiplatform, React Native, .NET MAUI, Tauri and Rust (Slint). It has the most mature single codebase across Android, Windows and macOS, compiles AOT, and Dart is close to TS and Kotlin. Rust was rejected for this app: a thin Android ecosystem (secure storage, widgets) and a steep curve for no felt speed gain.

**Kept lightweight on purpose:**
- **Runtime plugins:** only `http`, `flutter_secure_storage` and `path_provider`.
- **No state-management package:** a `ChangeNotifier` plus an `InheritedNotifier` (`AppScope`).
- **No `intl`:** formatting is hand-rolled in `domain/format.dart`.
- **No bundled fonts:** each platform's system font is used.
- **Icons:** Material icons only, which are tree-shaken (1.6 MB → 9 KB).
- **No images in the app:** `AppMark` is drawn with `CustomPaint`.

Release builds use `--obfuscate --split-debug-info`, and Android ships one APK per CPU type.

**Structure:** `lib/src/domain/` is pure Dart:
- money is held as integer **sen** (cents);
- the parsing is loose, like the Go version;
- cycles, categories, summaries and formatting are all here.

`lib/src/data/` holds the Wise client (statement JSON is parsed with `compute`, off the UI thread), `TokenStore`, `StatementCache` and `FakeSource`. `lib/src/app_controller.dart` holds the state. `lib/src/ui/` holds the theme, shared widgets, the shell and its three tabs, the category and places pages, setup and settings. See `app/README.md`.

**Behaviour:**
- **Cache first:** it opens instantly with the cached statement (`statement.json` in the app support directory, written to a temp file and renamed), then refreshes.
- **Refreshing:** on launch, on resume when the data is over 5 minutes old (`AppLifecycleListener`), by pull-to-refresh, with the ↻ button, or with F5 / Ctrl+R / Cmd+R.
- **Errors:** if a refresh fails, the old data stays and a red notice appears on every tab. A rejected token offers "Update token".
- **Category and places pages:** these open as real routes, so the system back gesture works. Android predictive back is enabled.
- **Number fitting:** big numbers use `FittedBox(scaleDown)`, the Flutter equivalent of `fitNumbers()`.

**App structure (redesigned 2026-11-09, third round).** Irfan asked for an app "designed with thought", not prettier tweaks, and said earlier layout instructions no longer bind. Research first (Apple HIG layout, tab bars, typography and charts pages; Material 3 navigation; NN/g; Monzo's design writing; Copilot Money; burn-down budgets as in PocketSmith; Shneiderman's "overview first, details on demand"; Refactoring UI), then a Claude Design canvas (https://claude.ai/artifact/3M8ieRXnhnhrgEHJJ9spST: Now in two states, Activity, Spending, Category, Desktop), then the build.

**Organised around the pay period**, the thing his money actually follows. Three tabs, one question each (`ui/shell.dart`; the open tab is `AppController.tab`, an `AppTab`):
1. **Now** (`now_page.dart`), "am I OK until payday?":
   - "Updated …", ↻ and settings (sliders icon) at the top.
   - **What's left** (`Headline`), coloured by pace: "left until payday, Sun 22 Nov" / "14 days to go".
   - **Pace card** (`PaceCard`): the verdict in words, then the chart that backs it up. "On pace: RM 162 to spare" / "Spending fast: RM 96 over pace" / "Overspent by RM 20", with "RM 127 a day lasts until payday." under it.
   - **Pace chart** (`PaceChart`, a `CustomPainter`, no chart package): money left at the end of each day since the last payday, against a dashed even pace from what was there at payday down to zero on the next one, with a dot for now. Its semantics label is one sentence with the numbers.
   - **Today**: today's payments and "All activity", which switches tab.
   - Wide windows: money and pace on the left, today on the right.
2. **Activity** (`activity_page.dart`), "what did I spend?": everything loaded (6 cycles), newest first, grouped by day with each day's total. Search (name or Wise's note) and category chips (most used first; one scrolling row on phones, wrapped from 600 wide). Filtering shows "3 transactions, RM 22.00 spent". Tapping a row opens `showTxnDetails`: when, category, Wise's own name for it, and the note if it adds something.
3. **Spending** (`spending_page.dart`), "where does my money go?": one month (7th to 6th) at a time.
   - The stepper reads ‹ This month / Last month / N months ago, with the dates under it ›. It's capped at 400 wide so the arrows stay next to the label.
   - The total and its average a day.
   - **The same day last month:** "RM 185 more than last month by day 3", from `CycleSummary.previousCents`. A month in progress against a whole one would always look good. Amber when more, green when less, "About the same" within RM 1, hidden when the month before wasn't loaded.
   - **By category** (icon, amount, share bar, ›) opens `CategoryPage`: the total, its share, "4 payments at 3 places", then Places and Payments.
   - **Top places** shows 5, then "All N places" → `PlacesPage`.
   - Wide windows: categories and places side by side.

**The pace maths** (`domain/pace.dart`, `PayPeriod`):
- **available** = balance + spent since payday, so a top-up during the period counts as if it was there from the start.
- **even pace left** at the end of today = available × (days − dayNumber) / days. Measuring to the end of today, not to now, means "to spare" is what you could still spend today and stay on pace.
- **ahead** = balance − even pace left. That gives `onPace`, `fast`, `overspent` (balance < 0), or `unknown` (no balance; the card hides).
- **a day** = balance ÷ days left, today included.

**Why this structure:**
- **Two time frames, no longer on one screen.** The old dashboard put the payday period and the 7th–6th month on one screen, so it needed scope rules and a "Back to current month" button. Now Now is always today and Spending is always a month.
- **The week figure is gone.** Calendar weeks don't line up with paydays (it needed a "since Mon, 2 Nov" caveat), and pace answers "am I spending too fast?" directly.
- **A number needs a verdict.** "RM 1,780" alone doesn't say whether that's fine. HIG: every chart gets a headline that says what it shows.
- **A tab bar for 3–5 top-level places** (HIG, Material): a `NavigationBar` on phones under 600 wide, a `NavigationRail` above.
- **Details on demand:** a category opens its own page; a transaction opens a sheet.

**Colour means state:**
- green: on pace, or less than last month;
- amber `Palette.warn`: spending fast, or more than last month;
- red: below zero only, so it still means something when it shows;
- neutral: spending amounts;
- green with "+": money in.

**Layout rules:**
- **One topic per card.** Lists sit on one surface (`ListSurface`), with rows split by inset hairlines and the heading outside (`SectionHeader`, whose figure wraps under the title at large text). This replaces the earlier "one card, one fact" rule, which Irfan released; never mix unrelated figures in one card.
- **Rows** (`_ListRow` behind `TxnTile` and `PlaceTile`): a 40px category icon tile (`categoryIcon()`), name plus one fact on the left, amount plus one fact on the right. At ≥ 1.5× text (`context.largeText`) the right side moves under the name. In a category's own page the icon and category would repeat, so payments show the day and time instead.
- **Sentences round to whole ringgit** (`rmWhole`: "RM 162 to spare"); lists keep sen.
- **Back** steps out: an earlier month → this month → the Now tab → out of the app (`PopScope` in the shell). On desktop, Escape does the month step, Ctrl/Cmd+1–3 switch tabs, and F5 / Ctrl+R / Cmd+R refresh. All shortcuts live in the shell, above the focused node.
- **No silent mode:** after `staleAfter` (5 min) in the background, `appResumed()` opens on Now and the current month.
- **`Panel` and `ListSurface` are `Material`s**, so ripples show on them.

**UI/UX rules applied (Irfan asked for design principles to be researched and applied; keep them):**
- **4-point spacing scale:** `Space` in `ui/theme.dart` (4, 8, 12, 16, 24, 32). Sections are 24–32 apart, a heading sits 8 above its surface, and rows have 12 above and below. Don't add one-off values.
- **Type ramp:** `Styles` in `ui/theme.dart`. Screen titles are 22, section titles 16. Big numbers are `MoneyText`: the ringgit big, with "RM" at half size and the cents at 0.6×, both at 81% opacity so the eye lands on the value. 81% is the lowest opacity that keeps the red at 4.5:1 contrast; 70% measured 3.70:1.
- **Number line:** `Headline` puts the big number in a fixed-height line (`SizedBox` plus `FittedBox`), with text scaling capped at 1.3× for the number only. All other text scales fully.
- **Merchant names:** `displayName()` shows Wise's capitals in normal case ("Kantin Pejabat", "Grab Ride"). Codes without vowels (KTM, KFC) and words with digits stay as they are. This is display only; grouping uses the raw name.
- **48dp targets** (Fitts's law, Material): the tabs, the stepper arrows, the chips, and the View all buttons.
- **Visibility of status:** `updatedLabel()` shows "Updated just now / 5 min ago / 9:05 am / Yesterday, 9:30 pm" and refreshes itself every 30 s.
- **Perceived speed:** the first load shows a `Skeleton` in each screen's shape, not a spinner. It stays still under "reduce motion", as does the month fade (`context.reduceMotion`). The refresh spinner keeps moving as essential progress.
- **Recognition over recall:** `dayLabel()` and `whenLabel()` give "Today, 2:15 pm" and "Yesterday". Activity groups rows by day, so rows show only the time.
- **Errors:** `ErrorBanner` (on every tab) shows a title ("Couldn't reach Wise"), the reason, and "Showing saved data from …", one per line, with the fix as a button.
- **Accessibility:**
  - Screen titles, section headings, the verdict and the stepper are `Heading`s.
  - Headlines and the chart each read as one sentence.
  - Tests run at 200% text on three screen sizes, through every screen and the settings sheet.
- **Native feel (Jakob's law):**
  - A selection haptic on tab change, month step and filter chip.
  - A short fade when switching months.
  - The system back gesture.
- **Setup:** first run shows the four token steps. "Change Wise token" folds them behind "How to get a token", because you've done it before.

**Platform details that matter:**
- **Android:**
  - The release manifest has `INTERNET`. Flutter only adds it for debug, so without it a release build can't reach Wise.
  - `allowBackup=false`: Keystore-wrapped data can't be restored on another device.
  - The launch and Android 12+ splash screens are dark, with no white flash.
  - minSdk is 24.
  - Adaptive and monochrome icons.
  - Edge-to-edge drawing with light system-bar icons (`AnnotatedRegion` in `app.dart`).
- **macOS:** `com.apple.security.network.client` is in both entitlements files; the sandbox blocks networking without it. `TokenStore` uses `MacOsOptions(usesDataProtectionKeychain: false)`, so no Keychain Sharing entitlement is needed. That entitlement would tie an unsigned build to the Mac that built it.
- **Windows:** the exe is `SpendingTracker.exe` with the title "Spending Tracker". `flutter_secure_storage_windows` needs the VS ATL component, which GitHub's Windows runner has.
- **Android signing:** `android/app/build.gradle.kts` signs with `android/key.properties` if it exists. CI writes that file from the `ANDROID_KEYSTORE_*` secrets. Otherwise it falls back to the debug key, and then a new APK can't update an old one. Irfan hasn't added the secrets yet.

**CI** is `.github/workflows/app.yml`:
- **Every run:** analyze, test and a format check. Windows and macOS builds were verified green in run 42467360054. Android kept failing on a GitHub 504 while the Gradle wrapper downloaded Gradle from GitHub releases. Over about 75 minutes, runs 42467360054, 42468675873 and 42469402257 failed, the last after 4 retries, all before any app code compiled. Run 42470567159 showed that Gradle's CDN (`downloads.gradle.org`) also redirects zips to GitHub, though it serves the `.sha256` files itself. So a **Fetch Gradle** step tries three routes, then points `distributionUrl` at the local file for that run only:
1. `services.gradle.org`, checked against Gradle's `.sha256`;
2. the same release asset through GitHub's API (`gh release download`, with the job token), also checked;
3. the runner's preinstalled Gradle, zipped, but only if it's at least the pinned version, since AGP 9.1 needs Gradle 9.3.1 or newer. This logs a warning.
- **Green again since 2026-11-09:** once GitHub's outage cleared, runs 42544914234 and 42545991218 built everything. Android is a 23 MB artifact holding three APKs (arm64 is the one for modern phones), and Windows is an 11.5 MB zip. The APKs are signed with the debug key until the `ANDROID_KEYSTORE_*` secrets are added.
- **Pushes to `main` and manual runs:** an Android APK per CPU type, and a Windows zip.
- **macOS:** only on `v*` tags and manual runs, because macOS minutes cost 10× on private repos.
- **Tags:** also create a GitHub release.

The Go workflow (`build.yml`) ignores changes under `app/`.

**Testing here:**
- **Install the Flutter SDK:** this sandbox doesn't keep it. Download it to `/home/user/sdk/flutter` (from `storage.googleapis.com/flutter_infra_release`; pub.dev is reachable).
- **Run the checks:** `flutter analyze` and `flutter test` in `app/`.
- **Widget tests:** set `WidgetController.hitTestWarningShouldBeFatal = true`, and scroll with `tapVisible()` before tapping.
- **Screenshots:** copy `app/` to a scratch folder, run `flutter create --platforms web .` there, and build with `--dart-define=FAKE_DATA=true --no-web-resources-cdn`. Don't commit a web folder: Irfan doesn't want a web app. Add `SemanticsBinding.instance.ensureSemantics()` in the copy to drive it through the accessibility tree.

**Categories:** the same rules as the Go app, plus:
- **Canteen keywords** (kantin, canteen, warung, gerai, medan selera), because Irfan eats at his workplace canteen and those payments were landing in "Other". The Go `categories` list has them too.
- **"AI & software"** (Anthropic, OpenAI, GitHub, iCloud, Microsoft and similar). AI subscriptions are on his watch list, and they were the biggest share of "Other". This one is Flutter only.

## Build, run, test (Go app)

```bash
# Windows exe (what Irfan uses)
GOOS=windows GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o SpendingTracker.exe .

# Run locally
WISE_TOKEN=xxx go run .
```

### Test without a real token

```bash
python3 dev/mockwise.py &
go build -ldflags "-X main.wiseAPI=http://127.0.0.1:9999" -o /tmp/tracker-test .
WISE_TOKEN=good /tmp/tracker-test < /dev/null &
curl -s localhost:8765/api/data | python3 -m json.tool
```

The mock covers a business plus a personal profile with large IDs, USD and MYR balances, card, deposit, transfer, unmatched-merchant and older-month transactions, and a 401 for a bad token. For headless screenshots, set the browser `timezoneId` to `Asia/Kuala_Lumpur`, or cycle and week boundaries will be shifted.

To test hosted mode, start the same test binary with these variables:

```bash
PORT=9090 WISE_TOKEN=good APP_PASSWORD='correct horse battery' /tmp/tracker-test &
curl -s -o /dev/null -w '%{http_code}\n' localhost:9090/          # 303 to /login
curl -s -c jar -d 'password=correct horse battery&remember=1' localhost:9090/login
curl -s -b jar localhost:9090/api/data | python3 -m json.tool       # data with canLogout: true
```

When scripting parallel curls against it, `wait` on their PIDs only. A bare `wait` also waits on the server and hangs.

## Unverified assumptions: check these first with a real token

1. **Token availability.** Wise's newer docs describe personal API tokens for **business** accounts. It isn't confirmed that Irfan's personal account offers them.
2. **Statement access and SCA.** The docs say personal tokens can read balance statements for accounts based in Malaysia. Wise might still answer 403 with an `x-2fa-approval` header. If that happens, either implement SCA signing (upload a public key, then sign the one-time token) or fall back to the activities API (`/v1/profiles/{id}/activities`).
3. **Field shapes** are taken from the docs, not from real responses: the amount sign on `DEBIT`, `merchant.category` being a string, and how **DuitNow QR** payments appear (unknown `details.type`). The mapping may need tuning once real data comes in.
4. Wise's DuitNow QR support is rolling out gradually, so some merchants may not accept it yet.

## Decisions already made (with reasons)

- **CIMB was dropped.** It has no personal API. Its OCTO push notifications contain no transaction details (Irfan checked), so reading notifications won't work. eStatements are monthly only, which isn't live enough.
- **Malaysia Open Finance** (PayNet, first institutions expected January 2027) works through licensed providers, not personal APIs.
- **Wise was chosen** because it supports DuitNow QR and a card in Malaysia, and its API lists Malaysia among the countries where personal tokens can read statements.
- **No webhooks.** Wise's personal webhooks only offer transfer update, account deposit and transfer issue events. There's nothing for card or QR spending, hence the on-demand Update button.
- **No Claude artifact dashboard.** Those pages can't fetch external hosts.
- **No Google Sheet or Apps Script.** Irfan wanted the app to call the API directly. An earlier Apps Script web app version existed and has been superseded.
- **Go instead of Python.** Irfan asked for something fast and lightweight. The result is a single exe with no runtime.
- **A hosted website, not a native app, for other devices.** He uses Android and Windows, and sometimes a Mac. A website (with a manifest, so it installs to the home screen) covers all three from one build. A native app would mean three builds and Mac signing hassles. Tailscale to the laptop was rejected because the laptop would have to stay on.
- **A login page, not HTTP basic auth.** The Mac may be shared, and basic auth has no real logout.
- **Plain HTML, no frontend framework for now.** Irfan chose this. If the UI grows a lot, the fallback plan is React + Vite (he knows React) embedded with `go:embed`, or templ + htmx to stay all-Go. Skip Go WebAssembly: the download is too big for phones.

## Ideas not built (only build if Irfan asks)

- An AI question box (needs an LLM API key). The lighter option offered was a **Copy for AI** button that copies the cycle's transactions as text to paste into Claude. Irfan hasn't asked for either yet.
- Deep-dive views Irfan said belong in a monthly AI analysis, not the dashboard: needs vs wants, a watch list (AI subscriptions, Roblox), and a comparison with last cycle. AI subscriptions also have no category yet.
- The doughnut and the 6-month bar chart were removed on purpose (they overlapped with the category table, and the trend view is monthly deep-dive material). Don't bring them back unasked.
- A Mac build (`go build` on the Mac)
- Auto-refresh on a timer
- A `categories.json` next to the exe so categories can be edited without rebuilding
- Budgets (he explicitly said tracking, not budgeting)

## Working with Irfan

- Be concise and direct. He prefers simple designs and pushes back on complexity, so offer the simplest thing that works.
- He's a CS graduate and a working engineer (React, TypeScript, .NET, FastAPI, Kotlin), so technical depth is fine and long explanations aren't needed.
- His laptop is assumed to be Windows, but that isn't confirmed.
