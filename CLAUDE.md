# Spending Tracker: handover for Claude Code

## What this is

Irfan's personal spending tracker (Malaysia, RM). A small Go app that pulls his MYR transactions from the Wise API and shows a dashboard in the browser on his laptop. It's "somewhat live": he presses **Update** and it fetches fresh data from Wise.

Focus is **tracking** (where money goes, percentages, what's left this month), not budgeting.

## Status (2026-11-08)

- Code is complete. It builds, and it's been tested only against `dev/mockwise.py` (re-verified 2026-11-08: `go vet` clean, Windows build OK, mock test and bad-token 502 OK). **It has never been run against the real Wise API.**
- The repo is `ipanropi/spending-live-tracker` (not `spending-tracker` as first planned). It's pushed to branch `ccr-2b2be70a-egwfux`. `main` doesn't exist on GitHub yet, so the CI workflow (which triggers on `main`) hasn't run.
- Irfan has a Wise account and has seen Integrations and tools. He hasn't confirmed that he's created an API token yet.
- A Windows build (`SpendingTracker.exe`, about 6.5 MB) was sent to him. CI builds it too (see below).

## Files

| File | Purpose |
|---|---|
| `main.go` | The whole backend. Go standard library only. |
| `index.html` | Dashboard UI, embedded into the binary with `go:embed`. Vanilla JS plus Chart.js 4.4.1 from cdnjs. |
| `.github/workflows/build.yml` | Builds the Windows exe on every push to `main` (as an artifact) and on `v*` tags (as a release). **Untested.** |
| `dev/mockwise.py` | Fake Wise API for testing. |
| `README.md` | User-facing setup instructions. |

## How it works

- It listens on `127.0.0.1:8765` (local only), serves `/` (the embedded HTML) and `/api/data` (JSON), and opens the browser.
- It runs as a single instance. If the port is already taken, it opens the browser and exits.
- **Token:** the app reads the `WISE_TOKEN` env var first, then `wise_token.txt` next to the exe. If neither exists, it asks for the token on stdin and saves it with mode 0600. The file is gitignored.
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

The mock covers a business plus a personal profile with large IDs, USD and MYR balances, card, deposit, transfer, unmatched-merchant and older-month transactions, and a 401 for a bad token. Chart.js loads from cdnjs, so a headless screenshot needs network access or a route stub.

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
