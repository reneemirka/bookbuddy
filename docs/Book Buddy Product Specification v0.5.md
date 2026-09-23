# Book Buddy
## Product Specification v0.5

### 1. Product Vision

**Book Buddy** is a personal book companion that helps readers never lose track of a series, forget what happened in it, miss a book they were waiting for, or miss an author event they would have wanted to attend.

Book Buddy connects to a user's existing reading history, identifies series they've read or started, lets them follow books, series, and authors, tracks upcoming releases and events, and proactively reminds them why they cared and what they need to remember before a new book arrives.

Users can also manage their reading activity directly inside Book Buddy, including reading status, ratings, reviews, and reading dates.

Book Buddy is **personal first, social later**. The initial version is designed for one user, while the architecture should support multiple users in the future without requiring a fundamental redesign.

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
   Unfollowing stops proactive monitoring but never deletes reading history.

7. **A notification is not the end of the workflow.**  
   Books the user is waiting for remain easily accessible after notifications have been sent.

8. **Avoid duplicate data entry.**  
   Existing reading services should be used where helpful, while Book Buddy should allow users to manage their reading activity directly.

9. **User-created data belongs to Book Buddy.**  
   Ratings, reviews, statuses, and other data entered directly into Book Buddy must remain available even if an external integration changes or disappears.

10. **External services should be replaceable.**  
    Hardcover, Google Books, and other services should sit behind internal interfaces rather than being deeply coupled to the app.

11. **Trustworthy information matters.**  
    Release dates and events should have identifiable sources and confidence levels.

12. **Design for efficient growth.**  
    Shared information about books, authors, series, releases, and events should not be unnecessarily duplicated per user.

---

# 3. Core Concepts

## Library

The user's reading history.

A UserBook can include:

- Want to read
- Currently reading
- Read
- DNF
- Rating
- Review
- Date started
- Date finished
- Other personal reading information

## Following

Things the user explicitly wants Book Buddy to monitor.

Users can follow:

- Series
- Individual books
- Authors

Following answers:

> **What should Book Buddy watch for me?**

## Watchlist

The Watchlist is a book-only actionable queue containing books the user is waiting for or intends to read.

A book may enter because:

- The user followed it directly
- It was discovered through a followed series
- It was discovered through a followed author

Watchlist answers:

> **What books am I waiting for or need to read?**

A Watchlist item remains active until the user:

- Marks the book Read/Complete, or
- Removes it

Sending a notification never removes a Watchlist item.

---

# 4. MVP Capabilities

The planned product should support:

- Goodreads CSV import
- Hardcover integration
- Personal book library
- Reading statuses
- Ratings
- Reviews
- Reading dates
- Live book search
- Search for authors and series
- Adding books not already in the user's library
- Automatic series identification
- Series progress
- Follow/unfollow series
- Follow/unfollow books
- Follow/unfollow authors
- Persistent Watchlist
- Upcoming release tracking
- Calendar
- Release notifications
- Personalized reminders
- AI-generated spoiler-controlled recaps
- Basic author/book event discovery
- Location-based event filtering
- Local and remote notifications
- Settings

Not all of these capabilities need to be implemented in the first development milestone.

---

# 5. Explicitly Out of Scope for Initial Product

- Social feeds
- Messaging
- Public profiles
- Friend activity
- Social recommendations
- Purchasing books
- E-book/audiobook delivery
- Android app
- Web app
- Barcode scanning
- Subscriptions
- Advertising
- Comprehensive event aggregation across every source
- Automatic following of every detected series
- Personalized book recommendation engine

---

# 6. Initial Setup

1. User installs Book Buddy.
2. User imports their Goodreads CSV.
3. Book Buddy imports reading history where available.
4. Book Buddy matches imported books against canonical book metadata.
5. Book Buddy identifies authors and series.
6. User reviews detected series.
7. User chooses which series to follow.
8. User can follow individual books and authors.
9. User configures locations and notification preferences.

---

# 7. Live Search

Book Buddy should allow the user to search for books, series, and authors that are not already in their Library.

The Add/Search interface should support queries such as:

- Book title
- Author name
- Series name
- ISBN

Example:

User searches:

> Funny Story

Book Buddy retrieves live search results and displays information such as:

- Cover
- Title
- Author
- Publication/release date
- Series, when known

The user can select a result and:

- Add it to their Library
- Follow the book
- Add it to the Watchlist
- Navigate to its author
- Navigate to its series

---

# 8. Search Architecture

The iPhone app should eventually search through the **Book Buddy backend**, rather than tightly coupling the application to one external book provider.

