# Account setup checks at booking and listing actions

Customers and providers can sign in and browse the normal dashboard, services,
messages and profile pages without completing setup. `RootGate` does not replace
their shell with an onboarding page or open a popup automatically.

`requireAccountSetup` checks current server records when a customer prepares or
previews a contract offer, or a provider opens/submits a service listing, resumes
its visibility, or accepts a booking. Incomplete profiles and unapproved KYC show
a dismissible popup with Complete profile, identity verification and Refresh status
actions. Keep browsing closes the popup without performing the protected action.
After completing the requirements, Continue resumes that action. Duplicate clicks
share one pending check; connection errors block the action and permit browsing.

Both roles need a name and phone number. Customers supply an address or barangay
and city; providers select a valid base barangay and service barangays. KYC keeps
the existing ID Analyzer approval flow. Unfinished capture can restart, pending
review waits for a decision, and rejected checks can be retried. Certificate and
listing approval requirements still apply separately to each provider service.

Booking commands and listing rules enforce eligibility independently of these
popups. There is no client-editable setup-complete flag. Private drafts and
deactivation remain available to the backend without granting publication rights.

Profile address text is saved as entered, including house, street and purok details.
Profile geocoding changes coordinates without replacing the address with Google's
formatted city result; stale lookup responses cannot overwrite later edits.
Provider address details are private in `users`, readable only by the owner and
administrators. Public provider maps use barangay centers and service barangays.
Area selection and location maintenance preserve the private address while
removing exact provider home pins. Empty profiles show Location not provided.

Tests cover browsing, popup dismissal, profile/KYC completion, pending and rejected
checks, retries and duplicate clicks, address save/reopen, geocoding preservation,
and server/rules eligibility and private-address access in the demo emulator.
