# OpenWC

**A little relief. A more open city.**

A native SwiftUI iPhone app by **Vojtěch Klepáček** for community-shared toilet access information. Dark purple by default, with light/system appearance and a floating glass navigation bar.

## Features

- Apple Maps business pins, optional location centering, and nearby places sorted by distance within 5 km.
- A permanently visible nearby search field and navigation that reserves its own space.
- Email registration/login, session restoration, password visibility, confirmation and terms acknowledgement.
- A prominent + action to share a place, toilet code, access notes, step-free information and an optional photo.
- Business search **or manual map placement**: move the map beneath the pin, confirm the location, and enter the place name.
- Code copying, walking directions, contribution history and broken-code reports.
- In-app terms, privacy policy, copyright notices and private account/data request tracking.
- Separate, clearly labelled fictional demo that cannot publish.

## Run in Xcode

You need a Mac with **Xcode 26 or newer**. Deployment target: iOS 17+. Native Liquid Glass is used on iOS 26+, with a system-material fallback on older versions.

1. Open `OpenWC.xcodeproj`. Do not create a new Xcode project.
2. Allow Swift Package Manager to resolve **Supabase Swift 2.55.4**.
3. Select the **OpenWC** scheme and a specific **iPhone simulator**.
4. Press **⌘R**. Use **Explore a demo**, or register and confirm your email if requested.
5. For a physical iPhone, select your Apple development team in Signing & Capabilities and set your own unique bundle identifier.

Debug explicitly uses `ONLY_ACTIVE_ARCH=YES`; Release uses `NO`. If an old copy still gives a Supabase incompatible-target error, verify that you opened this project and selected an iPhone simulator. Capture the full build log if the error persists; this setting is a correction, not a verified diagnosis of every possible target mismatch.

## Backend

This working copy contains the existing OpenWC project's URL and public publishable key in `Config.xcconfig`. Publishable keys are designed for clients; row-level security controls database access. Never add a secret/service-role key to the app or repository.

The connected project is `vpqezabichkjiwllczsg`, in EU Frankfurt. **Both SQL files have already been applied there. Do not rerun them against that project.** Existing contributions are preserved.

The community update also applies `Database/community_features.sql`, adding private profiles, saved places, current code checks and an authenticated aggregate-summary RPC. It has already been applied to the connected project. The worldwide/profile-photo update additionally applies `Database/worldwide_profiles.sql`; it is also already applied there. Raw voter identities stay private; only counts and recent check/report times are shared.

For your own empty Supabase project:

1. Apply `Database/schema.sql`, then `Database/account_requests.sql`, then `Database/community_features.sql`, then `Database/worldwide_profiles.sql`.
2. Put its URL and publishable key in `Config.xcconfig`.
3. Configure authentication/email confirmation and production SMTP.
4. Review the RLS/storage policies and operational settings.

Places are authenticated community records. Anonymous clients cannot read codes. Inserts require the contributor's own account ID. Photos are public assets; uploads and cleanup are restricted to the owner's folder. Private reports and account requests are readable only by their submitter and administrators.

Discovery now uses an authenticated geographic query for the selected area, with a configurable 5–50 km radius and up to 200 nearest results. Search centers sent to the backend are rounded to 0.001 degrees; exact business coordinates remain part of shared listings. A latitude/longitude index narrows candidate rows, and a clamped haversine distance handles international coordinates and the date line. With very large datasets, a PostGIS index/pagination would be the next scaling step. Personal contributions and saved-place records are loaded independently of the selected city (up to 200 place records per group).

## Legal and ownership

**© 2026 Vojtěch Klepáček. All rights reserved.** No general open-source license has been chosen for the original project. Third-party dependencies keep their own licenses; see `LICENSE` and `Legal/COPYRIGHT.md`.