Conceptually:

```text
iPhone
   ↓
Book Buddy Search API
   ↓
Book Buddy Backend
   ↓
Internal database/cache
   +
External metadata providers
```

Potential providers include:

- Hardcover
- Google Books
- Open Library
- Future metadata providers

External providers should sit behind a common abstraction.

Example:

`BookMetadataProvider`

Possible implementations:

- `HardcoverMetadataProvider`
- `GoogleBooksMetadataProvider`
- `OpenLibraryMetadataProvider`

The specific provider strategy may evolve without requiring major changes to the iPhone UI.

---

# 9. Search Behavior

Search should:

- Debounce user input
- Avoid requests on every keystroke
- Prefer cached/canonical Book Buddy records where appropriate
- Search external providers when needed
- Deduplicate equivalent books
- Distinguish editions when relevant
- Display useful metadata before selection

Search results should feel responsive.

A debounce of approximately 300–500 milliseconds is reasonable, but this should be treated as an implementation detail rather than a hard product requirement.

---

# 10. Canonical Book Data

Book Buddy should distinguish between:

**A work/book**

and

**An edition**

when the distinction becomes relevant.

For example, hardcover, paperback, Kindle, and international editions should not necessarily be treated as four unrelated books.

At minimum, canonical matching should consider:

- Title
- Author
- ISBN
- External identifiers
- Publication metadata

The architecture should allow more sophisticated work/edition modeling later without requiring it in the earliest implementation.

---

# 11. Storage Architecture

Book Buddy should eventually use two layers of storage.

## Local iPhone Storage

SwiftData should store local application data and cached information required for a responsive experience.

Examples:

- Library
- UserBook records
- Watchlist
- Ratings
- Reviews
- Reading status
- Cached book metadata
- Cached series metadata

The app should remain useful even when network access is temporarily unavailable.

## Book Buddy Backend

As cloud functionality is introduced, the backend database becomes the canonical location for synchronized Book Buddy data.

It should contain:

### Shared/canonical data

- Books
- Authors
- Series
- Series membership
- Releases
- Events

### User-specific data

- UserBook
- Reading status
- Rating
- Review
- Reading dates
- FollowedSeries
- FollowedAuthor
- FollowedBook
- WatchlistItem
- Notification preferences
- Locations
- Notification history

Early milestones may operate entirely locally before the backend is introduced.

---

# 12. Data Deduplication

Shared book metadata should not be unnecessarily duplicated for each user.

For example:

```text
Book
id: 123
title: Example Book
author: Example Author
```

can be referenced by many:

```text
UserBook
userId
bookId
rating
review
status
```

If 5,000 users have read the same book, Book Buddy should generally have one canonical Book record plus user-specific relationships rather than 5,000 independent copies of the same metadata.

---

# 13. Scalability

Book Buddy should comfortably support personal libraries containing thousands of books.

The architecture should not impose an artificially small per-user library limit.

Storage is not expected to be the primary scaling constraint.

More important constraints include:

- External API rate limits
- Search requests
- Release monitoring
- Event monitoring
- AI generation
- Notification scheduling

The architecture should therefore favor:

- Caching
- Deduplication
- Batching
- Shared release checks
- Shared metadata records

---

# 14. Efficient Monitoring

Book Buddy should not independently check the same release once per interested user.

Bad model:

```text
User A → check Book X
User B → check Book X
User C → check Book X
```

Preferred model:

```text
              Book X
                 ↓
        Check release once
                 ↓
       Update canonical release
                 ↓
        Determine interested users
          ↙       ↓       ↘
       User A   User B   User C
```

This approach should also be used where practical for:

- Event monitoring
- Book metadata updates
- Series metadata updates

---

# 15. Ratings and Reviews

Users should be able to rate and review books directly inside Book Buddy.

A book detail page should support:

- Reading status
- Rating
- Review
- Date started
- Date finished

Example:

**My Reading**

Status: Read

Rating: ★★★★½

Finished: September 12, 2026

**My Review**

> I loved the characters but thought the middle dragged.

**Edit Review**

Ratings should support the precision ultimately chosen for the UI, potentially including half-stars.

---

# 16. Book Buddy as Owner of User-Created Data

Any rating, review, or reading information entered directly into Book Buddy should be stored by Book Buddy.

Book Buddy must not require an external service to preserve that information.

If an external provider later becomes unavailable, user-created Book Buddy data should remain intact.

---

# 17. External Reading Synchronization

Hardcover is the preferred initial provider for ongoing reading synchronization.

