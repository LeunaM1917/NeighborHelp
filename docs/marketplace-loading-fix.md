# Booking and conversation loading repair

Implemented and deployed the backend repair on November 10, 2026 (Asia/Manila).

The localhost client had newer marketplace code than the deployed Firebase backend. Conversation import, barangay selection and availability callables were missing. Bookings also waited for every optional service/provider lookup before rendering, so an unavailable public profile hid the booking list. Scheduled search claimed availability even when the eligible provider directory was empty.

## Changes

- Booking records render immediately. Optional references load independently, deduplicate shared IDs and time out after 12 seconds. Missing profiles retain neutral labels and a retry notice; they do not remove booking history. Empty booking lists no longer become synthetic demo bookings.
- Messages distinguish pending/failed history import from a confirmed empty inbox. Existing conversations stay visible during import failures, and imports can be retried.
- Schedule search distinguishes an empty eligible directory, no matching schedule/location and successful matches. Check times explicitly use Manila time. Schedule controls have additional spacing.
- Browse category counts describe service types, and pricing/review copy reflects discussion, fixed/daily agreements and identity/certificate review.

## Firebase deployment

Project: `neighborhelp-63771`, Functions region: `us-central1`.

Published the matching callables: `inquiryCommand`, `getPublicDirectory`, `getPublicProviders`, `providerAvailability`, `providerArea`, `providerTimeOff`, `certificateCommand`, `bookingCommand`, `contractCommand`, `agreementCommand`, `paymentCommand`, `reportCommand`, `settlementCommand` and `workCaseCommand`.

Updated the related triggers: `auditUsers`, `auditServiceProviders`, `auditServices` and `onBookingUpdated`. Existing functions outside that target set were preserved. All 16 configured Firestore indexes are now `READY`, including the four previously missing indexes. This targeted deployment did not publish the remaining scheduled jobs or run the provider-location cleanup migration.

The provider directory is legitimately empty until providers choose their base/service barangays and satisfy the existing approval/certificate requirements. No barangays were guessed from private home coordinates and no certificate approvals were invented. Providers can complete the selection through their profile settings; administrators review certificates through the existing workflow.

## Verification

- Flutter analysis: no issues; 161 Flutter tests passed, including 10 new loading/empty-state regressions.
- Server checks: 17 unit tests and 82 Firebase emulator tests passed.
- Web release build succeeded; no hosted web client was published because the reported app runs on localhost.
- Six deployed marketplace endpoints passed localhost CORS preflight checks and returned the expected unauthenticated rejection, rather than a missing endpoint.
- The computer-use tool stopped browser verification because it could not confidently identify the active Chrome URL. These results establish code, component and endpoint checks; they do not claim an authenticated browser walkthrough.
- After hot-restarting localhost, the user confirmed that Bookings and Messages load successfully.

Hot-restart the running localhost app to load the Dart changes, then reopen Bookings and Messages. Provider search can return real providers after they complete their barangay selections and required certification review.
