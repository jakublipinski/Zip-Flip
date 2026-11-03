# Zip Flip

Flashcards on your wrist, fed by a Google Sheet.

Zip Flip is an independent watchOS app. It does not need an iPhone, so it runs on an Apple Watch that was set up for a child through Apple Watch For Your Kids (formerly Family Setup). You keep your cards in a Google Sheet, share the sheet by link, send the link to the watch, and flip.

**Status:** design stage, November 2026. No app code yet. This README is the design record and will grow with the project.

Website: https://zip-flip.app (coming)

## How it will work

1. Put your cards in a Google Sheet, one tab per deck. Column A is the front of the card, column B is the back.
2. Share the sheet as "Anyone with the link" (viewer).
3. Send a Zip Flip link to the watch, for example by iMessage. Tapping it opens the app and loads the spreadsheet. Each tab shows up as a deck, named after the tab.
4. Pick a deck and flip through its cards. Mark each one Got it or Again. Repeat whenever you have a minute. Practice any deck at any time without touching the schedule.

No account, no sign-in, no iPhone app, no server that sees your cards.

## Why this exists

Three things together: a watch-only app, your own content, and no sign-in. At the time of writing we could not find an app that combines them. Watch flashcard apps ship fixed content or depend on an iPhone companion. Sheet-based flashcard apps live on the phone. A child's watch set up through Family Setup has no iPhone attached, so companion apps are not even installable there.

## Design decisions

Each entry records what was decided, why, and what follows from it. Dates are when the decision was made. Decisions marked *working assumption* will be confirmed or revised once there is running code.

### 1. Independent watchOS app, no iOS companion (2026-10)

**Decision.** Zip Flip is a standalone watchOS app with "Supports running without iOS app" enabled. There is no iPhone app and there will not be one in v1.

**Why.** The target device is a child's watch set up through Family Setup. Such a watch has no paired iPhone, and watchOS apps that require a companion cannot be installed on it. Everything the app needs has to live on the watch.

**Consequences.** No WatchConnectivity. Networking, storage, onboarding and settings all run on the watch. Any feature that would be easier on a phone is either done on the watch or not done.

### 2. Data source is a link-shared Google Sheet read through the CSV export endpoint (2026-10)

**Decision.** The app reads a sheet that is shared as "Anyone with the link". It downloads the sheet through Google's CSV export URL, which takes the spreadsheet ID and an optional tab (`gid`) and returns plain CSV without authentication.

**Why.**
- No Google sign-in on the watch. OAuth flows on watchOS are impractical, and a child's watch has no good place to enter credentials.
- No API key. The alternative, Sheets API v4 with an API key, would put a key into an open-source repository. The CSV endpoint needs none.
- Not "Publish to web". Publishing creates a long opaque token, republishes on a delay, and is a second thing for the sheet owner to remember. Link sharing uses the normal 44-character spreadsheet ID that is already in the sheet's URL, and edits show up on the next refresh.

**Consequences.** Private sheets are not supported, by design. The owner must set link sharing. The app never sees a Google account. Google could change the export endpoint, so the parser is kept small and isolated. Observed 2026-11-03: the export answers with a 307 redirect to a `googleusercontent.com` download host and the CSV comes from there, so the client follows redirects and judges the final answer by its status and `text/csv` content type, not by its host; an unknown id answers 404; a deleted tab's `gid` answers 400; the export's `Content-Disposition` header carries `<spreadsheet title> - <tab name>.csv`, which is where the app learns the title and notices renamed tabs.

### 3. The sheet reaches the watch through a Universal Link (2026-10, link form revised 2026-11-01)

**Decision.** The primary way to get a sheet onto the watch is a link of the form `https://zip-flip.app/s/?id=<spreadsheetId>`. Sent by iMessage or Mail and tapped on the watch, it opens Zip Flip directly and adds the spreadsheet, whose tabs become decks. The website serves the Apple App Site Association file that makes this work, and the app declares the Associated Domains entitlement. The id travels as a named query item rather than as a path segment so that a static site can answer the link with a real page (decision 16), and so the association file can require the item: a bare `/s/` opens nothing.

**Why.** The watch has no camera for QR codes, no NFC for third-party apps, no clipboard shared with other devices, and custom URL schemes are not available on watchOS. Typing a 44-character ID on a watch is miserable, and the SE models have no keyboard at all. Universal Links are the one transport that works on every Family Setup watch (watchOS 7 and later) and feels natural to a parent: share a link.