It should sit behind:

`ReadingDataProvider`

with an initial implementation such as:

`HardcoverProvider`

Book Buddy may import:

- Reading status
- Ratings
- Reviews
- Reading dates
- Library changes

Where supported and desirable, Book Buddy may later synchronize Book Buddy changes back to the external provider.

However, **write-back synchronization is not required for Book Buddy's core functionality**.

Book Buddy remains capable of storing its own ratings, reviews, and reading activity.

Conflict-resolution behavior for two-way synchronization should be explicitly designed before write-back is implemented.

---

# 18. Goodreads Import

Goodreads should be treated primarily as an import source.

Book Buddy should support Goodreads CSV import for fields such as:

- Title
- Author
- ISBN
- Reading status
- Rating
- Review
- Date read
- Date added

Imported books should then be matched against Book Buddy's canonical metadata.

Goodreads should not be treated as a required live API dependency.

---

# 19. Series Identification vs. Following

Book Buddy may identify that a book belongs to a series without automatically following the series.

Example:

User has read:

> The Fifth Season

Book Buddy identifies:

> Broken Earth

The user can see the series and reading progress without receiving monitoring or notifications.

Only after the user chooses:

> **Follow series**

does proactive monitoring begin.

Unfollowing preserves all reading history.

---

# 20. Adding and Following a Series

Users should be able to discover a series through:

- Their Library
- Search
- A book detail page
- An author page

Following a series tells Book Buddy to monitor it for future books and relevant events.

Newly discovered upcoming books may enter the Watchlist.

---

# 21. Following a Book

A user can follow an individual book.

This is useful for:

- Standalone books
- Books from otherwise-unfollowed series
- Upcoming books
- Books discovered outside the user's existing Library

Following the book places it on the Watchlist and enables relevant monitoring.

---

# 22. Following an Author

A user can follow an author independently.

Book Buddy may monitor followed authors for:

- New book announcements
- Upcoming books
- Release changes
- Talks
- Signings
- Launch events
- Other relevant appearances

Relevant upcoming books may be added to the Watchlist.

---

# 23. Watchlist

The Watchlist is the user's persistent actionable list of books they are waiting for or intend to read.

Example:

## Coming Soon

**Murderbot #8**  
May 14, 2027  
Because you follow Murderbot

**New Emily Henry Novel**  
June 2027  
Because you follow Emily Henry

## Released

**Book X**  
Released September 18  
Not yet read

A book remains on the active Watchlist until the user:

- Marks it read/complete, or
- Removes it

---

# 24. Watchlist Lifecycle

States may include:

- Watching
- Released
- Read/Complete
- Removed

The active Watchlist should prioritize:

1. Upcoming books
2. Released-but-unread books

Read books move into the Library/history.

---

# 25. Following and Watchlist Independence

Following determines what Book Buddy monitors.

Watchlist represents books the user is waiting for.

Example:

1. User follows Series A.
2. Book Buddy discovers Book 4.
3. Book 4 enters Watchlist.
4. User later unfollows Series A.
5. Book 4 remains on Watchlist.
6. User can remove Book 4 separately if they no longer want it.

This prevents Watchlist items from unexpectedly disappearing.

---

# 26. Series Model

Series may contain:

- Main novels
- Novellas
- Short stories
- Prequels
- Companions
- Spin-offs
- Other related works

### SeriesBook

- seriesId
- bookId
- position
- type

Series ordering should not assume every series is a simple linear sequence.

---

# 27. Release Tracking

Book Buddy should monitor releases relevant to:

- Followed series
- Followed books
- Watchlist books

Potential sources include:

1. Publisher information
2. Author information
3. Google Books
4. Open Library
5. Other reputable metadata providers
6. Manual correction

Release records should contain:

- Book
- Release date
- Status
- Source
- Source URL
- Confidence
- Last verified
- Previous release date

Confidence:

- Confirmed
- Likely
- Unknown

---

# 28. Release Monitoring Frequency

Suggested monitoring frequency:

- No known date: weekly
- More than 6 months away: weekly
- 1–6 months: 2–3 times/week
- Less than 1 month: daily
- Recently changed date: daily temporarily

These frequencies may be adjusted as the backend architecture and API limitations become clearer.

---

# 29. Release Notifications

### Announcement

Notify when a relevant new book is announced.

### Approximately 3 months

Remind the user why they cared:

- Ratings
- Reviews
- Reading history

### Approximately 1 month

Resurface:

- Reviews
- Ratings
- Personal comments
- Reading history

### Approximately 1 week

Generate:

