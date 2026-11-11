# ID Analyzer identity verification

New customer and provider government-ID verifications use hosted DocuPass 3 in
Document + Face mode. The existing ID picker, browser launch, profile statuses,
notifications, and administrator controls retain their presentation and sequence.
Provider names in the related text now refer to ID Analyzer. TESDA certificate
review remains separate.

## Server configuration

Store `IDANALYZER_API_KEY`, `IDANALYZER_PROFILE_ID`,
`IDANALYZER_WEBHOOK_SECRET`, and optional `IDANALYZER_REGION=us` in the ignored
`functions/.env`. Do not put secrets in Flutter, git, logs, or screenshots.
The fine-grained key needs `docupass:create`, `docupass:read`, `profile:read`, and
`profile:list`. `transaction:read` supports investigation in the same integration.

Each server-created session overrides its webhook to the deployed
`idAnalyzerWebhook` endpoint with an opaque session binding. No manual webhook
change is required for these sessions. Manually created portal test links are
not attached to NeighborHelp accounts and must never grant a platform badge.
The profile's standalone webhook can stay empty.

The server fixes mode to Document + Face, binds the selected document category
and Philippines issuing country, disables file upload and phone verification,
and requests 24-hour link expiry. NeighborHelp independently rejects results
completed after its 24-hour deadline, even if the vendor omits hosted expiry.
It preserves the profile's other checks while
requiring fake-ID, face-mismatch, liveness-error, recaptured-face, expired-ID,
country, and document-type warnings to reject at weight 1. Review/reject trigger
weights are 1. The profile's remaining review policies still apply.

## Compatibility and decisions

The deployed endpoints `createDiditSession`, `createDiditSessionHttp`, and
`refreshDiditStatus` keep their names so existing Flutter installations work.
New creation routes to ID Analyzer. Refresh routes by the record's provider;
old Didit records remain available. Old Didit callbacks cannot overwrite an
ID Analyzer record.

The stored `diditSessionId` and `diditStatus` fields are compatibility aliases for
the hosted reference and normalized status. `verificationProvider=idanalyzer`
identifies the actual vendor. The final `verificationDecision` stores the raw
ID Analyzer accept/review/reject decision. Accept maps to Approved, review to
Pending, and reject to Rejected. A platform administrator's manual rejection is
preserved until the user deliberately starts another attempt. Existing verified
accounts are not reset or reverified automatically.

`identitySessions` contains private server-written bindings. Webhooks require an
HMAC-SHA256 signature over timestamp + dot + raw body, within five minutes. Only
conclusive/update events reconcile a session. The server reads the authoritative
DocuPass record, confirms the reference, owner binding, profile, non-reusable
Document + Face mode, completion and transaction ID, and writes the result only
if it is still the account's current session. Browser redirects and individual
scan events cannot approve anyone. Short leases serialize reconciliation;
duplicate deliveries do not rewrite the profile or generate repeated status
notifications. Inactive or changed-role accounts cannot gain approval.

Creation reuses an existing pending link for the same ID type and return URL.
It is limited to two new attempts per minute and five per account per UTC day.
Signed-out, suspended, wrong-role, or already verified accounts cannot create
new charged sessions. External return URLs are rejected; Firebase Hosting URLs
for this project and localhost development URLs are supported.

## Deployment and validation

The canonical web address is `https://neighborhelp.web.app`. Firebase Hosting
target `neighborhelp` publishes the application; target `legacy` redirects the
old project-number address to it while retaining paths and query parameters.
Both new Firebase domains are authorized for sign-in and verification returns.
New-origin sessions may require users to sign in again; account data remains in
the same Firebase project. Use `firebase deploy --only hosting` to deploy both
Hosting targets, or `--only hosting:neighborhelp` for the application alone.

Run `npm test --prefix functions`, `npm run test:emulator --prefix functions`,
and Flutter analysis/tests before deployment. Emulator tests use only synthetic
records in `demo-neighborhelp` and mocked ID Analyzer responses.

Deploy the four verification functions, the user/provider audit triggers, and
Firestore rules. Deploy a tested Flutter web build to publish the updated vendor
text; backend compatibility does not depend on updating the client immediately.
Complete one verification from inside NeighborHelp to confirm the live user
flow and final notification. Creating a hosted link consumes evaluation credits
even if the user does not complete it.

Official references:

- https://developer.idanalyzer.com/help/id-analyzer-api-v2
- https://developer.idanalyzer.com/help/webhook-2
- https://developer.idanalyzer.com/help/obtaining-key

## Verification on November 10, 2026

Validated 28 backend unit tests, 112 Firebase emulator/security tests (14 for
this integration), 190 Flutter tests, clean Flutter analysis, and a release web
build. A live, uncompleted DocuPass creation/read confirmed the owner binding,
profile, non-reusable Document + Face mode and issuing-country/type restrictions;
no real identity document was submitted by the deployment checks.

The seven affected Cloud Functions are ACTIVE in `us-central1`. Firestore rules
and Firebase Hosting were deployed to `neighborhelp-63771`. Live HTTP checks
confirmed that unsigned webhooks and unauthenticated creation are rejected,
localhost CORS is supported, and a correctly signed unlinked test webhook is
acknowledged without changing any production user's verification.

One verification started and completed from an unverified NeighborHelp account
remains the user acceptance check. The earlier manually created portal test is
not an account verification within NeighborHelp.
# Readability and administrator review

New app-created links explicitly reject unreadable front/back documents, low OCR
confidence, missing identity text, blurred/small images and missing faces. A server
quality check also inspects the authoritative completed transaction independently
of its overall decision: an unrecognized licence back cannot become verified even
if the vendor decision was changed to accept. Only warning codes and a retake flag
are saved in NeighborHelp; extracted names, ID numbers and document images are not
copied into these application records. Receiving a photo for analysis is not proof
that the identity check passed.

Unreadable results show clear retake guidance on customer/provider profiles and
the booking/listing setup popup. Existing unfinished links from the older quality
policy are not reused for a new capture attempt. No new session or paid scan is
created in the background; the user starts a fresh attempt explicitly.

`identityReviewCommand` authorizes the active Administrator and any configured
MFA policy on the server. Approvals first reconcile ID Analyzer and require a bound,
completed, readable result. Readable review cases can be manually approved; missing,
unfinished and unreadable results cannot. Rejection works for submitted checks
without needing the vendor API. Actor identity and role are server-derived, review
actions are audited, and the existing status-change triggers provide notifications.
Manual approval of a readable review survives duplicate callbacks, while later
quality failures still remove eligibility. Stale or wrong-role applications fail
with a specific explanation. The admin UI no longer labels every validation or
connection error as a permissions problem.

ID Analyzer reference: https://developer.idanalyzer.com/help/decision-flow
Profile/API reference: https://developer.idanalyzer.com/help/id-analyzer-api-v2
