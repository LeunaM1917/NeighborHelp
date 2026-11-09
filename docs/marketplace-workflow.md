# Marketplace workflow changes

Customers discuss a job with providers before sending a fixed amount or daily rate offer. Each accepted offer creates its own service agreement. The System Administrator checks TESDA credentials; providers and legacy verification accounts cannot approve certificates. The academic paper is unchanged.

The subsequent [marketplace improvements](marketplace-improvements.md) add schedule search, customer confirmation, versioned amendments, payment acknowledgments and inquiry safety. Their workflow and rollout requirements supersede older descriptions below where applicable.

## Pricing and agreements

- Fixed pricing charges the proposed amount once. Daily pricing multiplies the proposed rate by the agreed number of working days, rounded to centavos on the server.
- Offers support 1–30 consecutive working days and 0.5–8 scheduled hours per day, in half-hour steps. Schedule inputs and agreement dates use Asia/Manila. Hours describe the schedule, not hourly billing. Schedule conflicts compare the actual daily work periods.
- Both participants must send text in the inquiry before an offer can be prepared. Photos can be exchanged as supporting information. Customers can open separate private conversations with multiple providers.
- The customer previews the complete server-generated agreement and explicitly accepts it. The provider must explicitly accept the same SHA-256 fingerprint. An administrator cannot accept, start or complete work on a participant's behalf.
- Providers can request changes. Customers discuss changes and send a new offer. Accepted scope, pricing and schedule are never silently overwritten; cancel the previous job with a recorded reason before replacing accepted work.
- Additional days, partial-day adjustments, materials and extra work do not generate automatic charges. They must be described in the agreement or a new mutually accepted offer. Payments stay directly between the parties; no escrow or payment processing was added.
- Both parties can read and download the agreement and acceptance record as text. Closing a contract requires completion or cancellation of its outstanding work.

## Certificate policy

The authoritative backend allowlist is `functions/service_policy.json`. Its Flutter counterpart is `lib/utils/approved_service_catalog.dart`; a test checks that they stay equal. Firestore rules also restrict provider submissions to supported catalog titles and fixed, daily or negotiable indicative pricing.

Initial qualification families are Carpentry NC II or NC III, Domestic Work NC II, Computer Systems Servicing NC II, and the supported domestic RAC qualification names. Cleaning remains available only with the matching Domestic Work qualification. Custom services, tutoring, errands and other unmapped tasks are hidden. Electrical work, master plumbing and other services requiring unsupported professional licences remain excluded. A TESDA certificate never substitutes for a required professional licence, permit or supervision.

The System Administrator opens the official TESDA registry, compares the holder, certificate number, qualification and validity, then records review notes and a result. Opening the checker does not approve anything. A missing or unclear result stays pending while the administrator follows up. Approval requires a supported qualification, uploaded private certificate document, number, valid dates and explicit confirmation of the registry check. Every published service requires its own matching approved qualification family.

Identity checks through Didit remain separate. Certificate images and inquiry attachments are restricted by Storage rules. Inquiry records and messages are private to their participants, including against unrelated administrator accounts. Reviewers can access certificate evidence through the admin certificate screen.

## Historical records and rollout

- Historical hourly booking prices and their display remain intact. Accepted legacy work can finish under its recorded terms. Legacy pending requests must be replaced with new fixed or daily offers.
- Old certificate approvals without a TESDA registry review must be reviewed again. Old public provider projections fail closed until refreshed. Unsupported listings are hidden in the new client immediately; backend commands independently reject ineligible services.
- The `enforceMarketplacePolicy` scheduled function runs every six hours to refresh public projections and deactivate unsupported or expired listings without deleting booking or contract history. Public eligibility also carries certificate expiry so the client does not keep offering an expired service between refreshes.
- Deploy the Functions and Firestore/Storage rules together, then release the updated web and Android clients. New callable functions are `inquiryCommand`, `certificateCommand` and `contractCommand`; `bookingCommand` now requires agreement preview and acceptance. Older clients cannot create or accept new requests under the former protocol.
- This change has not deployed or altered a production database. Use the demo emulator suite before deployment. No automatic migration deletes services, contracts or messages.

The agreement template requires review by a Philippine lawyer before real transactions. That review should cover the intended tasks, employment or domestic-worker obligations where applicable, payments, cancellation, liability, privacy, permits and dispute handling. The code records agreement and consent; it does not establish legal compliance by itself.

## References

- [TESDA Registry of Certified Workers](https://www.tesda.gov.ph/rwac)
- [TESDA training regulations and qualification downloads](https://www.tesda.gov.ph/download)
- [Domestic Work NC II training regulations](https://www.tesda.gov.ph/Downloadables/TRs/TR%20-%20Domestic%20Work%20NC%20II.pdf)
- [Civil Code of the Philippines, including Articles 1306 and 1318](https://lawphil.net/statutes/repacts/ra1949/ra_386_1949.html)
- [Electronic Commerce Act, Section 16](https://elibrary.judiciary.gov.ph/thebookshelf/showdocs/2/3888)
