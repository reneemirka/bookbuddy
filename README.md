# Book Buddy

Book Buddy is a personal reading companion for keeping track of your library, anticipated books, author events, and the details you want to remember before the next installment.

## Current milestone: M13 — Polish the Personal Version

Book Buddy currently provides a native iOS app shell and four primary tabs:

- Library
- Radar
- Calendar
- Settings

The Library is backed by local on-device storage. You can add a book, set its reading status, rating, review, and reading dates; browse detected series and their reading order; and search Open Library by title, author, series, or ISBN.

Following is separate from reading intent:

- **Want to Read** is the Library status for books you plan to read.
- **Follow** tells Book Buddy to monitor a book, series, or author for future release information.
- When following a book with known series metadata, Book Buddy asks whether to follow only that book or the entire series.
- **Radar** shows upcoming and recently released books relevant to something you follow. It refreshes when the app opens and on demand.
- **Calendar** provides month and agenda views for known book release dates, with navigation back to books and series.

The app remains local-first. Release information is cached on-device from Open Library while the app is active. Optional local reminders are scheduled around known release dates and replaced idempotently when those dates change.

An optional, narrowly scoped Cloudflare monitoring worker can check followed books, authors, series, and enabled public event calendars while the app is closed. It stores only an anonymous device ID, APNs token, explicitly followed entities, and the public event-feed URLs—not the Library, reviews, reading dates, or recaps. Configure its KV namespaces and APNs secrets before connecting it under **Settings → Background Monitoring**. The app requests an APNs device token when notification permission is available.

M13 additions include a first-run guide and a JSON export of local reading, following, and event-location preferences from **Settings → Data**.

Series can cache spoiler-bounded recaps composed only from books marked Read. The iOS app does not store an OpenAI key. A deployable Cloudflare Worker gateway is in [`recap-gateway`](recap-gateway), with a fixed model, a 1,200-token output cap, and default limits of 20 recaps per day and 100 per month. It is not deployed or connected by default.

Hardcover can be connected from **Settings** with a personal API token. The token is stored in the iOS Keychain. Sync is manual and one-way: Hardcover records are imported and refreshed, while matching Book Buddy records are preserved rather than overwritten. There is no write-back to Hardcover.

## Checks

Run `./scripts/run-evals.sh` before committing. The repository includes a pre-commit hook that runs this build evaluation when Git is configured with `git config core.hooksPath .githooks`.

## Requirements

- macOS with the current version of Xcode installed
- An iOS Simulator supplied by Xcode, or an iPhone configured for development

## Open and run

1. Open [BookBuddy.xcodeproj](BookBuddy.xcodeproj) in Xcode.
2. Select the `BookBuddy` scheme.
3. Choose an iPhone Simulator from the device menu.
4. Press **Run** (or `Command-R`).

The app launches to the Library tab. Use the tab bar to visit Radar, Calendar, and Settings.
