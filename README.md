# OpenWC

A native SwiftUI iPhone app for community-shared toilet access codes. Dark purple by default, with light and system appearance options.

## Run on iPhone or Simulator

1. On a Mac with **Xcode 26 or newer**, open `OpenWC.xcodeproj`.
2. Allow Xcode to resolve the Supabase Swift package.
3. Select the OpenWC scheme and an iPhone simulator, then Run.
4. For a physical iPhone, choose your Apple development team under Signing & Capabilities and change `app.openwc.ios` to your own unique bundle identifier.

Minimum deployment target: iOS 17. iOS 26 uses native Liquid Glass for the floating navigation capsule; older versions use system material blur. This source package is not a signed IPA or an App Store submission.

## Connected backend

A dedicated **OpenWC** Supabase project was created in **varone's organization**, region `eu-central-1`, reference `vpqezabichkjiwllczsg`. `Config.xcconfig` already contains its project URL and **public publishable key**. No privileged server key is included.

`Database/schema.sql` has already been applied to that project. Do not run it again there. It is included for review and for setting up another empty project. To switch projects, apply the schema once in the new project and update `Config.xcconfig`.

The database starts empty. Real businesses and access codes are added by signed-in contributors; the app does not fabricate live listings. Apple Maps searches actual businesses when adding a place. Demo mode is separate, uses fictional Prague listings and codes, and cannot publish.

## Accounts and sharing

- Register with an email and a password of at least eight characters.
- If email confirmation is enabled, confirm through the email before returning to log in. Email delivery depends on your Supabase email configuration; configure production SMTP before launch.
- The Supabase SDK handles session storage, restoration and refresh.
- Allow location access for automatic centering and distance ordering. The nearby view shows shared places within 5 km. Without location, the map can be explored manually and the list explains that distance sorting is unavailable.
- Tap the purple +, search by business name/address, select a result and confirm its pin, then add the code, access notes and an optional photo.
- Photos are resized to a maximum 1600-pixel edge and re-encoded as JPEG, up to 5 MB. Photo library selection uses Apple's system picker.
- Tap a map pin or list row for the code, copy action, photo, walking directions and a broken-code report.
- Profile shows the signed-in user's contributions. Settings controls appearance and links to iOS location settings.

## Data access

Authenticated users can read community places and insert places under their own user ID. Anonymous clients cannot read codes. Reports are visible only to their submitter; administrators can review them in Supabase. One report per user/place is allowed. Photo uploads/deletes are restricted to the user's own folder. Photos are public community assets, so they must not include private information. Coordinates are stored for businesses; users' live locations stay on device.

Database constraints validate lengths, coordinates and photo ownership. Row level security is enabled on both tables. Schema changes and policies should be reviewed before a public release.

## Verification and limits

Completed here:
- Provisioned the dedicated project and applied the schema.
- Checked the security advisor: no findings at verification time.
- Ran a rolled-back database transaction covering place insertion, ownership spoof rejection, invalid coordinate rejection, report insertion, report isolation and anonymous access denial.
- Validated project references, plist, scheme XML and asset JSON locally.

**Not verified here:** Xcode compilation, Swift package resolution, iOS rendering, device location, email delivery, signup/login and photo upload end to end. This environment has no Xcode, Apple SDK or iOS Simulator. Run the included manual checklist on a Mac before distributing.

Before an App Store release, add a published privacy policy, in-app account deletion, a moderation/review workflow, production email delivery, abuse controls, and App Store assets. Places are loaded in one request with Supabase's default result limit; use geographic server queries and pagination before expanding beyond an initial local community. Opening hours and step-free labels are contributor supplied, not independently verified.

The Figma URL could not be accessed from this environment. The interface follows the written brief rather than a verified copy of that file.

## Project files

- `OpenWC/Views.swift`: onboarding, authentication, map, nearby list, profile, settings, details and glass navigation.
- `OpenWC/AddPlaceView.swift`: Apple Maps business search, place selection, photo preparation and sharing form.
- `OpenWC/AppStore.swift`: Supabase auth, data, photos and reports.
- `OpenWC/Models.swift`: place model and location service.
- `Database/schema.sql`: database, storage and RLS policies.
- `make_project.py`: regenerates the included Xcode project using Python's standard library.

## Manual acceptance checklist

1. Run in dark/light modes and with large Dynamic Type; confirm text and controls remain usable on a small iPhone.
2. Register, confirm email, log in, force quit/relaunch and log out. Try an invalid password and a disconnected network.
3. Test location permission allowed/denied and a simulated location outside Prague. Check map centering and distance sorting.
4. Add a real permitted place, confirm its pin, add a photo and verify it from a second account after relaunch.
5. Confirm a user's place cannot be inserted under another user's ID; verify anonymous code reads are rejected.
6. Check photo removal before save, oversize photos, business search with no results and database/network failures.
7. Check code copy, walking directions and broken-code reporting. Confirm another user cannot read the report.
8. Inspect navigation glass on iOS 26 and the blur fallback on iOS 17/18.

## Architecture correction

Debug now explicitly sets `ONLY_ACTIVE_ARCH=YES`; Release keeps `NO`, following Apple’s recommended architecture settings. This addresses a possible app/package architecture mismatch during simulator builds. It has not been compiled or verified on a Mac.