The documents in `Legal/` are bundled into the app and accessible before registration and from Settings. They are **development drafts**, not a declaration that the app is legally compliant or ready for the App Store. Email: [vojtechklep@gmail.com](mailto:vojtechklep@gmail.com). GitHub: [vojtikdev](https://github.com/vojtikdev). Discord: **vojtikdev**. Use email for private privacy, account, security or copyright requests; do not post sensitive details in public issues.

Before public app launch:

- Complete and verify controller details and operational arrangements.
- Finalize retention, backup expiry, provider/transfer arrangements, moderation, age safeguards and a request-handling process.
- Have the legal text reviewed for the actual jurisdictions and operating arrangements.
- Publish the privacy notice at a stable public URL for the App Store listing.
- Complete required privacy disclosures/manifests and dependency-license inventory against the resolved SDKs and actual behavior.
- Run native builds and device tests, configure production email, and review password/security settings.

### Privacy/account request operations

Settings → Privacy & account requests inserts a private request into `public.account_requests`. This is a **manual queue**, not automatic account deletion. The operator must actively monitor it in Supabase, verify the request, fulfill applicable rights and time limits, and communicate the outcome. The app shows pending/processing/completed status. Ordinary members cannot set status or read other users' requests.

For deletion, revoke sessions; remove all related photos using their storage paths; delete account-associated contributions, reports and request records; then delete the Auth account using secure administrative tools. Database cascades do not delete Storage files. Handle token expiry, backups and any required lawful retention deliberately. Never embed administrative credentials in the iOS client. Record any required operational audit outside the app's public tables and notify the user through a verified private channel.

## Verification

Run the local packaging check:

```sh
python3 scripts/check_project.py
```

This checks deterministic project generation, all Swift/resource references, legal-resource inclusion, plist/scheme/asset formats, architecture settings and the pinned SDK. It **does not compile Swift**.

The GitHub Actions workflow in `.github/workflows/ios-build.yml` compiles the app and runs three iPhone simulator UI tests. The latest feature update passed on Xcode 26.6: [verified build and UI tests](https://github.com/vojtikdev/OpenWC/actions/runs/40300631933). The tests cover Settings actions staying above the footer (including the pushed privacy page), Nearby search with a keyboard, and exact-pin selection without a business-search result. The exact `Package.resolved` produced by that build is committed to lock transitive dependencies. This verifies compilation and the specified simulator interactions, not every device, provider result or authenticated flow.

Backend checks performed in rolled-back transactions: own request insertion/read, ownership-spoof rejection, rejection of client-supplied request status, cross-user request isolation, and anonymous denial. No temporary test accounts or requests are retained. Existing place data is preserved. The security advisor currently reports leaked-password protection disabled; review the setting before launch.

**Remaining checks:** iOS rendering, keyboard behavior, pin positioning on device, email delivery, and signup/photo upload end to end. The remote CI build passed; this editing environment itself has no Xcode or iOS Simulator. The location delegate uses an explicit preconcurrency conformance; the project currently builds in Swift 5 language mode.

### Manual acceptance checks

1. On a small iPhone and large text, open login/register, toggle password visibility, check validation/errors and confirmation-email feedback, and open both legal links.
2. Open Nearby, search with the keyboard open, scroll to the final row and confirm neither search nor rows hide under the glass bar. Test iOS 17/18 and 26/27.
3. Search for a business, adjust its pin, cancel without changing it, then confirm. Also add a place using only a manual pin and name, with location permission denied.
4. Add a photo and submit; verify the stored coordinate and photo from a second account. Verify invalid names/codes cannot be submitted.
5. Submit a private data request and check status/history. Verify another account cannot read it and the client cannot mark it completed.
6. Verify demo isolation, logout/session restoration, permission denial, network failures, light mode, VoiceOver and map attribution.

## Repository layout

- `OpenWC/`: SwiftUI screens, state, location and models.
- `Legal/`: legal documents bundled as resources.
- `Database/`: schema, storage policies and account-request queue.
- `OpenWC.xcodeproj/`: generated project and shared run scheme.
- `make_project.py`: deterministic project generator (Python standard library).
- `scripts/check_project.py`: packaging checks.
- `.github/workflows/ios-build.yml`: macOS simulator build workflow.

The Figma file could not be accessed during implementation; the design follows the written brief.

## Contact

Email: [vojtechklep@gmail.com](mailto:vojtechklep@gmail.com). GitHub: [vojtikdev](https://github.com/vojtikdev). Discord: **vojtikdev**. Use email for private privacy, account, security or copyright requests; do not post sensitive details in public issues.

## Community and discovery update

- Pin placement suggests the nearest Apple Maps business within 500 m. Search selects the nearest returned match to the pin/current search area and offers alternatives. Map coverage is provider dependent; it cannot guarantee every business is returned. Keep-exact-pin mode remains available.
- Search requests are debounced and older responses are ignored. Street/square queries can anchor a nearby-business lookup. Names/addresses remain editable before publishing.
- The bottom navigation now occupies a separate VStack footer instead of overlaying any page or pushed Settings content. Lists/forms retain bottom scroll space.
- Original business monogram badges cover McDonald’s, Five Guys, Burger King, KFC, Bouda Burgers, Subway, Bageterie Boulevard and Starbucks; other venues use a storefront icon.
- Edit your private display name, bio, avatar and accent from Profile. The overview shows loaded contributions, saved places, current code checks and a seven-day snapshot. It does not collect visit/location history.
- Save places for later and filter Nearby by Saved, Step-free or Needs recheck.
- A reported code prompts other visitors on its detail page to confirm working/broken status. One current vote per account/place, server timestamps, and 30-day aggregates prevent repeated votes from inflating counts. Two recent working votes with a working majority clear the recheck flag; conflicting/negative votes remain visible in the counts. Votes are community assertions, not proof that someone visited a venue.
- Profile, favorites and raw vote RLS are owner-only. The summary function has a narrow authenticated interface in a private schema, a fixed search path, no dynamic SQL and a 1000-place request bound. Clients cannot assign check timestamps or alter another member’s profile/vote.

### Community update verification

The three UI tests passed with zero failures. The backend also passed rolled-back tests for profile editing/upsert and ownership protection, private saved/profile/vote records, changed votes remaining a single record, correct two-user aggregate counts, server-only check timestamps, and anonymous summary denial. No temporary test accounts/votes were retained. Live nearest-business accuracy, authenticated profile screens, cross-device layouts and full signup/photo flows remain manual device acceptance checks.

## Worldwide browsing and profile photos

- The map renders behind the glass navigation and bottom safe area; non-map pages keep a reserved footer. Map attribution receives clearance for the measured footer height.
- Use the globe to search any city/district/address, pan and tap Search this area, or recenter Near me. The picker applies no country filter. Provider map/search coverage still varies, and shared codes only exist where people contribute them.
- Choose a radius and sort Nearby by distance, newest or most confirmed. Saved places remain accessible across cities; sharing and copying addresses use system controls.
- Profile now supports a custom display name/bio plus a selected photo, center-cropped preview, replacement and removal. Files are private and immutable, with owner-only policies and temporary signed display URLs. Upload failure rolls back the new photo; old-file cleanup is best effort and must also be handled in account deletion.
- Profile edits can be previewed in demo mode; those changes/photos stay in the current session and are not uploaded.
- The privacy notice explains approximate search-center requests and private profile-photo processing.
