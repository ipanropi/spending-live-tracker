# Spending Tracker

A small app that shows where your money goes, using live data from your Wise MYR account. Run it on your laptop, or host it as a private website and use it from your phone and other computers.

One 6.7 MB file. Double-click it, and the dashboard opens in your browser. Press **Update** to pull your latest transactions from Wise.

## What it shows

It works best if Wise is your spending wallet: on each payday (the 7th and the 22nd), move your spending money into Wise. Your Wise balance is then what's left until the next payday.

- What's left until the next payday, and what that comes to per day and per week
- Spent this month (7th to 6th), and spent this week (Monday to Sunday)
- Spending by category with percentages
- Your top 5 places
- Every transaction in the month. Pick an earlier month to look back.

Paydays are `paydays` in `main.go`. The month starts on `payDay`.

## Setup

1. Create a Wise API token with **Read only** access (Wise website > Integrations and tools > API tokens).
2. Download `SpendingTracker.exe` from [Releases](../../releases) or the latest [Actions](../../actions) build.
3. Double-click it. If Windows warns you, click **More info > Run anyway**.
4. Paste your token when asked. It is saved in `wise_token.txt` next to the app.

Keep the black window open while you use the dashboard. Close it to stop.

## Use it on your phone and other devices (hosted mode)

The same app can run on a web host. When the `PORT` environment variable is set (hosts like Render and Cloud Run set it for you), it switches to hosted mode:

- It serves the dashboard to any device, behind a login page.
- It reads your token from `WISE_TOKEN` and never asks for it.
- It won't start unless both of these are set on the host:

| Variable | Value |
|---|---|
| `WISE_TOKEN` | Your read-only Wise API token |
| `APP_PASSWORD` | The password for the login page, at least 12 characters |

The host must serve the site over HTTPS, because the login cookie only works on HTTPS.

To get an app icon:
- **Android:** open the site in Chrome, then menu > **Add to Home screen**.
- **Windows:** in Edge or Chrome, menu > **Install** (or **Apps > Install this site as an app**).
- **Mac:** in Safari, **File > Add to Dock**. In Chrome, use the install icon in the address bar.

"Keep me logged in" keeps you in for 30 days. Untick it on a shared computer, and use **Log out** when you're done.

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

- On the laptop, the app only listens on `127.0.0.1`, so nothing else on your network can open it.
- On the laptop, your token stays on your computer in `wise_token.txt`, which is ignored by git. Never commit it.
- In hosted mode, every page needs the password. After 20 wrong passwords in 15 minutes, it stops accepting logins for a while, but devices already logged in keep working. Changing `APP_PASSWORD` or `WISE_TOKEN` logs out every device.
- A read-only token can see transactions but cannot move money.