**Fallbacks considered.** A short pairing code backed by a small service (possible later, if link sharing proves awkward). Manual entry by dictation or Scribble (last resort, always available). Baking a sheet ID into a TestFlight build (fine for personal use, not a product).

**Consequences.** The web domain is part of the product, not just a landing page. The same link opened on a phone or desktop must show a useful page, since people will tap it there too.

### 4. The domain is zip-flip.app (2026-11-01)

**Decision.** All links use `https://zip-flip.app/...`.

**Why.** The `.app` top-level domain enforces HTTPS, which Universal Links require anyway. The unhyphenated spellings were not available.

### 5. One spreadsheet, one tab per deck, two columns (2026-11-01, working assumption)

**Decision.**
- The app holds one spreadsheet. Every tab in it is a deck, named after the tab. Tabs hidden in Google Sheets are skipped.
- Column A: front. Column B: back. Other columns are ignored. There is no hint column.
- Rows where A or B is empty are skipped.
- If the first row reads "front" and "back" (case-insensitive) it is treated as a header and skipped. Otherwise there is no header.
- Any text works: words, definitions, dates, formulas, capital cities. The app does not care what the cards are about.
- Opening a new Zip Flip link replaces the spreadsheet. Progress for the previous one stays on the watch, so switching back loses nothing.

**Why.** Tabs are how people already organise a spreadsheet by subject, so a family's sheet with tabs for Spanish, capitals and times tables needs no reformatting. Renaming a tab renames the deck. A tab's internal id (`gid`) never changes, so renaming keeps the progress. Hiding a tab is a natural way for the owner to park a deck without deleting it. There is no hint column because a hint is a third thing to author, a card that needs one is usually better split into two cards, and a 40 mm screen has no room for it anyway.

**Consequences.** The CSV endpoint can download a tab but cannot list tabs. The app therefore reads the spreadsheet's HTML view (`/htmlview`), which embeds one script entry per visible tab with its name and `gid`, then downloads each tab as CSV. This is the one piece of fragile parsing in the app. It is kept in one small, isolated parser, and if it fails the app falls back to the first tab as a single deck. Verified on 2026-11-01 against a public single-tab sheet and on 2026-11-02 against the project's own test sheet with five tabs: the HTML view lists the four visible tabs in display order, an empty tab included, and omits the hidden one, while the CSV export still serves a hidden tab's `gid` on request. The tab list therefore comes from the HTML view only; the app never guesses `gid` values. The export itself is UTF-8 with CRLF record separators, quotes fields that contain commas or line breaks (the line break inside a quoted field is a bare LF), writes an empty row as `,,`, leaves numbers unformatted, and answers an empty tab with an empty body and status 200.

### 6. Offline first (2026-11)

**Decision.** The last downloaded deck is cached on the watch. Studying works with no network. The app refreshes the deck when it is opened and the network is available.

**Why.** A child's watch is on Wi-Fi or cellular intermittently. A flashcard session should never fail because of connectivity.

**Refresh policy (2026-11-02).** The cards and the tab list refresh on different clocks. Measured on the five-tab test sheet, Google sends the HTML view that carries the tab list as about 19 KB gzipped per request, while each tab's CSV is a few hundred bytes, and no endpoint allows a conditional request (every response is marked no-store, without an ETag), so each refresh pays the full price. The app therefore re-downloads the CSVs on launch when the cache is older than a few hours, and re-reads the tab list only when a link is opened, on a manual refresh, when a tab's CSV answers 400 because the tab was deleted, and otherwise at most once a day. A renamed tab is noticed from the CSV alone, because the export's Content-Disposition header carries the tab's name. Alternatives measured and set aside the same day: the gviz JSON endpoint (same data as CSV, three times the size, drops empty rows, guesses header rows), the zipped web-page export (one 5 KB request for the whole workbook, but hidden tabs are indistinguishable and it means parsing Google's grid HTML), the xlsx export (has the hidden flag but not the `gid`), and the Sheets API with an API key (one small JSON request, but a Google Cloud project to own for the app's lifetime and a key in the binary). CSV stays because it is the official export with exact quoting rules and needs nothing from us.

