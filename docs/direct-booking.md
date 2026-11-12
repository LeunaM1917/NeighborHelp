# Direct booking

The service detail page again contains the original booking form: work address and confirmed coordinates, date, start time, duration, hourly or fixed pricing, and request notes. Customers send a pending booking directly. A chat exchange and a signed contract are no longer prerequisites. Messages links to the same booking form.

Hourly fees use the saved listing rate and requested duration on the server. Fixed requests preserve the customer's offered total for the provider to review. Accepting a direct request reserves the schedule and increments the provider's accepted count without creating a contract, agreement version or milestone. Providers can decline instead. Schedule changes require provider approval. After work starts, providers report completion and customers confirm it or request corrections. Confirmed direct bookings become `Completed` and remain eligible for reviews.

Existing contract records remain readable, and older contract clients retain their protocol during rollout. No existing bookings, agreements, messages, ratings or verification records are deleted.

## Functional requirements 1–5

For a real account walkthrough:

1. Use an active provider with completed account details, approved identity verification, a current matching administrator-reviewed certificate, and an approved active service listing. Select a base barangay and the barangays served. Its public map position is the approximate barangay center.
2. Open the customer map. Without a saved customer location, eligible provider pins remain visible. Saving a customer location applies real distance and service coverage checks. The display's default Panabo center is never treated as the customer's address.
3. Search by service, category, provider name, base area or a selected service barangay. Existing category, radius, price, rating and availability filters still apply.
4. Check recommendations and, for a specific appointment, use the existing date-based provider search. Results require provider verification, eligible listings, coverage and schedule availability. Provider acceptance checks current availability again under a shared transactional lock.
5. With a completed and verified customer account, open a service, fill in the booking form, confirm the job coordinates, and submit. Sign in as the selected provider to accept or decline. For accepted work, exercise start, report completion, customer confirmation and feedback. Work must start at or after its scheduled time; hourly work must run for its booked duration.

An empty result can be correct when there are no eligible approved services covering the chosen address and schedule. Do not bypass verification or invent provider locations to populate a demo.

## Verification and release

Run `flutter analyze`, `flutter test`, `npm.cmd test --prefix functions`, and `npm.cmd run test:emulator --prefix functions`. The emulator command needs Java 21 or newer. `flutter build web --release` builds the web client.

On November 12, 2026 (Asia/Manila), the updated `bookingCommand` function and Firestore rules were deployed to `neighborhelp-63771` in `us-central1`. The rules permit reviewed hourly listings. No production booking or verification records were created or migrated during this release.

The web release build was verified locally. Hot-restart a running localhost app to load the restored booking form; hosted web and Android clients need their own release. The restored client requires the updated backend. The changed expiry notification wording is covered by emulator tests; the optional `expireContractOffers` scheduler was not deployed in this targeted release.
