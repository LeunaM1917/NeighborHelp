# Required account setup

Customer and provider sign-ins, including email registration, Google registration,
returning sessions and ID Analyzer return links, pass through `AccountSetupGate`
before the existing dashboard shell is mounted. There is no dismiss or skip flag.
Existing accounts with incomplete details also finish setup on their next visit.
Administrator and retired verification-agency account handling is unchanged.

Required details:

- Both roles: full name and contact phone number.
- Customers: address, or barangay and city. A profile GPS pin is optional; the
  actual job location is selected separately in a contract offer.
- Providers: a valid base barangay and at least one valid service barangay.
  Exact home coordinates are not required or published.

KYC uses the existing ID Analyzer government ID and face verification flow.
The account opens only when the platform identity fields indicate approval.
An accepted authoritative ID Analyzer result retains its existing approval
behavior. Pending review, unfinished capture and rejected results remain blocked;
legacy records awaiting System Administrator approval continue to show that state.
The gate does not create paid verification sessions in the background. Refreshing
uses the existing status reconciliation endpoint, and errors leave setup required.

The setup screen reuses the existing profile editors. Required field validation
is enabled when opened from setup. Optional profile items such as photos,
education, portfolios, reviews and a first listing are not onboarding prerequisites.
Each listing still requires a current matching administrator-approved TESDA
certificate and separate listing approval.

The booking command validates customer setup and KYC before previewing/creating
an offer and rechecks participant eligibility before acceptance. Provider listing
rules require approved KYC and required account details for submissions or
activation, while private inactive drafts and deactivation remain possible.
These guards do not manufacture verification decisions or modify old contracts.

Tests cover layout at 390 and 1280 pixels, incomplete and rejected KYC, pending
approval, retry/error paths, automatic access after approval, required editor
validation and server/rules bypass attempts against the demo emulator.