### 7. Scheduler: a doubling ladder with two answers (2026-11-01, working assumption)

**Decision.** Two answers per card: **Got it** and **Again**. Each card sits on a ladder: level 0 is a card not yet learned or just forgotten, and levels 1 to 8 set the gap until the card is due again, in days: 1, 2, 4, 8, 16, 32, 64, 128. Got it moves the card up one level. Again sends it back to level 0 and shows it again later in the same session until it gets a Got it, which puts it on level 1, due tomorrow, the same as a new card that gets Got it on first sight. Gaps of four days or more get up to ten percent of random extra, rounded down to whole days, so cards do not pile up on one day; in practice the extra starts at the 16-day gap. Days are local calendar days.

**Why.** We compared the SuperMemo family (SM-2 from 1987 through SM-20), Anki's SM-2 variant, FSRS and the Leitner box system.

- SM-2 wants a grade from 0 to 5. With two answers, Got it is grade 4, and in SM-2 a grade of 4 leaves the ease factor unchanged, so the algorithm degenerates into a fixed geometric ladder (1, 6, 15, 37, 94 days). We take the ladder directly and make the early steps gentler.
- FSRS needs roughly 20 to 30 percent fewer reviews than SM-2 for the same retention, but it carries 21 fitted parameters, wants review history to optimise against, and its intervals cannot be explained to a child. On a watch session of a minute or two the saving does not pay for the opacity.
- Leitner's boxes are exactly this ladder, and "a card climbs a ladder, a miss sends it back down" is an explanation a child can hold. Common Leitner schedules run 1, 2, 4, 7, 15, 31, 64 days, and Anki's default also returns a lapsed card to one day.
- Two buttons, not four. Hard and Easy are misused even by adults, which the FSRS documentation warns about, and two-button grading is an accepted mode even for FSRS. Two big buttons are also all a 40 mm screen has room for.

**Consequences.** Per-card state is one small integer plus a date. The scheduler is a pure function and can be tested without a device. A smarter scheduler can later slot in behind the same two-button interface, and stored state stays usable because any scheduler can be seeded from a level and a due date.

### 8. Privacy by construction (2026-11)

**Decision.** No accounts, no analytics, no tracking SDKs. The spreadsheet ID and the cached cards live on the watch. Card content is fetched directly from Google. The only server component is the static website that hosts the Apple App Site Association file and the landing page.

**Why.** The app is aimed at children's watches. The simplest way to handle their data responsibly is not to have it.

### 9. Swift and SwiftUI, minimum watchOS 10 (2026-11, working assumption)

**Decision.** Native Swift and SwiftUI. Minimum deployment target watchOS 10.

**Why.** Family Setup requires Apple Watch Series 4 or later, or an SE. Series 4, Series 5 and the first SE top out at watchOS 10, so watchOS 10 is the newest target that still reaches every watch a child could be using.

### 10. Distribution through the App Store, testing through TestFlight (2026-11, unverified)

**Decision.** Ship through the App Store. Test on real Family Setup watches through TestFlight.

**Why.** Reports from other developers suggest that a watch set up through Family Setup does not appear in Xcode as a run destination and has no Developer Mode toggle. TestFlight installs from the watch itself. This needs to be verified on a real device before it is treated as fact.

### 11. The name is Zip Flip (2026-11-01)

**Decision.** The app is called Zip Flip. On the watch and in the App Store it appears as "Zip Flip", two words.

**Why.**
- It rhymes, so it sticks after one hearing.
- It sounds like what it is: a quick flip of a card.
- It describes the action, not the content, so it fits vocabulary, history dates, maths facts and anything else someone puts in a sheet.
- It is short enough to sit under a watch icon without truncation, and it spells the way it sounds in most languages.
- It is playful. A child can say it without it sounding like homework.

Names that described the data source or the device were rejected, partly because they boxed the app in and partly because the obvious words belong to other companies' brands.

### 12. Open source under Apache 2.0 (2026-11-01)

**Decision.** The code is public under the Apache License 2.0. See [LICENSE](LICENSE).

**Why.** A learning tool for children should be inspectable. Apache 2.0 allows reuse while keeping the name and any marks out of the grant.

### 13. A session shows due cards first, then a few new ones, in short bites (2026-11-01, working assumption)

