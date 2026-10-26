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

For your own empty Supabase project:

1. Apply `Database/schema.sql`, then `Database/account_requests.sql`.
2. Put its URL and publishable key in `Config.xcconfig`.
3. Configure authentication/email confirmation and production SMTP.
4. Review the RLS/storage policies and operational settings.

Places are authenticated community records. Anonymous clients cannot read codes. Inserts require the contributor's own account ID. Photos are public assets; uploads and cleanup are restricted to the owner's folder. Private reports and account requests are readable only by their submitter and administrators.

The app loads places in one request, subject to the backend's default row limit. Server-side geographic queries and pagination are needed before larger-scale expansion.

## Legal and ownership

**© 2026 Vojtěch Klepáček. All rights reserved.** No general open-source license has been chosen for the original project. Third-party dependencies keep their own licenses; see `LICENSE` and `Legal/COPYRIGHT.md`.

The documents in `Legal/` are bundled into the app and accessible before registration and from Settings. They are **development drafts**, not a declaration that the app is legally compliant or ready for the App Store. A public contact email has not yet been supplied and is not inferred from a private account profile.

Before public app launch:

- Add a working public privacy/support/copyright contact and verified controller details.
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

A GitHub Actions workflow in `.github/workflows/ios-build.yml` is prepared to build on macOS against an available iPhone simulator. After publication, inspect its result. Commit the first successfully resolved `Package.resolved` from Xcode to lock transitive dependencies; no lockfile is fabricated here.

Backend checks performed in rolled-back transactions: own request insertion/read, ownership-spoof rejection, rejection of client-supplied request status, cross-user request isolation, and anonymous denial. No temporary test accounts or requests are retained. Existing place data is preserved. The security advisor currently reports leaked-password protection disabled; review the setting before launch.

**Not verified here:** Swift compilation, package resolution, iOS rendering, keyboard behavior, pin positioning on device, email delivery, or signup/photo upload end to end. This environment has no Xcode or iOS Simulator.

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
