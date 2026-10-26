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