> **What you need to remember**

### Release day

Notify:

> **It's out!**

The book remains on the Watchlist afterward.

---

# 30. Calendar

Book Buddy should provide a dedicated Calendar.

It may display:

- Release dates
- Author events
- Bookstore/library events
- Book Buddy reminders

Support:

- Month view
- Agenda/list view

Tapping an item should open the relevant:

- Book
- Series
- Author
- Event

---

# 31. AI Recaps

The purpose is:

> **Tell me what I personally need to remember before reading the next book.**

Inputs may include:

- Books marked read
- Reading order
- Ratings
- Reviews
- Reading dates
- Series metadata
- Relevant plot/character information from books already read

Prioritize:

- Major plot developments
- Important characters
- Relationships
- Previous reveals
- Unresolved threads
- Important world-building
- Information likely to matter next

### Hard requirement

**Never spoil a book the user has not read.**

Generated recaps should be cached.

---

# 32. Events

Book Buddy should identify relevant:

- Author talks
- Signings
- Launch parties
- Bookstore events
- Library events
- Festivals
- Conventions
- Reading events
- Promotional appearances

Events may be relevant because of:

- Followed author
- Followed series
- Watchlist book
- Upcoming release

Initial event coverage can use a limited set of reliable sources.

---

# 33. Location

Users should configure locations and radii rather than requiring continuous location tracking.

Example:

**Pittsburgh — 25 miles**

**Cleveland — 50 miles**

No continuous precise location tracking is required.

---

# 34. Data Model

Conceptual entities include:

### Book

- id
- title
- subtitle
- description
- coverURL
- primaryPublicationDate
- publisher
- externalIdentifiers
- lastUpdated

### Author

- id
- name
- metadata
- externalIdentifiers

### Series

- id
- name
- authorIds
- description
- externalIdentifiers

### SeriesBook

- seriesId
- bookId
- position
- type

### UserBook

- userId
- bookId
- status
- rating
- review
- dateStarted
- dateFinished
- source
- sourceId
- lastSynced

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

### WatchlistItem

- userId
- bookId
- addedAt
- addedReason
- status
- completedAt
- removedAt

### Release

- id
- bookId
- releaseDate
- status
- source
- sourceURL
- confidence
- lastVerified
- previousReleaseDate

### Event

- id
- title
- description
- authorIds
- bookIds
- seriesIds
- eventType
- venue
- address
- latitude
- longitude
- start
- end
- source
- sourceURL
- lastVerified

### Notification

- id
- userId
- type
- relatedEntityId
- scheduledFor
- sentAt

---

# 35. App Navigation

Primary navigation:

1. **Library**
2. **Radar**
3. **Calendar**
4. **Settings**

A prominent **Add/Search** action should be accessible from appropriate parts of the app.

## Library

Reading history and personal book data.

## Radar

The proactive Book Buddy dashboard containing:

- Watchlist
- New announcements
- Upcoming releases
- Recently released-but-unread books
- Upcoming events
- Important reminders

Radar answers:

> **What do I need to know about my books right now?**

## Calendar

Chronological releases, events, and reminders.

## Settings

- Reading-data provider
- Notifications
- Locations
- Followed authors
- Followed series
- Data/import
- AI settings
- Account

---

# 36. Backend Architecture

Long-term architecture:

```text
External metadata / reading / event sources
                  ↓
          Book Buddy Backend
                  ↓
     ┌────────────┼────────────┐
     ↓            ↓            ↓
 Database     AI service    Scheduler
                                  ↓
                                 APNs
                                  ↓
                              iPhone App
```

The backend should handle scheduled monitoring.

The iPhone should not be responsible for reliably polling external sources in the background.

---

# 37. Offline and Synchronization Behavior

The app should remain useful without an active internet connection.

Locally available functionality should include, where cached:

- Library browsing
- Ratings/reviews
- Reading status
- Watchlist browsing
- Series progress

Changes made offline should eventually synchronize once connectivity returns after cloud synchronization is implemented.

Detailed conflict-resolution rules should be designed when cloud synchronization is introduced.

---

# 38. Security

Secrets must never be committed to GitHub.

Examples:

- Hardcover credentials
- Google API credentials
- AI credentials
- APNs credentials

Backend secrets belong in environment variables or a secret-management system.

The iPhone should not contain unrestricted backend credentials.

---

# 39. Testing Requirements

Testing should cover:

### Library

- Create/edit UserBook
- Reading statuses
- Ratings
- Reviews
- Reading dates
- Persistence

### Search

