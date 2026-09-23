# Book Buddy
## Product Specification v0.4

### 1. Product Vision

**Book Buddy** is a personal book companion that helps readers never lose track of a series, forget what happened in it, miss a book they were waiting for, or miss an author event they would have wanted to attend.

Book Buddy connects to a user's existing reading history, identifies series they've read or started, lets them follow books, series, and authors, tracks upcoming releases and events, and proactively reminds them why they cared and what they need to remember before a new book arrives.

Book Buddy is **personal first, social later**. The initial version is designed for one user, with an architecture that can eventually support sharing with friends.

---

# 2. Core Product Principles

1. **Reduce memory burden.**  
   The user should not have to remember which series they're waiting for, when books are coming out, what happened three books ago, or which author events they wanted to attend.

2. **Be proactive.**  
   Once configured, Book Buddy should monitor relevant books, series, authors, releases, and events without requiring ongoing manual maintenance.

3. **Respect the user's reading boundary.**  
   Recaps must never spoil books the user has not read.

4. **Knowing about something is different from following it.**  
   Book Buddy may identify a series or book in the user's library without automatically monitoring it.

5. **Following is opt-in.**  
   Users explicitly choose which books, series, and authors they want Book Buddy to watch.

6. **Unfollowing is safe and reversible.**  
   Unfollowing a series, book, or author stops proactive monitoring but never deletes reading history.

7. **A notification is not the end of the workflow.**  
   Books the user is waiting for should remain easily accessible after notifications have been sent.

8. **Avoid duplicate data entry.**  
   Existing reading services should remain the source of truth for reading activity whenever possible.

9. **Trustworthy information matters.**  
   Release dates and events should have identifiable sources and confidence levels.

---

# 3. Core Concepts

Book Buddy has three distinct concepts:

## Library

The user's reading history:

- Read
- Currently reading
- Want to read
- DNF
- Ratings
- Reviews
- Reading dates

## Following

Things the user explicitly wants Book Buddy to monitor.

The user can follow:

- A series
- A single book
- An author

Following determines what Book Buddy actively watches for new releases, events, and relevant reminders.

## Watchlist

Books the user is actively waiting to read.

The Watchlist is a **book-only actionable list**.

A book can enter the Watchlist because:

- The user followed the book directly
- The user followed a series and Book Buddy identified an upcoming book
- The user followed an author and Book Buddy identified a relevant upcoming book

A Watchlist book remains easily accessible until the user:

- Marks it read/complete, or
- Removes it from the Watchlist

A notification being sent does **not** remove the book from the Watchlist.

### Conceptual relationship

```text
                 ┌── Series
Following ───────┼── Author
                 └── Book
                      │
                      ↓
                  Watchlist
                      │
                 ┌────┴────┐
                 ↓         ↓
              Released    Read
```

Following answers:

> **What should Book Buddy watch for me?**

Watchlist answers:

> **What books am I waiting for or need to read?**

---

# 4. MVP

The MVP should provide:

- Goodreads CSV import
- Hardcover integration for ongoing reading-data synchronization
- Personal book library
- Automatic series identification
- Series progress tracking
- Ability to follow a series
- Ability to follow a single book
- Ability to follow an author
- Ability to unfollow series, books, and authors
- Persistent Watchlist
- Series dashboard/detail pages
- Upcoming release tracking
- Release-date notifications
- Personalized reminders based on ratings/reviews/reading history
- Calendar view
- AI-generated spoiler-controlled series recaps
- Basic author/book event discovery
- Location-based event filtering
- Local and remote notifications
- Settings

---

# 5. Explicitly Out of Scope for MVP

- Social feeds
- Messaging
- Public profiles
- Friend activity
- Social recommendations
- Buying books
- E-books/audiobooks
- Android app
- Web app
- Barcode scanning
- Subscriptions
- Advertising
- Comprehensive event aggregation across every possible source
- Automatic following of every identified series
- Personalized book recommendation engine

---

# 6. Initial Setup

1. User installs Book Buddy.
2. User imports their Goodreads CSV.
3. Book Buddy imports books, ratings, reviews, and reading statuses where available.
4. Book Buddy identifies authors and series.
5. User reviews their detected series.
6. User chooses which series they want to follow.
7. User can optionally follow individual books.
8. User can optionally follow authors.
9. User configures locations and notification preferences.

---

# 7. Adding Books, Series, and Authors

Book Buddy should have a prominent **Add** action.

The user can search for:

### A series

Selecting a series allows the user to:

