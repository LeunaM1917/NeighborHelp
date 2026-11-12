# Provider signup and profile editors

Successful provider email/password signup and creation of a provider Google
profile mark an onboarding intent. The dashboard opens the existing Complete
your profile checklist once its provider profile has loaded. Customer signup and
existing account login do not mark this intent. Dismissing the checklist does not
reopen it on dashboard rebuilds; Profile Progress still opens it manually.

The checklist stays mounted beneath profile editors. Closing, cancelling, or
saving an editor returns to the checklist. Saved user, provider, and service data
are refreshed when the editor returns. The standard profile editors share a
720-by-720 preferred frame that fits the available viewport and keyboard space,
with a fixed header and top-right Close button. Existing Add Service presentation
is retained. Overview-only saves skip the service-area command when no area was
changed, so a new provider can save a bio before choosing a service area.

Signup offers Google and email/password; the unsupported Apple action was removed
for both account roles.

## Certificate selection and upload

The web certificate picker opens directly from the Upload click. Its input remains
connected until selection, cancellation, or failure. Listeners and cancellation
timers are then removed, so cancelling permits another attempt. Native clients
retain FilePicker. Supported documents remain PDF, JPG/JPEG, and PNG up to 5 MB.

The editor assigns a stable certificate entry ID before selection and reuses it
for uploads and the saved record. Certificates still require administrator review;
uploading does not grant verification or certificate approval. Private storage
references and the existing Firestore and Storage rules are retained.

## Validation

- `flutter test` covers signup handoff, automatic opening, return navigation,
  progress refresh, editor sizing and sticky close controls, cancellation/retry,
  and the certificate upload/save ID relationship.
- `flutter test --platform chrome test/certificate_document_picker_test.dart`
  covers actual browser input creation, cancellation, selection, and cleanup.
- The opt-in `CERTIFICATE_CHOOSER_BROWSER_INTEGRATION` test uses an external Chrome
  DevTools driver to supply a trusted browser gesture, intercept the native file
  chooser, and select a local disposable PDF. It does not upload production data.
- The security emulator suite checks that a new unverified provider can upload
  PDF/JPEG/PNG evidence and submit a pending certificate, while unrelated access
  and self-approval remain denied.

On Windows with Flutter 3.35, browser tests can require temporary SDK CanvasKit
files under `test/canvaskit/chromium` because of the test runner's asset path
handling. These temporary files were removed after verification. Desktop and
phone modal previews were also rendered and inspected using local test data.
