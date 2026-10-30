# NeighborHelp readiness review for November 3, 2026

Reviewed October 28, 2026 (Asia/Manila), against local commit `a3b72bf`. This is a source review and local-check result, not certification of the deployed Firebase project. No application source or live data was changed. Training a new certificate model is outside this validation scope.

## Assessment

There is a substantial implemented foundation, but I would not treat the system as ready for validator sign-off yet. The highest priorities are access rules, the unfinished move from Verification Agency to admin review, usable credential evidence, and a complete rehearsal of the customer/provider/admin workflow. A readiness percentage would be misleading without your validator's rubric and deployed-system results.

## Checks performed

- `flutter test --no-pub --reporter expanded`: **71 passed, 1 failed**. Failure: `test/user_role_test.dart:21` expects a Customer with a provider profile to become a Provider. `UserRole.resolve` deliberately preserves an explicit Customer role. Reconcile the test with the intended account policy rather than changing roles simply to satisfy a stale expectation.
- `flutter analyze --no-pub`: **13 issues: 2 warnings and 11 informational notices; no analyzer errors**. The command exits nonzero. Warnings are unused imports in `admin_user_reports_page.dart`; other findings are deprecated form-field parameters and style notices.
- `node --check functions/index.js`: passed JavaScript syntax checking. This does not validate deployed functions or authorization behavior.
- `flutter build web --release --no-pub`: **passed**, generating `build/web` (143.2 seconds). This proves compilation, not live API correctness or successful deployment. Android was not built.
- Not exercised: live sign-in, Didit sessions/webhooks, real Storage uploads, Firestore Emulator tests, deployed Functions/indexes, FCM/email delivery, Android release build, or the existing sentiment API's Python tests. A usable Python executable was not found through the checked launchers/installation path. No dependencies were installed.

## Finish before validation

### 1. Critical: prevent users assigning themselves privileges or undoing moderation

**Evidence:** `firebase/firestore.rules:97-114` only protects selected verification fields during self-update. It does not protect `role` or `accountStatus`; user creation only checks ownership of the document ID. A user-created document can also supply verification fields. This is a rule-level gap found in source; deployed rules were not inspected or attacked.

**Work:** limit self-registration to allowed customer/provider roles and unverified state; prevent clients changing role, moderation status or review metadata. Enforce blocked-account restrictions in rules and server functions, not only `root_gate.dart:284` UI routing. Review who can read private user data, because all signed-in users can currently read full `users` documents.

**Acceptance:** ordinary accounts cannot grant themselves Administrator, set verification to approved, reactivate themselves, or bypass a suspension using direct database requests. Legitimate profile edits still succeed.

### 2. Critical: enforce booking and certificate integrity in trusted code

**Evidence:** `firebase/firestore.rules:136-154` prevents adding approved certificate IDs but permits changes to certificate contents while an existing approved ID remains. Provider statistics such as ratings and completed bookings are not protected by that guard. `firebase/firestore.rules:217-222` lets a booking participant update the entire booking without an immutable-field or state-transition restriction. `providerServiceCreateValid` checks ownership and draft/pending state, not identity or required credentials.

**Work:** protect approval evidence, computed statistics, participant IDs, fees and completion fields; authorize each transition and its permitted editor. Check service existence/eligibility when creating a booking. Validate credentials and identity in trusted rules or server code rather than relying on publish-button checks. Invalidate approval when certificate evidence changes.

**Acceptance:** direct client writes cannot forge ratings/completion, reuse an approval for changed credentials, change booking participants, skip booking stages or book a non-public/ineligible listing.

### 3. High: complete the agency-to-admin change

**Evidence:** `lib/models/user_role.dart:5` and `lib/screens/root/root_gate.dart:295` retain the agency role and route. `lib/screens/admin/pages/admin_certificates_page.dart:14,126` explicitly makes certificate review read-only. Approval is implemented in `lib/screens/verification_agency/agency_certificates_page.dart` and `lib/services/firestore_service.dart:1594`. The identity-review admin page already has approve/reject actions, so this is a partial migration, not an entirely missing admin area.

**Work:** give the admin the certificate queue and approve/reject/request-correction flow; update provider instructions, audit attribution, permissions and role routing. Plan what happens to existing agency accounts without silently promoting them to administrators. Existing historical reviewer records can remain as audit history.

**Acceptance:** an authenticated Firebase admin can review a provider credential; the provider sees the result and reason; the proposed validation flow requires no agency login.

### 4. High: provide actual credential evidence for manual review

**Evidence:** `lib/screens/provider/provider_certification_dialog.dart:306` has an optional certificate URL. There is no certificate file picker/upload path in the dialog; `lib/services/storage_service.dart` supports profile, service and portfolio images only. The admin/agency certificate cards display a URL as text. `firebase.json` includes Firestore rules but does not configure deployment of the existing Storage rules file.

**Work:** add image/PDF evidence upload and an admin preview/open action, file limits and appropriate private access. Wire Storage rules into deployment and confirm the actual deployed rules. If the team deliberately chooses a link-only MVP instead, require an accessible evidence link and provide an open action; do not describe that as file upload.