**Decision.** The home screen lists the decks with the number of cards due in each. Opening a deck builds a queue: every card due today or earlier, sorted by due date with ties shuffled, then new cards in sheet order, at most 5 new cards per deck per day. A session shows at most 20 cards and then offers to continue if more are waiting. A card answered Again returns to the queue a few cards later. When nothing is due and today's new cards are done, the app says so and shows when the next card is due.

**Why.** Due cards are the ones about to be forgotten. New cards are the expensive ones, since each will come back many times, so they are rationed. Sheet order is the owner's order, usually the order they want things learned. Shuffling within a due date stops the child learning the sequence instead of the cards. Twenty cards is about a minute on the wrist. Anki uses the same "due date, then random" order and a daily new-card limit.

**Consequences.** After a long break the backlog clears over several short sessions instead of one wall. The new-card limit and the session size are constants in v1 and may become settings later.

### 14. Progress lives on the watch, one JSON file per deck, keyed by the card's front text (2026-11-01, working assumption)

**Decision.** The app keeps, in its Application Support directory, one folder per spreadsheet. In it: a small metadata file (fetch time, tab list) and, per tab, the last downloaded CSV and a progress file named by the tab's `gid`. The progress file maps a card key to level, due date, review count, lapse count, the day the card was first answered (which counts against the daily new-card allowance) and last review date, under a schema version. The card key is a hash of the normalised front text: Unicode NFC, trimmed, inner whitespace collapsed, case folded. Files are written atomically after every answer. Settings and the current spreadsheet id live in UserDefaults.

**Why.**

- The sheet belongs to its owner and the app never writes to it, so progress has to live elsewhere, and decision 8 rules out a server.
- Front text is the only identity a plain sheet has. Rows get inserted, sorted and deleted, so row numbers are useless. Hashing the front means fixing a typo in an answer keeps the progress, while rewriting a question starts it fresh, which is what a teacher would want.
- Keying the deck by `gid` rather than tab name means renaming a tab keeps its progress, and reordering tabs changes nothing.
- A Codable JSON file beats SwiftData or Core Data here. The data is a dictionary of a few hundred small records, a file is readable in a debugger and exportable through the share sheet, and there is no migration machinery to carry.

**Consequences.** Duplicate fronts in a tab collapse into one card, and the first row wins. Progress for rows or tabs that disappear from the sheet is kept for 180 days and then pruned. Deleting the app deletes progress; there is no cloud copy in v1. An optional id column, for identity that survives question edits, can be added later without changing the file format.

### 15. Practice mode never touches the schedule (2026-11-01)

**Decision.** Every deck offers Practice beside its session. Practice shows the deck's cards in random order, twenty at a time, with the same flip and the same two buttons, and writes nothing: no level, due date or count changes.

**Why.** A child who finishes the session and wants to keep going should be able to, and a parent quizzing before a test wants to run the whole deck. If that touched the schedule it would either inflate levels, as cards answered right several times in one evening raced up the ladder, or punish, as one Again reset a well-known card. Keeping practice free of side effects keeps the scheduler honest.

**Consequences.** Practice is a read-only view of the deck and is cheap to build. It is the answer to "I have nothing due but I want to play", so the end-of-session screen offers it.

### 16. The website is static and hosted on GitHub Pages (2026-11-01)

**Decision.** Everything under zip-flip.app is static HTML in the `web/` folder of this repository, deployed to GitHub Pages by a workflow on every push that touches it, with the custom domain set through a `CNAME` file and HTTPS enforced. The site carries the landing page, the privacy and support pages the App Store requires, and the Apple App Site Association file at `/.well-known/apple-app-site-association` that makes Universal Links work. The upload action excludes dot-prefixed paths by default, so the workflow sets `include-hidden-files: true`; without it the first deploy published everything except `.well-known` (2026-11-02).

**Why.** The site has no dynamic content, and Pages is free, versioned with the code, and already proven with the same layout in another watch app of ours. The `.app` top-level domain requires HTTPS, which Pages provides for custom domains.

