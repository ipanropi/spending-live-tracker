# Spending Tracker: handover for Claude Code

## What this is

Irfan's personal spending tracker (Malaysia, RM). A small Go app that pulls his MYR transactions from the Wise API and shows a dashboard in the browser. It runs either on his laptop or, in hosted mode, as a private password-protected website for his other devices (Android, Windows, sometimes a Mac). It's "somewhat live": he presses **Update** and it fetches fresh data from Wise.

Focus is **tracking** (where money goes, percentages, what's left this month), not budgeting.

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
| `web/index.html` | Dashboard UI. Vanilla JS plus Chart.js 4.4.1 from cdnjs. If Chart.js can't load, the page skips the charts and still shows the numbers. Dark only, by Irfan's choice, with 4px corners (he dislikes heavy rounding). Colours are CSS variables on `:root`. Category colours are a fixed 8-slot order checked for colour-blind separation on the `#1a1a19` card, assigned by amount rank so neighbours in the doughnut are neighbours in the list. Categories past 8 share one grey. Don't cycle colours or pick them ad hoc. |
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
  3. `GET /v1/profiles/{pid}/balance-statements/{bid}/statement.json?currency=MYR&type=COMPACT&intervalStart=…&intervalEnd=…`. The window runs from the 1st of the month 5 months ago (local time) to now.
- **JSON parsing** is deliberately loose (`map[string]any` with `UseNumber`), so an unexpected field shape won't break decoding.
- **Each transaction** becomes `{date, amount, name, category, note}`:
  - **amount:** negative means money out. The sign is forced to match `DEBIT` or `CREDIT`.
  - **name:** the first one present of `details.merchant.name`, then `details.recipient.name`, then `details.senderName`, then `details.description`.
  - **category:** if the amount is positive, it's "Money in". Otherwise the first keyword match in `categories` wins. If nothing matches, it uses Wise's `merchant.category`, then `TRANSFER` becomes "Transfers" and `CONVERSION` becomes "Currency exchange", and anything left is "Other".
- **Balance** comes from `endOfStatementBalance`.
- **All the maths** happens client-side in `index.html`: the month selector, the four summary cards (spent, money in, left this month, balance now), the category doughnut and table with percentages, top places, the 6-month bar chart, and the transaction list. All text is HTML-escaped.
- **Errors** are returned as `{"error": "..."}` with HTTP 502 and shown in a red box on the page.

## Build, run, test

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

The mock covers a business plus a personal profile with large IDs, USD and MYR balances, card, deposit, transfer, unmatched-merchant and older-month transactions, and a 401 for a bad token. Chart.js loads from cdnjs, which the Claude Code cloud sandbox blocks. For headless screenshots, `npm pack chart.js@4.4.1` and route the cdnjs URL to `package/dist/chart.umd.js`.

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

- An AI question box (needs an LLM API key)
- A Mac build (`go build` on the Mac)
- Auto-refresh on a timer
- A `categories.json` next to the exe so categories can be edited without rebuilding
- Budgets (he explicitly said tracking, not budgeting)

## Working with Irfan

- Be concise and direct. He prefers simple designs and pushes back on complexity, so offer the simplest thing that works.
- He's a CS graduate and a working engineer (React, TypeScript, .NET, FastAPI, Kotlin), so technical depth is fine and long explanations aren't needed.
- His laptop is assumed to be Windows, but that isn't confirmed.