> **Follow series**

Book Buddy then monitors the series for future releases and relevant events.

Upcoming books in a followed series can automatically become Watchlist items.

### A single book

Selecting a book allows the user to:

> **Follow book**

This is useful when:

- The user has never read the series
- The book is standalone
- The book is part of a series the user doesn't want to follow
- The user simply heard about an upcoming book and wants to know when it is released

Following an individual book causes it to appear on the Watchlist.

### An author

Selecting an author allows the user to:

> **Follow author**

Book Buddy can then monitor the author for:

- New book announcements
- New releases
- Author events
- Signings
- Talks
- Launch parties
- Other relevant appearances

Relevant upcoming books can appear on the Watchlist.

---

# 8. Series Identification vs. Following

Series identification must never automatically imply following.

For example, Book Buddy imports:

> *The Fifth Season*

and identifies:

> Broken Earth

The user can see that relationship in their Library and Series views.

But Book Buddy should not automatically start monitoring the series.

The user explicitly chooses:

> **Follow series**

The user can later choose:

> **Unfollow series**

Unfollowing stops active monitoring but preserves:

- Books
- Reading progress
- Ratings
- Reviews
- Reading dates
- Previously generated recaps
- Series information

The user can follow the series again later.

---

# 9. Watchlist

The Watchlist is a persistent, easily accessible list of books the user is waiting for or intends to read.

This is one of the primary product surfaces.

Example:

## Your Watchlist

### Coming soon

**The next Murderbot book**  
May 14, 2027  
Following because: Murderbot series

**New Emily Henry novel**  
June 2027  
Following because: Emily Henry

**Book You Added**  
Release date unknown  
Following because: You added it

### Released

**Book X**  
Released September 18

The book remains on the Watchlist until the user:

> **Mark as read**

or

> **Remove**

---

# 10. Watchlist Lifecycle

Watchlist items can have states:

- Watching
- Released
- Read/Complete
- Removed

The primary Watchlist should emphasize:

1. **Upcoming books**
2. **Recently released but unread books**

Books marked Read/Complete should leave the active Watchlist but remain in the Library.

Removed books should likewise remain in the Library if they were previously part of the user's reading data.

---

# 11. How Books Enter the Watchlist

A book can enter the Watchlist through three paths.

### Directly followed book

User searches for a book and taps:

> Follow book

→ Book enters Watchlist.

### Followed series

User follows a series.

Book Buddy identifies a future book in that series.

→ Book enters Watchlist.

### Followed author

User follows an author.

Book Buddy identifies a relevant upcoming book.

→ Book enters Watchlist.

The Watchlist item should record its origin so the user can understand why it is there.

For example:

> Following because you follow the Scholomance series.

or:

> Added by you.

---

# 12. Following and Watchlist Independence

Following and Watchlist membership are related but not identical.

For example:

1. User follows the Scholomance series.
2. Book Buddy discovers Book #4.
3. Book #4 enters the Watchlist.
4. User later unfollows the Scholomance series.
5. Book #4 **remains on the Watchlist** if it has already been surfaced to the user.

This prevents the user's personal reading queue from unexpectedly changing when they modify what Book Buddy monitors.

The user can explicitly remove the book if they no longer want it.

---

# 13. Library

The Library contains the user's reading history and imported books.

It should show:

- Books
- Reading status
- Ratings
- Reviews
- Authors
- Series
- Reading dates

The Library is not limited to followed books.

A book can be:

- In Library only
- In Library + Watchlist
- In Library + associated with a followed series
- In Library + individually followed

---

# 14. Series Model

A series is a distinct entity from an individual book.

A series may contain:

- Main novels
- Novellas
- Short stories
- Prequels
- Companion books
- Spin-offs
- Other related works

Series ordering should therefore not assume a simple linear sequence.

### SeriesBook

- seriesId
- bookId
- position
- type

Types may include:

- novel
- novella
- short story
- prequel
- sequel
- companion
- spin-off
- other

---

# 15. Series Detail Page

Example:

## The Scholomance

**Following**

### Your progress

2 of 3 main books read

Last read: *The Last Graduate*

Rating: 5 stars

### Books

✓ *A Deadly Education*  
✓ *The Last Graduate*  
○ *The Golden Enclaves*

### Upcoming

Next book announced

Release: October 12, 2027

**Add to Watchlist**

### Your history

- Ratings
- Reviews
- Reading dates
- Comments

### Remember before the next book

AI-generated spoiler-controlled recap.