**Consequences.** Pages serves only files that exist, so the spreadsheet id travels in the query string. `https://zip-flip.app/s/?id=<spreadsheetId>` is answered by `web/s/index.html` with a normal 200 status, and Pages redirects the slash-less `/s?id=...` to it with the query intact (checked 2026-11-01 against a live Pages site). That page is the landing page: it reads the id from the address, explains that the link is meant to be tapped on the watch, and links to the sheet itself. The earlier idea of a `/s/<spreadsheetId>` path answered by `404.html` was dropped because it would have shipped every link with a 404 status, which link previews may refuse to render.

The association file matches path and query together, with and without the trailing slash, so only a link that carries an id opens the app:

```json
"components": [
  { "/": "/s",  "?": { "id": "?*" } },
  { "/": "/s/", "?": { "id": "?*" } }
]
```

Matching happens on the tapped URL before any request reaches the site, so an installed app never loads the page. If the app is not installed, Messages on the watch shows the page in its reduced web view, so the page must be small and must say how to install the app (to verify on a real watch). Apple requires the association file over HTTPS with a valid certificate and no redirects, so the apex domain must serve it directly. Verified 2026-11-02 after the first deploy: Pages serves the file with status 200, no redirect and the generic `application/octet-stream` type, and Apple's CDN accepted it as is, returning the same content at `https://app-site-association.cdn-apple.com/a/v1/zip-flip.app`.

### 17. Zip Flip looks like a sibling of Silent Bell (2026-11-01)

**Decision.** Zip Flip shares its visual bones with Silent Bell, the first app in this family, so the apps are recognisable as coming from the same place: black ground, warm greys for text, Newsreader for display lines, system type everywhere else. Each app gets one field colour and one flat geometric glyph for its icon. Silent Bell's field is sand; Zip Flip's is teal (`#6EB6CF`). The two answers differ in lightness as well as hue: Got it is a filled teal button on the right, Again a dark grey one on the left.

**Why.** More apps are planned. A shared look costs nothing on a one-person team and lets each app vouch for the others. The icon rules come from App Review experience: a watchOS icon is masked to a circle on a black honeycomb, so a dark field has no visible edge and gets rejected as a placeholder.

**Consequences.** The website reuses Silent Bell's page skeleton, self-hosted fonts and cookie-free GoatCounter visit counting, with a separate GoatCounter site for Zip Flip, disclosed on the privacy page. The app itself stays free of analytics (decision 8). The hero line is the descriptive "Flashcards from Google Sheets."; "Know zip? Flip." closes the page. The home page carries a slot for a short demo video, self-hosted rather than embedded from a video platform, and a link maker that turns a pasted Google Sheets address into a Zip Flip link inside the browser. The icon glyph is two cards with the top one caught mid-turn, dark on the teal field (chosen 2026-11-01 from three directions). Design boards live in a private design canvas, not in the repository; the production assets (SwiftUI views, the icon rendered by a script, the web folder) are built from the approved boards.

## Non-goals for v1

- An iPhone app.
- Google sign-in or private sheets.
- Editing cards on the watch.
- Cloud sync of progress between devices.
- Images, audio or rich text on cards.
- Hints, notes or any third column.

## Open questions

- Verify that TestFlight is a workable path to a Family Setup watch. Direct installs are out: on 2026-11-01 `xcrun devicectl list devices` on a Mac next to such a watch listed only the developer's own paired watch and iPhone.
- Confirm how the HTML view behaves for a spreadsheet with dozens of tabs. Five tabs, one hidden and one empty, are confirmed (decision 5).
- Background refresh cadence, and whether watchOS background tasks are worth the complexity for v1.
- Whether a pairing-code service is ever needed, or whether links are enough.
- How a Family Setup watch presents the landing page when a link is tapped before the app is installed, and whether an App Store link on that page opens the watch App Store.

## Planned repository layout

```
README.md          this file, the design record
LICENSE            Apache 2.0
project.yml        XcodeGen definition of the two targets; the .xcodeproj is generated, not committed
ZipFlip/           watchOS app sources (SwiftUI)
ZipFlipContainer/  the empty iOS container that carries the watch app to the App Store
ZipFlipCore/       Swift package: parsers, scheduler, session planner, progress store, tested with swift test
scripts/           run.sh, check-ui.sh, shots.sh, release.sh
tools/             makeicon.swift and the simulator input helpers
web/               static site for zip-flip.app on GitHub Pages, including the AASA file
```

## Contributing

Issues and pull requests are welcome. If you propose a change to one of the decisions above, open an issue first and say which decision it affects and why.