- Query behavior
- Debouncing
- Empty results
- Provider failures
- Deduplication
- Selecting a result
- Adding a result to Book Buddy

### Import

- Goodreads CSV parsing
- Book matching
- Ratings/reviews
- Reading status
- Duplicate handling

### Series

- Series matching
- Standalones
- Non-linear series
- Progress calculation

### Following

- Follow/unfollow book
- Follow/unfollow series
- Follow/unfollow author
- Unfollowing preserves history

### Watchlist

- Direct book addition
- Series-generated item
- Author-generated item
- Notification does not remove item
- Released book remains active
- Mark Read removes from active Watchlist
- Remove works without deleting Library history

### Releases

- Announcement detection
- Release-date changes
- Source confidence
- Duplicate handling

### Notifications

- Scheduling
- Cancellation
- Idempotency
- Notification history

### Calendar

- Release display
- Event display
- Reminder display
- Navigation

### AI

- Reading-boundary enforcement
- No unread-book spoilers
- Cached generation

### Events

- Radius filtering
- Duplicate detection
- Date changes

---

# 40. Revised Development Milestones

## M1 — App Shell

- SwiftUI project
- Git repository
- Project structure
- Library / Radar / Calendar / Settings navigation
- Placeholder screens

## M2 — Local Data Model

Build the local foundation:

- Book
- Author
- Series
- SeriesBook
- UserBook
- Reading status
- Rating
- Review
- Reading dates
- SwiftData persistence

Do not introduce backend dependencies yet.

## M3 — Local Library UI

Build a usable local reading tracker:

- Library list
- Book detail
- Mark Want to Read
- Mark Currently Reading
- Mark Read
- Mark DNF
- Rate book
- Write/edit review
- Reading dates

At this point Book Buddy should work as a basic offline reading library.

## M4 — Goodreads Import

- CSV import
- Field mapping
- Book creation/matching
- Ratings
- Reviews
- Reading history
- Duplicate handling

## M5 — Series + Following + Watchlist

- Series model/UI
- Series identification
- Series progress
- Follow/unfollow series
- Follow/unfollow author
- Follow individual books
- Persistent Watchlist
- Watchlist lifecycle
- Manual removal
- Mark Read behavior

## M6 — Live Search

- Search interface
- External metadata provider abstraction
- Book search
- Author search
- Series search where supported
- Result deduplication
- Add/follow from search

This may initially call an external provider directly during development, but the architecture should make migration to the Book Buddy backend straightforward.

## M7 — Hardcover Integration

- ReadingDataProvider abstraction
- Hardcover implementation
- Authentication
- Import/synchronization
- Conflict strategy for external vs. Book Buddy data

Do not implement write-back until conflict behavior is intentionally designed.

## M8 — Backend + Release Tracking

Introduce cloud infrastructure:

- Backend API
- Database
- Canonical book metadata
- Search caching
- Release ingestion
- Shared release monitoring
- User synchronization

## M9 — Notifications + Calendar

- Push notifications
- Release announcement
- Countdown reminders
- Release-day notification
- Calendar integration
- Idempotency

## M10 — AI Recaps

- Personalized recap generation
- Reading-boundary enforcement
- Review/rating context
- Caching

## M11 — Events

- Event model
- Initial sources
- Location filtering
- Event notifications
- Calendar integration

## M12 — Polish

- Onboarding
- UI refinement
- Error handling
- Performance
- Settings
- Accessibility
- Testing

## M13 — Friends / Multi-user Expansion

Only after the personal product works well:

- Full authentication
- Multi-user refinement
- Sharing
- Friend-specific functionality

---

# 41. First Meaningful Release

The first meaningful personal version should allow the user to:

1. Import their Goodreads library.
2. Browse their Library.
3. See series and series progress.
4. Record reading status.
5. Rate books.
6. Write/edit reviews.
7. Follow/unfollow series.
8. Follow books and authors.
9. Maintain a persistent Watchlist.
10. Search for books not already in the Library.
11. Add those books to Book Buddy.

This version does **not** require:

- AI recaps
- Comprehensive events
- Push notifications
- Automated release monitoring
- Multi-user support

Those capabilities should be layered onto a useful core product.

---

# 42. Ultimate Success Criterion

Book Buddy should make the user feel:

> **I don't have to remember which books I'm waiting for, when they come out, why I cared about them, what happened in the previous books, or which author events I might want to attend. Book Buddy remembers for me.**

And:

> **I decide what Book Buddy watches.**

Book Buddy should feel like a thoughtful personal assistant for the user's reading life rather than another platform that requires constant maintenance.