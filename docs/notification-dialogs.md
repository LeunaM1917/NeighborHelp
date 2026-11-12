# Notification dialogs

Use `AppNotificationDialog` for informational notices, warnings, errors and confirmations. These share a preferred outer size of 560 × 360 logical pixels, with an X close button in the header. Flutter clamps the dialog to the available viewport and keyboard space on small screens.

Long messages scroll inside the dialog. Actions remain in the footer at normal sizes; short viewports, large text and narrow multi-action alerts move the actions into the scrollable content so they stay reachable. The existing theme supplies background and text colors.

The X dismisses the route with a null result. Callers must continue only on their explicit affirmative result, such as `answer == true`; closing a notice must not submit, approve, delete, upload or start another workflow. Existing action labels and callback behavior are retained.

Editing forms, map/location pickers, galleries, record viewers and the notification inbox retain their existing layouts. In particular, `ProviderServiceFormScreen` and its Add Service dialog were not resized or restyled. Only its certificate and submission notices use the shared notification surface. `WorkflowDialog` remains available for workflow forms.

Tests cover equal dimensions for short and long messages, dismissal and confirmation results, 320/560/1280-pixel viewports, 200% text, keyboard insets, scroll reachability and retention of the listing form's dimensions and unsaved contents after closing a notice.

Published to https://neighborhelp.web.app on November 12, 2026 (Asia/Manila), after static analysis, all 296 Flutter tests and the release web build passed.