**Acceptance:** submit evidence, reopen it after signing out/in, view it as admin, reject it with a reason, replace it and confirm approval resets. Unrelated accounts cannot access private evidence.

### 5. High: correct or remove filters that do not affect results

**Evidence:** `lib/screens/customer/tabs/customer_browse_tab.dart:81-143` implements search/category and sorting. The location, price, minimum-rating and availability controls update state at lines 216-226, but their selected values are not applied by `_filterAndSort`. “Most booked” sorts by review count, which is not booking count. “Recommended” on Browse sorts by rating/review count, while Nearby uses the weighted recommendation score.

**Work:** make each exposed filter affect results, reset pagination on filter changes, and align labels with actual sorting. Confirm whether Browse's Recommended must use the manuscript's weighted score.

**Acceptance:** use seeded providers with deliberately different prices, ratings, locations and schedules; changing each filter produces the expected membership/order, including no-match cases.

### 6. High: separate sample listings from the validator's live marketplace

**Evidence:** `lib/screens/customer/customer_demo_catalog.dart:247` unconditionally appends demo and featured listings to live results. `customer_home_tab.dart:892` and `customer_browse_tab.dart:147` show a preview message instead of opening a booking for those items. `customer_demo_catalog.dart:240` defaults the verified badge to true when a provider profile is missing.

**Work:** use actual seeded Firebase services for validation; remove preview rows from live mode or visibly identify them before interaction. Treat missing verification evidence as unverified. Filter suspended providers from discovery and booking eligibility; `rankProvidersByRecommendation` only receives provider profiles and checks verification, not the user moderation status.

**Acceptance:** every ordinary service card in the validation flow opens a real service that can receive a booking. Unverified/missing-profile/suspended providers do not receive a misleading verified badge or an eligible listing.

### 7. High: check rules helpers used by chat, reports and reviews

**Evidence:** `firebase/firestore.rules:65,72,84,229` use `b.exists` after `get(...)`. Firestore's documented Rules `Resource` has `data`, `id` and `__name__`, rather than an `exists` property. Existence is checked with the `exists(path)` function. This is a source/docs finding; its effect has not been reproduced in an emulator. It risks denying the operations that use these helpers. The review callable can mask a broken direct-write path because it uses the Admin SDK.

**Work:** use the documented existence checks and run emulator allow/deny cases for chat, user reports and milestone reviews. Restrict message receiver/booking consistency and read-status-only updates.

**Acceptance:** booking participants can send/read messages, report the other party and review a completed milestone; outsiders are denied. Incomplete milestones cannot be reviewed. Missing bookings fail safely.

Reference: https://firebase.google.com/docs/reference/rules/rules.firestore.Resource and https://firebase.google.com/docs/rules/rules-language

### 8. High: make multi-write booking actions safe to retry

**Evidence:** `lib/services/firestore_service.dart:540-570` accepts a booking, assigns a contract milestone and increments accepted bookings using separate steps. Completion at lines 769-791 writes completion before incrementing the provider count. Acceptance lacks a pending-status check in that method. Concurrent/retried actions can produce duplicate counts or partial state. `functions/index.js:976-996` checks existing reviews then adds a random-ID review without an atomic uniqueness guard.

**Work:** make acceptance/completion transactional or server-owned and idempotent; enforce valid starting states. Use a deterministic per-booking/per-reviewer review ID with an atomic create/transaction, including direct-write authorization.

**Acceptance:** double-tap, concurrent requests and retry after connection loss create one accepted/completed transition, one milestone/count increment and one review per party.

### 9. High: prove the deployed identity and sentiment integrations

**Evidence:** `admin_verification_page.dart:145,184` and `firestore_service.dart:1551,1578` require a successful Didit check before admin identity review. Deferring the new certificate model does not remove this existing dependency. `functions/index.js:548-607` falls back to keyword sentiment if the API URL is absent or fails; `lib/utils/review_sentiment.dart:110` also displays fallback sentiment.

**Work:** perform a real Didit session and webhook/status-refresh/admin-approval walkthrough using authorized test accounts. If LSTM sentiment is in the validator rubric, verify an actual stored review has `sentiment.source = lstm`; a colored sentiment badge alone is not evidence the model ran. Confirm project, region, callback, enabled APIs, keys, quotas and deployed indexes without exposing secrets. Check maps/location permission and no-GPS behavior on the validation device.

**Acceptance:** demonstrate the expected integration on the deployed build and distinguish pending/failure/fallback states. Have prepared, legitimate test records to avoid waiting for external processing during the session; do not fake successful integration results.

### 10. Medium: eliminate misleading unfinished actions

**Evidence:** notifications schedule/email/push are explicitly not wired in `admin_notifications_page.dart:77,131`; draft saving only displays a snackbar at line 235. Many admin exports are placeholders. Apple registration is a placeholder at `register_details_screen.dart:751`. Portfolio video/text/link/document/audio options are placeholders at `provider_portfolio_flow.dart:463-467`. Saved browse services are an in-memory set (`customer_browse_tab.dart:51,314-323`).

