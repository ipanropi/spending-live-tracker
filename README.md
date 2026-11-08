# Spending Tracker

A small desktop app that shows where your money goes, using live data from your Wise MYR account.

One 6.5 MB file. Double-click it, and the dashboard opens in your browser. Press **Update** to pull your latest transactions from Wise.

## What it shows

- Spent, money in, and what's left this month
- Your current Wise balance
- Spending by category with percentages
- Top places you spend at
- Spending by month for the last 6 months
- Every transaction for the selected month

## Setup

1. Create a Wise API token with **Read only** access (Wise website > Integrations and tools > API tokens).
2. Download `SpendingTracker.exe` from [Releases](../../releases) or the latest [Actions](../../actions) build.
3. Double-click it. If Windows warns you, click **More info > Run anyway**.
4. Paste your token when asked. It is saved in `wise_token.txt` next to the app.

Keep the black window open while you use the dashboard. Close it to stop.

## Categories

Merchants are sorted into categories by keywords in the `categories` list in `main.go`. Anything that doesn't match uses Wise's own merchant category, or goes into "Other". Add keywords there and rebuild.

## Build it yourself

Needs [Go](https://go.dev/dl/) 1.24 or newer.

```
go build -ldflags "-s -w" -o SpendingTracker.exe .
```

For a Mac, build on the Mac with `go build -o SpendingTracker .` and run `./SpendingTracker`.

Every push to `main` also builds the Windows app on GitHub Actions. Pushing a tag like `v1.0.1` creates a release with the `.exe` attached.

## Privacy

- The app only listens on `127.0.0.1`, so nothing else on your network can open it.
- Your token stays on your computer in `wise_token.txt`, which is ignored by git. Never commit it.
- A read-only token can see transactions but cannot move money.
