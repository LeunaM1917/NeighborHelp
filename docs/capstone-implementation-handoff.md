# NeighborHelp capstone alignment

Work branch: `codex/capstone-nine-gaps`.
Starting commit: `49c33b64a904f3e4851d48fddcc2c75320865bde` on `ui/shared-web-sidebar`.

These changes implement the nine gaps identified against the supplied capstone document. The initial implementation was committed by the project owner as `fe43fef`. Follow-up repairs are on the same branch; no commits were created by the agent. On November 3, 2026, all 24 backend functions and the matching Firestore/Storage rules and Firestore indexes were deployed to `neighborhelp-63771`; all 12 indexes were verified READY. The updated web client was built locally; Firebase Hosting was not updated. The project owner will deploy hosting after local acceptance testing. No production records were manually migrated, approved or deleted.

## Customer loading and messaging repair

The client had been released locally before its new backend endpoints were deployed. `getPublicProviders`, `getPublicDirectory` and `bookingCommand` returned 404. These endpoints, session/device registration and geocoding now respond with the callable protocol and reject unauthenticated requests. The existing Didit, Maps and sentiment settings on previously deployed functions were verified as preserved.

The supplied August rules were compared with the current rules. Booking, contract and message reads again use explicit participant comparisons that Firestore can prove for list queries. Chat queries also constrain sender/receiver inside a single composite AND/OR filter, including legacy booking-based messages. Current protections for private profiles, privileged roles, account restrictions, immutable message content, server-owned booking/review writes and certificate approval remain in place. Query-level emulator tests cover both participants and denied access by strangers/suspended users.

Session streams now keep a stable identity, replay saved data on the first frame of a reopened page and can retry without recreating mounted pages. Account-scoped future reads are coalesced and briefly cached; failures are evicted. Directory bootstrap failures no longer prevent already available public projections from rendering. Home, Browse, provider discovery, bookings, requests and chat show recoverable errors rather than presenting failed loads as empty data. Customer booking/request detail hydration reuses one future per booking set and no longer calls `setState` from a build-time load. Session caches are cleared at sign-out.

Chat opens from its booking even if optional profile/service details fail. Help and notification popup scrollbars now own the same controller as their lists, fixing the reported `scrollbar.dart:1466` assertion.

A read-only compatibility check found two active legacy service records without `approvalStatus`. The client now presents missing or invalid approval values as Pending, matching the backend's explicit approval requirement. These records need administrator review; they were not automatically approved. One other approved technical listing lacks a matching approved certificate, so it remains excluded until its evidence is reviewed. Two active service listings currently satisfy the backend eligibility checks.

Follow-up verification: 97 Flutter tests, 27 Firestore/Storage emulator tests and 5 backend domain tests passed; Dart analysis was clean. Web release and Android debug builds succeeded. Anonymous live probes verified the six new callable endpoints respond with `UNAUTHENTICATED` rather than 404. No messages were sent to production users and no signed-in browser walkthrough was performed.

## Implemented behavior

1. Browse filters apply category, location, price, rating and working-day availability. Recommended results use the shared 40/30/20/10 provider score. The selectable search radius and provider coverage limits apply to each sorting mode. Authenticated discovery uses eligible live providers and approved services; map pins no longer invent coordinates for providers without GPS.
2. Administrator exports generate CSV or JSON, with timestamps in UTC, safe CSV cells, and an audit event. Reports export the selected period's booking records. Collection export dialogs explicitly identify exports of all records.
3. Booking reports recognize both historical `Completed` records and `Milestone Complete`. Date filters use booking request creation dates. Rating history uses actual dated customer reviews, without fabricating points for missing days. Feedback reports distinguish LSTM classifications, keyword fallbacks and unanalyzed comments. Geographic demand reports group actual booking coordinates into approximately 1 km cells. Current provider rating/verification metrics are identified separately from period activity.
4. Booking responses, cancellations, schedule proposals/responses, verification and service/certificate reviews produce notifications. Completion requests feedback from both parties. Reminder jobs run every 15 minutes for accepted appointments starting within the next hour. Device tokens are bound to the currently signed-in account, moved safely when accounts switch, and removed at sign-out; push delivery cleans up expired tokens. Scheduled administrator announcements use the same scheduler. Email delivery is outside scope.
5. Server-owned audit events preserve actor, role, timestamp, action and record reference. The Activity page reads these events. There is no fabricated historical audit backfill: events begin when the backend is deployed.
6. Booking creation and status transitions run through server commands. Per-provider transactional locks prevent concurrent overlapping accepts and reschedule approvals. Customer schedule proposals preserve the original appointment until the provider approves. Bookings require coordinates confirmed for the entered service address. Text messaging remains available; image attachments upload and display on web and native layouts.
7. Certificate review is available in the administrator console. Credentials must match the technical service and be unexpired; carpentry is included. Providers can upload PDF/JPG/PNG evidence up to 5 MB. Uploaded evidence is private and immutable. Editing the submitted certificate set requires renewed review.
8. Rules protect roles, account restrictions, identity fields, rating/counter fields, bookings and audit history. Private user records and verification metadata are separated from public display projections. Server review submission prevents duplicate feedback, rejects strong LSTM/rating contradictions, and respects account restrictions. Rating aggregation is repeatable on trigger retries, and ranking does not smooth an already Bayesian rating twice.
9. Idle sessions sign out administrators after 15 minutes and members after one hour. Browser caching supports previously loaded data; commands still require a connection and do not silently bypass validation. Administrator retention tools archive or restore closed/read records older than 180 days, with a reason and audit event. Archiving is reversible and does not erase personal information. Backup status is shown as unverified rather than hardcoded healthy. Backup inspection, daily scheduling and restoration-drill tooling is provided.