**Work:** finish features required by the rubric. For optional features, remove them from the promised MVP or clearly disable/label them before validation. Do not spend the last days completing every export, media type or sign-in provider unless required. Persist bookmarks if they are part of the required feature list.

**Acceptance:** every enabled control in the validation script performs its stated action and survives a refresh when persistence is expected. In-app notifications may be sufficient only if the agreed scope permits it.

### 11. High: use a real administrator login during validation

**Evidence:** `lib/services/auth_service.dart:68-102` attempts Firebase admin sign-in and silently falls back to a local UI-only admin session when it fails. Admin data/actions require Firebase and several pages reject local-only mode. Credentials are fixed in the local-login check.

**Work:** ensure a real Firebase admin account and correct role document; make failed admin authentication clear. Disable or explicitly isolate preview-only admin access in the validation/release build. Use controlled validation credentials rather than relying on the fixed demo login.

**Acceptance:** admin login accesses live queues, approvals survive reload, bad credentials fail clearly, and loss of Firebase access cannot look like a successful operational admin login.

### 12. High: complete release and end-to-end evidence

**Evidence:** the existing Flutter suite covers scoring, geometry, navigation and selected utility/policy behavior. The app smoke test only renders a generic `MaterialApp` (`test/widget_test.dart:7`). No `integration_test` suite, Firestore rule tests or backend test command was found in the reviewed project. Passing UI shell tests does not establish booking or Firebase integration correctness.

**Work:** reconcile the failing role test, clean analyzer warnings, build the exact target platform, deploy/check the intended rules/functions/indexes, and rehearse on two independent customer/provider sessions plus admin. Confirm the validator's platform and written rubric. Capture dated screenshots or a recording and expected/actual outcomes.

**Acceptance:** the following scenarios pass on the exact deployed/release build; the team has the URL/APK, seeded accounts, short demo script and known-limitations list.

## Validation rehearsal checklist

- Customer and provider registration, password login, logout and reset; Google sign-in if in scope. Accounts return to the right workspace after relaunch.
- Provider profile and photo save, real location and availability persist, and permission denial produces a usable fallback.
- Identity submission completes and admin reviews it; credential evidence can be submitted/viewed/rejected/corrected/approved.
- Provider creates a draft, submits a listing, admin approves/rejects it, and only eligible approved listings appear in discovery.
- Customer search and every enabled filter/sort work against real seeded data, including no results.
- Customer submits a future-dated booking; provider accepts/declines; both see matching status and fees.
- Chat is visible only to its participants. No message is sent to an unrelated user.
- Provider starts and completes work; demonstrate the actual time-window rule with appropriately prepared test data. Counts update once.
- Cancellation/rejection reasons appear on both sides; retry and double-tap cannot corrupt state.
- Both parties leave one review after completion, duplicates are blocked, ratings update and required sentiment behavior is demonstrated.
- User report reaches admin; suspension/reactivation works and suspended accounts cannot transact or reappear as bookable providers.
- In-app notifications arrive; unread state persists. Demonstrate external delivery only if implemented and in scope.
- Refresh/relogin, slow/offline connection, image upload failure and missing location produce clear recovery states.
- Run the same script on the validator's browser/mobile device; check small-screen dialogs and no overflow.

## Proposed schedule (Asia/Manila)

- **October 28:** confirm rubric and freeze scope; address privilege/moderation rules and rules-helper defects first. Reconcile the failing role test.
- **October 29:** finish admin-owned manual verification, credential evidence and real admin authentication.
- **October 30:** fix marketplace filters, verified status/demo separation and booking state/transaction integrity.
- **October 31:** verify deployed Didit, functions/indexes, maps, notifications and required existing sentiment integration. Resolve recommendation-formula consistency if evaluated.
- **November 1:** run the entire three-role validation script on the target platform; fix demonstrated failures and add focused regression/rule tests.
- **November 2:** freeze the build; prepare final URL/APK, accounts, seeded scenarios, screenshots/recording and known limitations. Rehearse with someone outside the development team.
- **November 3:** validate the frozen build. Avoid new model work or last-minute feature expansion.

This is a suggested work order, not an estimate that every item can be completed within one day. If capacity is tight, agree explicitly with the validator which optional controls are out of scope; retain the access-control and core booking requirements.

## Recommendation consistency to confirm with your manuscript

The weighted score is implemented as `0.40P + 0.30R + 0.20A + 0.10C` and has passing unit tests. However, `functions/index.js:1051` stores a Bayesian-adjusted `averageRating`, while `lib/utils/weighted_scoring.dart:53` applies Bayesian adjustment again. This is explicitly described in a code comment and may be intentional; confirm it matches the documented method. For example, using a 3.5 prior, weight 10, two 5-star reviews gives 3.75 after one adjustment and about 3.542 after the second. The function also derives a dynamic prior from provider averages, whereas the Dart default is fixed at 3.5. Use one agreed definition and show a reproducible calculation rather than changing the algorithm during validation.