---

# 16. Following Data Model

Following should be represented as user-specific relationships.

### FollowedSeries

- userId
- seriesId
- followedAt
- notificationsEnabled

### FollowedBook

- userId
- bookId
- followedAt
- notificationsEnabled

### FollowedAuthor

- userId
- authorId
- followedAt
- notificationsEnabled

These are monitoring preferences, not replacements for the underlying book/series/author data.

---

# 17. Watchlist Data Model

### WatchlistItem

- userId
- bookId
- addedAt
- addedReason
- status
- completedAt
- removedAt

`addedReason` may include:

- manual
- followed-series
- followed-author

The Watchlist is independent from notification history.

---

# 18. Release Tracking

Book Buddy should monitor releases for:

- Followed series
- Followed books
- Books on the Watchlist

Potential sources:

1. Publisher websites
2. Author websites/newsletters
3. Google Books
4. Open Library
5. Other reputable metadata sources
6. Manual user correction

Every release should record:

- Book
- Release date
- Release status
- Source
- Source URL
- Confidence
- Last verified
- Previous release date, if changed

Confidence levels:

- Confirmed
- Likely
- Unknown

### Monitoring frequency

- No release date known: weekly
- More than 6 months away: weekly
- 1–6 months away: 2–3 times/week
- Less than 1 month away: daily
- Recently changed release date: daily for a short period

---

# 19. Release Notifications

Book Buddy should progressively remind users about relevant upcoming releases.

### Release announcement

> The next book in a series you're following has been announced.

### ~3 months before release

Remind the user:

- Why they cared
- Previous ratings
- Reviews/comments
- Reading history

### ~1 month before release

Resurface:

- Previous reviews
- Ratings
- Important personal comments
- Reading history

### ~1 week before release

Provide:

> **What you need to remember**

A personalized spoiler-controlled recap based on books the user has actually read.

### Release day

> **It's out!**

The book remains on the Watchlist until the user marks it read/complete or removes it.

---

# 20. Calendar

Book Buddy should provide a dedicated **Calendar** view.

The calendar can display:

- Book release dates
- Upcoming author events
- Bookstore/library events
- Personalized reminder dates
- Other relevant reading-related dates

Users should be able to switch between:

- Month view
- Agenda/list view

Tapping an item should open its associated book, series, author, or event.

Example:

**October 2027**

12 — *The Scholomance #4* releases  
18 — Author event  
25 — Book Buddy reminder: revisit your previous review

Calendar items should respect the user's following and notification preferences.

---

# 21. Author Following

Authors can be followed independently from series.

Following an author can generate:

- New book announcements
- Release notifications
- Author events
- Signings
- Talks
- Launch parties
- Other relevant appearances

Following an author does not require following every series they write.

---

# 22. Events

Book Buddy should identify events relevant to:

- Followed authors
- Followed series
- Watchlist books
- Upcoming releases

Potential event types:

- Author talks
- Book signings
- Launch parties
- Bookstore events
- Library events
- Festivals
- Conventions
- Reading events
- Promotional appearances

Potential sources:

- Bookstores
- Libraries
- Publishers
- Author websites
- Event platforms
- Literary festivals
- Other reputable event listings

The initial MVP may use a limited set of reliable sources rather than attempting comprehensive web coverage.

---

# 23. Location

Users should configure locations and radii.

Example:

**Pittsburgh — 25 miles**

**Cleveland — 50 miles**

No continuous location tracking is required.

---

# 24. Event Notifications

Events should be prioritized based on:

1. Followed author
2. Followed series
3. Watchlist book
4. Connection to an upcoming release
5. Proximity
6. How soon the event occurs

---

# 25. AI Recaps

The purpose of AI recaps is:

> **Tell me what I personally need to remember before reading the next book.**

Use:

- Books the user has marked read
- Reading order
- Ratings
- Reviews
- Comments
- Reading dates
- Series metadata
- Important information from books actually read

Prioritize:

- Major plot developments
- Important characters
- Relationships
- Reveals already encountered
- Unresolved threads
- Important world-building
- Information likely to matter for the next book

### Hard rule

Never spoil a book the user has not read.

Generated recaps should be cached.

---

# 26. App Navigation

Primary navigation:

1. **Library**
2. **Radar**
3. **Calendar**
4. **Settings**

## Library

The user's reading history.

## Radar

The proactive Book Buddy dashboard.

It should surface:

- Watchlist books
- Recently announced releases
- Upcoming releases
- Upcoming events
- Important reminders

