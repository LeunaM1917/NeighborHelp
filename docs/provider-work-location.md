# Provider work location

The provider offer-review dialog and booking-detail page display a shared
`BookingWorkLocationCard` with the saved work address, booking coordinates and
an Open in Google Maps button. The marker is read-only. The map does not request
the provider's live location, use their home coordinates or change the booking.
The marker follows updated booking data rather than a customer profile address.

The selected provider can see the location before accepting the offer, consistent
with the existing booking access policy. The new card also checks that its viewer
is that booking's provider. Existing Firestore rules retain private booking reads
for the participants and administrators; no public projections or access rules
are changed by this feature.

Missing, zero and historical default-signup coordinates do not create a marker.
For an older booking with only an address, the button searches that address and
the UI explicitly asks the provider to confirm the exact work location. If neither
an address nor a valid pin exists, directions are disabled. A failed external
launch displays a popup with selectable location details and allows retry.

Directions use Google's universal Maps URL format, with `api=1` and `destination`
set to the exact saved coordinates, or the encoded legacy address. No origin,
account identifiers or booking identifiers are included in the URL.
Reference: https://developers.google.com/maps/documentation/urls/get-started#directions

Widget tests cover mobile/desktop constraints, marker position and read-only
settings, pending and accepted offers, saved-location updates, unrelated viewers,
legacy records, URL encoding, launch errors and duplicate-click protection.