## Profile photo upload/download repair

The reported existing profile JPEG was present, valid and returned HTTP 200, but its cross-origin GET response omitted `Access-Control-Allow-Origin`. The bucket had no CORS configuration. The read-only policy in `firebase/storage.cors.json` was applied to the existing bucket, and live image requests from two localhost ports and the Firebase Hosting origin were verified to return HTTP 200 with the CORS header. Uploads still use Firebase authentication and the existing owner/account/size rules. Future environments can apply the file using `gcloud storage buckets update gs://BUCKET --cors-file=firebase/storage.cors.json`; Firebase Hosting deployment does not apply bucket CORS.

The Storage service agent was also missing `roles/firebaserules.firestoreServiceAgent`, which is required for the deployed Storage rules' Firestore account/booking checks. That role was added only to the project's existing Firebase Storage service agent; the rest of the project IAM policy was preserved. No Storage rule was loosened. See [Firebase cross-service rule permissions](https://firebase.google.com/docs/rules/manage-deploy#manage_permissions_for_cross-service_cloud_storage_security_rules) and [browser download CORS requirements](https://firebase.google.com/docs/storage/web/download-files#cors_configuration).

Customer and provider profile photo uploads now validate JPG/PNG/WebP data and the 5 MB limit before upload, use the detected MIME type and a new filename for each photo, and distinguish upload failures from failures saving the profile. Shared profile/settings avatars retain initials on image failures instead of reporting uncaught image errors. The suite passed 103 Flutter tests and 28 backend emulator tests, including profile image ownership, MIME and size restrictions. No replacement photo was uploaded to production during verification; the project owner should retry their selected image after restarting the local app. Hosting remains unchanged.

## Verification workflow

The current product has Customer, Provider and Administrator workflows. Didit approval updates identity verification automatically. The administrator handles exceptional cases, certificate review and service listing approval. A manual identity rejection is preserved when Didit status is refreshed; starting a new identity session clears that prior session's decision. Delayed callbacks from superseded sessions are ignored.

Existing `Verification Agency` role values and review attribution are retained as historical data. They do not grant review access in the current rules, and the legacy account screen explains that verification has moved to the administrator. No agency account is silently promoted to administrator. An account-role migration, if wanted, should be reviewed separately.

Existing contracts and transaction records are retained. The booking backend reuses an existing active contract for the same customer/provider before creating one. Stray provider profiles are no longer automatically deleted or used to change a customer's role.

## Local checks

Verified on November 3, 2026:

- `dart analyze lib test`: no issues.
- Flutter suite: 84 tests passed, including compact and desktop booking layouts.
- Backend under Node 22: 5 domain tests and 25 Firestore/Storage emulator tests passed.
- Bundled LSTM API: 3 smoke tests passed using the real model weights in an isolated Python environment.
- Web release build and Android debug APK build succeeded. No physical-device installation or manual browser walkthrough was performed.
- Production Node dependency audit: zero reported vulnerabilities. `git diff --check` passed.
- Backup inspection, schedule and restore commands were checked in plan-only mode; no cloud backup operation was executed.

Local build outputs are `build/web` and `build/app/outputs/flutter-apk/app-debug.apk`. Ignored check logs are in `artifacts/capstone-*.log` and `functions/emulator-node22-test.log`.

Use Node 22 for backend development and Java 21 for the Firebase emulators. The emulators use a `demo-` project and separate ports; tests reject an absent emulator environment.

```powershell
flutter analyze
flutter test
flutter build web
flutter build apk --debug

Set-Location functions
npm.cmd ci
npm.cmd test
npm.cmd run test:emulator
```

The backend tests use the real local Firestore/Storage emulators. Push delivery and sentiment HTTP responses are controlled test fixtures; those tests do not claim live FCM delivery or live Didit verification.

To use the application against local emulators:

```powershell
# From functions, start the demo services in one terminal.
.\node_modules\.bin\firebase.cmd emulators:start --config ../firebase.test.json --project demo-neighborhelp --only auth,firestore,storage,functions

# From the project root, in another terminal.
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

Use `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2` for an Android emulator. Emulator mode uses an explicitly fake Firebase configuration and skips device push registration. It does not need production credentials. The UI can still require Google Maps configuration when displaying a map; geocoding and Didit are external services, not emulated implementations.

## Deployment and live checks remaining

The backend and rules were deployed during the customer loading/messaging repair described above. Future releases must remain coordinated: the client no longer writes booking mutations or reviews directly, and private records use public projections for display. Deploy callable endpoints and triggers before releasing an updated client and stricter rules; do not deploy stricter rules by themselves to an old client. Test future changes in a staging project first. Firebase Hosting was not redeployed during this repair.

- Confirm the existing Didit workflow/key/webhook settings and test approval, rejection, resubmission and a superseded webhook.
- Confirm the Maps server key has geocoding access, and that web/native maps render and the chosen pin is the actual service address.
- Set `SENTIMENT_API_URL` to the deployed LSTM API and verify real saved reviews have `sentiment.source = lstm`. A fallback is explicitly labeled; it is not presented as a model result.
- For web push, build with `--dart-define=FCM_WEB_VAPID_KEY=<public-web-push-key>`. The provided service worker uses Firebase Hosting's `/__/firebase/init.js` configuration endpoint. Other hosting requires an equivalent public configuration bootstrap. Do not embed private credentials in the worker. Enable notifications through the explicit account/settings button, then test a background notification on a real device/browser.
- Deploy Firestore indexes, including the scheduled announcement index. Verify the 15-minute scheduler is enabled and that reminders/announcements actually run.
- Test CSV/JSON save dialogs on Android and the supported browser. Test profile editing, provider availability, certificate uploads, messaging, bookings and administrator review with separate accounts.
- Confirm a real backup exists and complete a restore drill. Database backups do not back up Firebase Authentication accounts or Storage media; review those services' recovery procedures separately.

## Backup and retention operations

`scripts/manage-backups.ps1` prints its commands by default. `-Apply` is required to execute them with the installed, authenticated Google Cloud CLI. Restore destinations are restricted to named recovery databases; the script cannot target `(default)` for a restore.

```powershell
# Review plans without changing the cloud.
.\scripts\manage-backups.ps1 -ProjectId neighborhelp-63771 -Action Inspect
.\scripts\manage-backups.ps1 -ProjectId neighborhelp-63771 -Action ScheduleDaily

# Read backup configuration from the selected project.
.\scripts\manage-backups.ps1 -ProjectId neighborhelp-63771 -Action Inspect -Apply

# After confirming permissions, billing and existing schedules, explicitly apply
# the schedule or restore drill. Supply the full backup name from Inspect.
.\scripts\manage-backups.ps1 -ProjectId neighborhelp-63771 -Action RestoreDrill -BackupName projects/neighborhelp-63771/locations/LOCATION/backups/BACKUP -DestinationDatabase neighborhelp-recovery-drill
```

Inspect the restored database's record counts and representative linked transactions, and check its IAM/security configuration before calling recovery verified. No existing database is deleted or overwritten by these commands.

The 180-day archive threshold is an application retention choice, not a claim of a legally required retention period. The project owner should approve a final retention/anonymization/deletion policy before public deployment. This implementation intentionally provides reversible archiving rather than automatic deletion of users, reviews, messages, identity evidence or audit history.

Reference documentation: [Firebase backup and recovery](https://firebase.google.com/docs/firestore/backups), [Google Cloud backup scheduling](https://docs.cloud.google.com/sdk/gcloud/reference/firestore/backups/schedules/create), [Google Cloud restore command](https://docs.cloud.google.com/sdk/gcloud/reference/firestore/databases/restore), [FCM Flutter reception](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