The Radar should answer:

> **What do I need to know about my books right now?**

The Watchlist should be prominently accessible from Radar.

## Calendar

A chronological view of releases, events, and reminders.

## Settings

- Reading-data provider
- Notifications
- Locations
- Followed authors
- Followed series
- Followed books
- Data/import
- AI recap settings
- Account

---

# 27. Backend Architecture

External sources:

→ Book / series / release / event ingestion

→ Backend

→ Database

→ AI recap generation

→ Notification scheduler

→ APNs

→ iPhone

The backend should perform scheduled monitoring rather than relying on iPhone background execution.

---

# 28. Security

Secrets must never be committed to GitHub.

Examples:

- Hardcover API credentials
- Google API credentials
- AI API credentials
- APNs credentials

Store them in backend environment variables or a secret-management system.

The iPhone should not contain unrestricted backend/API secrets.

---

# 29. Testing Requirements

### Series identification

- Correct series matching
- Standalone books
- Non-linear series
- Multiple related series

### Following

- Identified series is not automatically followed
- Follow series
- Unfollow series
- Follow individual book
- Unfollow individual book
- Follow author
- Unfollow author
- Resuming a follow retains history

### Watchlist

- Manually followed book enters Watchlist
- Series-generated book enters Watchlist
- Author-generated book enters Watchlist
- Notification does not remove Watchlist item
- Released book remains visible
- Marking read removes it from active Watchlist
- Removing a book works without deleting Library history
- Unfollowing a series does not unexpectedly remove an existing Watchlist item

### Reading boundary

- Recaps only use books marked read
- Unread books cannot leak spoilers

### Releases

- New release detection
- Release-date changes
- Multiple sources
- Confidence levels
- Duplicate detection

### Notifications

- Correct scheduling
- Unfollow cancellation
- No duplicate notifications
- Notification history preserved

### Calendar

- Releases appear correctly
- Events appear correctly
- Reminder dates appear correctly
- Tapping calendar items opens the appropriate entity

### Events

- Geographic radius
- Duplicate detection
- Relevance
- Event-date changes

---

# 30. Development Milestones

### M1 — Hello World

- Create SwiftUI project
- Establish Git repository
- Basic project structure
- Basic navigation

### M2 — Local Library

- Book model
- Local persistence
- Library UI
- Book detail

### M3 — Goodreads Import

- CSV importer
- Mapping
- Book matching
- Reading-history import

### M4 — Series + Following

- Series model
- Series identification
- Series detail
- Series progress
- Follow/unfollow
- Add/search flow

### M5 — Watchlist

- Follow individual books
- Watchlist model
- Watchlist UI
- Manual book following
- Series-generated Watchlist items
- Author-generated Watchlist items
- Released-but-unread state
- Mark read/remove behavior

### M6 — Hardcover

- Authentication/API integration
- Ongoing reading synchronization
- Provider abstraction

### M7 — Release Tracking

- Release model
- External source ingestion
- Release verification
- Radar view

### M8 — Notifications + Calendar

- Notification preferences
- Release announcements
- Countdown reminders
- Release-day notifications
- Calendar
- Notification idempotency

### M9 — AI Recaps

- Personalized recap generation
- Reading-boundary enforcement
- Review integration
- Caching

### M10 — Events

- Event model
- Initial event sources
- Location filtering
- Event notifications

### M11 — Polish

- UI refinement
- Onboarding
- Error handling
- Settings
- Performance
- Testing

### M12 — Friends

Only after the personal version works well:

- Authentication
- Multi-user backend
- Sharing
- Friend-specific functionality

---

# 31. First Meaningful Release

The first meaningful release should allow the user to:

1. Import their Goodreads library.
2. See their books organized into series.
3. See their progress through each series.
4. Follow or unfollow individual series.
5. Search for and follow a new series.
6. Search for and follow a single book.
7. See upcoming/watched books in a persistent Watchlist.
8. Mark a Watchlist book read/complete or remove it.
9. See upcoming releases.

The first release does not need sophisticated AI or comprehensive event aggregation.

---

# 32. Ultimate Success Criterion

Book Buddy should make the user feel:

> **I don't have to remember which books I'm waiting for, when they come out, why I cared about them, what happened in the previous books, or which author events I might want to attend. Book Buddy remembers for me.**

And:

> **I decide what Book Buddy watches.**

The app should feel like a thoughtful personal assistant for the user's reading life, rather than another reading platform that demands ongoing maintenance.
