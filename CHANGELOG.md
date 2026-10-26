# Changelog

## 2026-10-26 — Account, navigation and legal update

- Replaced the basic account form with login/register modes, labelled fields, password visibility, registration confirmation and inline feedback.
- Registration requires terms acknowledgement and records its version/time. Login does not impose the registration password-length rule.
- Reserved bottom safe-area space for the floating glass navigation.
- Moved nearby search into an always-visible top inset, avoiding system bottom-search overlap.
- Added manual map pin placement, coordinate confirmation, editable business names/addresses and adjustment of searched locations.
- Added bundled Terms of Service, Privacy Policy and copyright notices credited to Vojtěch Klepáček.
- Added a private, manually processed data/account-request queue with ownership policies and status isolation.
- Updated the storage upload call, pinned Supabase Swift 2.55.4, preserved the Debug active-architecture correction, and added a macOS build workflow.

Legal pages remain development drafts pending a public contact, finalized operational policies and review. The first published GitHub Actions simulator build passed on Xcode 26.6. Device and visual testing remain outstanding.

- Added the operator’s supplied public email, GitHub and Discord contact details to legal documents and in-app requests.
- Published the source and commit history, verified the first macOS simulator build, and retained its resolved dependency lockfile.

## 2026-10-26 — Smarter discovery and community checks

- Automatic nearest-business suggestions for map pins and distance-ranked business search, with manual override.
- Debounced searches and stale-response cancellation; business monogram badges on maps, results and cards.
- Separate navigation footer, visible nearby search and bottom-safe scrolling in Settings, Profile and pushed pages.
- Editable private profiles; saved places; personal contribution overview and check chart; useful nearby filters.
- Working/broken community checks, recheck prompts, 30-day counts and server-controlled vote timestamps.
- Added owner-only profiles/favorites/check records and authenticated anonymous-voter aggregate summaries; verified ownership, isolation, repeat-vote behavior and timestamp protections in a rolled-back database test.

- Verified the updated app builds on Xcode 26.6 and all three iPhone simulator UI tests pass (Settings footer clearance, search with keyboard, exact pin selection).
- Verified profile upserts/ownership and community vote privacy/count/timestamp protections in rolled-back backend tests; no synthetic votes or test accounts retained.

## 2026-10-26 — Full map, worldwide discovery and personal photos

- Removed the map’s solid footer gap while preserving clearance on other pages.
- Added worldwide city/address search, viewport search, search radius and sorting; saved/contributed places load independently of the active city.
- Added private uploaded profile photos, downsampled/cropped previews, photo replacement/removal and demo profile editing.
- Added share-place/address-copy actions and improved distance labels.
- Added geographic queries with date-line-safe distances and updated privacy text for approximate server-side area searches.
- Added UI checks for full-height map rendering, city-search access and custom profile names/photo entry.

- Verified five UI tests on Xcode 26.6 with no failures, including the full-height map and custom demo profile name; reviewed map, profile and Settings screenshots.
- Verified worldwide/date-line geographic queries and private avatar ownership/removal constraints in rolled-back database checks.
- Reverified all five tests after adjusting MapKit attribution margins; the full-screen map and unobstructed Apple Maps attribution are confirmed in the retained screenshot.
