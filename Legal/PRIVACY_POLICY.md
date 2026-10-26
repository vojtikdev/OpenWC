# OpenWC Privacy Policy

**Development draft · Version 2026-10-26.** The operator/controller is **Vojtěch Klepáček**. A public privacy email/address has not yet been supplied. This is a release blocker. During testing, signed-in users can submit private access, correction, deletion or other requests in Settings → Privacy & account requests. The operator must monitor those requests and complete this notice before public launch.

## Data used by OpenWC

**Accounts:** Supabase Authentication processes your email address, password credentials and account identifiers to register and authenticate you. The app does not display your email to other members. Session credentials are stored by the Supabase SDK on your device so you can stay signed in. Registration sends the terms version and acceptance timestamp as account metadata. This acknowledgement is not used to grant database permissions.

**Contributions:** the database stores a place’s name, address, coordinates, access code, notes, step-free flag, optional photo path, creation time and contributor account ID. Signed-in users can read place records, including contributor IDs, but not account email records. Photos use a public storage bucket: anyone with a photo URL can view it. Do not upload private information or identifiable people without an appropriate lawful basis.

**Requests and reports:** the app stores your account ID, the place ID and reason when you report a broken code. It stores the type, text, status and timestamps of privacy/account requests. These records are readable by their submitter and authorized backend administrators, not other ordinary members. Do not enter passwords, identity documents or sensitive information in these messages.

**Location and maps:** optional device location is used to center the map and compute distances on device. OpenWC does not save your live device location in its database. Apple Maps handles map rendering, business searches and directions; it may receive map viewport, search text, search region and other data under Apple’s terms and privacy practices. Searching around your position can reveal an approximate area to Apple. Manually selecting a map pin does not require enabling location access. Business coordinates you submit are stored and shared as part of the listing.

**Operational information:** Supabase and Apple may process IP addresses, timestamps and security/service logs when their services are used. The current app has no advertising or third-party analytics integration added by the OpenWC source. No claim is made that service providers process no diagnostic information.

## Purposes and legal bases

Account, session and requested sharing functions are intended to operate on the basis of providing the service you request. Security, abuse handling and maintaining service integrity may rely on legitimate interests, subject to applicable balancing and objection rights. Optional location processing follows your device permission choice; you can withdraw that permission in iOS Settings. Legal obligations may require limited retention or disclosures. The operator must confirm these bases and any jurisdiction-specific requirements before launch. Agreement to terms is not blanket consent to unrelated data processing.

## Providers, recipients and transfers

Supabase provides authentication, Postgres database and photo storage. The configured OpenWC project is in the EU Frankfurt region (`eu-central-1`); that project setting alone does not establish where every provider, support operation, subprocessor or backup processes data. Apple supplies map, search and direction services. User-contributed photos are public; place records are accessible to authenticated members. Authorized administrators can access backend records to operate the service and handle requests. The operator must review provider agreements, subprocessors, international transfers and any required safeguards before public launch.

Provider information: [Supabase Privacy Policy](https://supabase.com/privacy), [Supabase DPA](https://supabase.com/legal/dpa), and [Apple Privacy](https://www.apple.com/legal/privacy/).

## Retention and deletion

Account records and contributions currently remain until the operator removes them or processes a deletion request. Reports and account/privacy requests remain until reviewed and removed under the operator’s retention schedule. That schedule, operational log periods and backup expiry periods have not yet been finalized and must be documented before launch; this draft does not promise a deletion period the system cannot enforce.

Submit a deletion request from the app to initiate removal of the entire account and associated contributions/photos, subject to any lawful retention duties. Requests are processed manually, not automatically. The operator must revoke sessions, remove stored photos and delete associated account records, then communicate completion. Database cascades do not by themselves remove storage objects. Previously issued tokens and public/cached photo copies require separate consideration. Provider backups may remain until their documented expiry. Copies retained independently by other users are outside the operator’s direct control.

## Your choices and rights

You can use the fictional demo without an account, decline location access, and share a place without a photo. You may request access, correction, deletion, restriction, portability or object to processing where applicable. You may withdraw consent for consent-based processing without affecting prior lawful processing, and complain to your competent data protection authority. Where GDPR applies, requests must be handled within its applicable time limits, ordinarily one month with extensions only where legally permitted and explained. The in-app request log records submission and processing status; it is not a substitute for the operator fulfilling those duties.

## Security and children

Database row-level policies restrict writes and private requests to the authenticated user; no server administrative key is included in the app. No system can guarantee absolute security. The service is not designed specifically for children. Age-related terms, any required consent measures and safeguards must be decided before offering the app to children; this draft does not assert those measures are implemented.

## Changes and contact

The version above identifies this notice. Material changes should be communicated as required. A working public contact channel, verified controller details, retention schedule, request monitoring and legal review are required before the development draft can become a final public notice.
