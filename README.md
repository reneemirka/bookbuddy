# Book Buddy

Book Buddy is a personal reading companion for keeping track of your library, anticipated books, author events, and the details you want to remember before the next installment.

## Current milestone: M3 — Local Library UI

Book Buddy currently provides a native iOS app shell and four primary tabs:

- Library
- Radar
- Calendar
- Settings

The Library is backed by local on-device storage. You can add a book, set its reading status, rating, review, and reading dates; tap it to view its detail screen; edit that reading information later; or swipe left to remove it. The other tabs remain placeholders.

No accounts, imports, APIs, notifications, or external book data are implemented yet.

## Requirements

- macOS with the current version of Xcode installed
- An iOS Simulator supplied by Xcode, or an iPhone configured for development

## Open and run

1. Open [BookBuddy.xcodeproj](BookBuddy.xcodeproj) in Xcode.
2. Select the `BookBuddy` scheme.
3. Choose an iPhone Simulator from the device menu.
4. Press **Run** (or `Command-R`).

The app launches to the Library tab. Use the tab bar to visit Radar, Calendar, and Settings.
