# Reliability and language improvements

Implemented locally on 2026-11-09. No production deployment, cloud account changes, SMS enrollment, diagnostic-upload consent or academic-paper edits were performed. The new GitHub workflow runs after these changes are pushed; local checks are not a hosted CI run.

## Administrator accounts

The shared demonstration credential and unauthenticated admin route are removed. Administrators use individually assigned Firebase accounts with the active Administrator role. On 2026-11-10, the email-verification prerequisite was removed from the console, admin commands and Firestore/Storage rules at the user's request. Phone MFA enrollment/challenge is implemented, with a console-managed `securityPolicy/admin.requireMfa` policy covering the same layers. See [account setup and migration](../firebase/ADMIN_SETUP.md). Configure Identity Platform and test enrollment/recovery before enabling that policy. Existing cloud passwords were not rotated automatically.

## Assets and application size

The previous service-photo catalog bundled 154 original files totaling 548,658,277 bytes. Bundled service thumbnails now total 1,004,130 bytes: about 99.8% fewer service-image bytes. WebP thumbnails use quality 80, maximum dimensions of 1200 × 1200 and stripped EXIF metadata. Originals remain unchanged in the repository; unsupported-category photos are excluded from the asset manifest.

The [optimization record](service-image-optimization.json) contains each source hash, dimensions and output size. Regenerate with Pillow 12.0.0 and `python scripts/optimize-service-images.py`; update `scripts/service-image-sources.json` when supported services change. These figures compare service-image assets, not debug and release APKs. Release-size analysis is part of local verification. The existing release signing setup uses a development key, so store distribution still requires appropriate release signing.

## Unresolved work

Admin navigation → Trust & safety → Unresolved work shows open/reviewing cases and resolved history. Participants see their own cases and review events in the contract panel. They can report a no-show for an unstarted accepted job one hour after its start, overdue completion after the stated 72-hour response period, or overdue corrections after 72 hours. The server validates eligibility and account limits. Reports remain allegations to investigate.

The 30-minute scheduler scans up to 200 bookings with a persisted cursor and wraps to the beginning, preventing old jobs from permanently excluding later records. It opens follow-ups and reminds participants at most once per day per open case. A missing start record is labeled Start unconfirmed, not proof of a no-show. Large deployments need a shorter cadence or indexed task queue before making timeliness guarantees.

Administrators record notes and an outcome. They can review, resolve or cancel active work after review; cancellation preserves agreements, payments and pending-amendment history. They cannot confirm completion for the customer, acknowledge money for either party or impose automatic financial penalties. Deploy the new workCases indexes with the functions and rules. Closed cases do not reopen automatically; new completion/correction cycles get distinct cases.

## Settlements and refunds

After accepted work is cancelled or completed, either participant can propose a final settlement recording completed work, supplied/returned materials, outstanding concerns and a final labour fee between zero and the accepted labour fee. The server calculates balance/refund due from acknowledged payments less acknowledged refunds. Additional new charges cannot be inserted through this mechanism; extra work/costs need an appropriate agreement before work.

The proposer previews and voluntarily accepts the exact record; only the other participant can accept it. Declining or withdrawing preserves existing terms. Original contract prices remain unchanged and all proposal outcomes remain on record. Pending receipts must be resolved before proposing a settlement, and a pending settlement freezes new payment/refund reports. Changed financial records invalidate a proposal's snapshot and require a new proposal.

Providers report refunds actually sent; customers acknowledge actual receipt or dispute it. Providers can withdraw unacknowledged reports. Concurrent refunds cannot exceed the remaining refund due, and receipt confirmation cannot credit twice. Gross payments, acknowledged refunds, net receipts, pending receipts and remaining balances stay distinct. Records do not transfer funds, verify a bank transaction, provide escrow or waive statutory rights. Qualified legal review remains necessary before live use.

## Languages

The interface uses English throughout. Language menus, saved language selection and the multilingual interface dictionaries have been removed from sign-in, contract offers, settlements and account preferences. A previous device language preference cannot change the interface. Shared English workflow labels and important notices remain in the copy lookup.

Accepted contract, amendment and settlement text remains the exact original document both parties accepted, with its hash and acceptance records. Removing interface language selection does not rewrite these records. Users are still asked to read the complete agreement before accepting. This interface change does not alter user-written reviews or the sentiment model's language capabilities. Use the [pilot protocol](pilot/README.md) for comprehension testing.

## Diagnostics and automated checks

Android Crashlytics is integrated with framework and uncaught asynchronous error handlers. Native collection defaults to false. Build with `--dart-define=CRASH_REPORTING_ENABLED=true` only after reviewing the Firebase setup. Users must separately opt in under device account preferences; the flag does not grant consent. Web/emulator builds skip this native reporter. Opting out disables collection and deletes unsent reports. Local mapping uploads stay disabled unless an operator explicitly sets the Gradle `uploadCrashlyticsMapping` property.

App-recorded errors contain the exception type and stack, not raw exception text, chat contents, addresses, certificate images or payment references. The SDK may include installation/device metadata after consent; this is not an anonymity guarantee. Native crash reports, existing server logs and sent reports need their own access/retention review. No real-device crash was sent here. Verify consent behavior and delivery on a test device using [Firebase's Flutter setup](https://firebase.google.com/docs/crashlytics/flutter/get-started). iOS requires separate platform/symbol configuration and has not been built or verified here.

`.github/workflows/quality.yml` runs on pushes, pull requests and manual invocation. It runs Flutter analysis/tests and an emulator-configured web build, Node unit and complete Firestore/Storage tests, Python sentiment/training-tool tests, and an actual local recovery drill. Jobs have timeouts, read-only repository permissions and cancellation of superseded branch runs. The workflow does not deploy or use cloud credentials.

## Recovery verification

An actual local Firestore export/import restored 12 synthetic documents, including agreements/history, payments/refunds, a settlement, private conversation and audit records. Content hash, financial balance and agreement preservation were verified after restart/import. See [drill evidence](local-recovery-drill-result.json). Repeat it with `scripts/run-local-recovery-drill.ps1` after installing Node dependencies and Java. It is restricted to the `demo-neighborhelp-recovery` emulator and creates a new ignored artifact directory.

A read-only inspection of the configured project's cloud backup listing returned no available backups on 2026-11-09. Consequently no cloud backup could be restored. The local drill does not prove production recovery or restore Auth users/Storage blobs. Configure an appropriate schedule, wait for a successful backup and use `scripts/manage-backups.ps1` to restore into a new isolated recovery database. Verify records and plan Auth/Storage recovery separately. Cloud schedules/restores can incur charges and were not created here. Follow the official [Firestore backup/restore documentation](https://firebase.google.com/docs/firestore/backups).

Human pilot sessions, native review, cloud recovery, real-device MFA/diagnostics verification and deployment remain operational steps. Do not commit snapshots or diagnostic records containing real personal data.

Local verification: 141 Flutter tests, 72 Firebase emulator tests, 12 server unit tests and 21 Python tests passed; analysis was clean. Final consent/language regressions passed after the last translation additions. Android ARM64 release and web release builds succeeded. The measured APK is 27,078,607 bytes. See the [verification record](reliability-verification.json) for logs, source hashes and explicit operational limits.
