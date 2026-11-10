# Barangay privacy, messaging and availability

The five requested improvements are implemented. See [the November 10 loading repair and deployment notes](marketplace-loading-fix.md) for the current targeted Firebase deployment status. The provider-location cleanup migration remains a separate maintenance step.

## Behavior

1. Inquiries and booking messages share one conversation for each customer/provider pair. Opening Messages imports older booking conversations in bounded pages. Original messages and photos remain readable; imports preserve sender, time and booking reference, skip invalid participant pairs and do not duplicate unread counts. Old message documents become an archive: clients cannot create messages or upload photos through that path. New texts/photos use the existing server limits, block checks, upload permits and reporting tools. A block pauses chat and new offers; it does not cancel accepted work.
2. Providers choose a base barangay and one or more service barangays from Panabo's 40 barangays. The app no longer asks for a provider home pin. The server derives the approximate center and display area from the catalog, ignoring old GPS fields. Old public projections without `locationPolicyVersion: 1` are unreadable under the new rules, and providers without a valid selection are hidden from discovery. Provider user addresses become barangay-only; current home GPS is removed by selection or maintenance. Customers' private job addresses and immutable historical agreements remain intact. Distance is a straight-line estimate from the barangay center; provider driving-distance labels and radius coverage are replaced with selected barangays. Coverage membership uses indicative polygons, not legal boundaries. Near a simplified boundary, discuss the service area and adjust the provider's selected neighboring barangays if appropriate.
3. Weekly hours can be overridden with date-specific time off. The editor selects whole days in Manila time. The server supports unavailable hours too: up to 100 future periods, 90 days per period, within one year. Accepted work must be amended or cancelled before overlapping leave can be added. Acceptance and time-off commands serialize against the same provider schedule lock. Public availability exposes dates, not private reasons. Every requested daily work period is checked.
4. Offers expire 72 hours after sending or at scheduled work start, whichever comes first. The server rejects late acceptance/change requests immediately, even before the cleanup scheduler runs. Every 15 minutes, the scheduler records expired offers in bounded batches and notifies both participants once. Legacy unanswered offers expire at their scheduled start. No acceptance, charge, completion credit or new contract is created by expiry. History stays available; continuing requires a new discussed offer. High-volume backlogs can take several sweeps to clear.
5. Chat has labeled controls, Ctrl+Enter sending, message sender/time semantics and theme colors for readable text. Offer history expands without a fixed row height. The map has an equivalent provider list. Barangay selection uses labeled dropdowns/checkboxes and 48px action targets. Automated checks cover narrow layouts at 100%, 200% and 300% text scale, target labels/sizes, contrast and keyboard sending. Actual TalkBack/VoiceOver, browser screen-reader and device testing remain a pilot task; automated checks do not establish full-app accessibility compliance. New helper copy uses English where translations are not yet available.

## Catalog provenance

`functions/panabo_barangays.json` is the shared source. `lib/data/panabo_barangays.dart` is generated from the same rows and checked for equality in tests. `scripts/build_barangay_catalog.py` reproduces both from the downloaded GeoJSON; it records the full source SHA-256. IDs and names correspond to the [PSA Panabo barangay list](https://psa.gov.ph/classification/psgc/barangays/1102315000).

Geometry is the 2023-10-24 hierarchical snapshot in [barangay-boundaries-repository](https://github.com/bendlikeabamboo/barangay-boundaries-repository/tree/main/2023-10-24/hierarchical_t0p005), derived from [NAMRIA](https://namria.gov.ph/) administrative boundaries dated 2023-11-06 and [PSA](https://psa.gov.ph/classification/psgc) PSGC data. Credit PSA and NAMRIA. The upstream simplification is 0.005 degrees; boundaries and computed centers are indicative and may differ from current local boundaries. They are not home locations, legal boundary evidence, travel routes or precise arrival estimates. Verify boundary suitability with the city before a wider pilot. The upstream MIT code license is preserved in `barangay-data-license.txt`; it does not replace the source datasets' attribution requirements.

To reproduce after downloading that snapshot:

```powershell
python scripts/build_barangay_catalog.py artifacts/barangays.geojson
```

## Coordinated rollout

Use a maintenance window and a tested backup/recovery process. Install matching Functions dependencies and build the client before rollout. Publish the new client together with matching Firestore/Storage rules, indexes and Functions; older clients cannot write to the legacy chat path or save precise provider pins. Wait for the offer expiry indexes to finish building before enabling its schedule. The Functions deployment includes `providerArea`, `providerTimeOff`, `expireContractOffers` and the administrator-only `migrateProviderLocations` maintenance callable. Existing certificate/admin role requirements remain in force.

Before changing current provider records, review the count-only migration plan under the intended operator credentials:

```powershell
node scripts/migrate_provider_locations.js --project YOUR_PROJECT_ID
```

After reviewing that concrete plan, apply it to the same project:

```powershell
node scripts/migrate_provider_locations.js --project YOUR_PROJECT_ID --apply
```

The script requires an explicit project, uses operator Application Default Credentials, and never prints addresses or coordinates. It processes 100 providers per page. It clears current legacy provider coordinates, replaces a valid base with its catalog center, removes user home pins/addresses, and deletes old public projections. It is safe to rerun. Profile triggers republish only eligible, selected providers; the policy scheduler can also refresh projections once deployed. Providers without selections must open profile settings and choose barangays before appearing in discovery. Historical booking addresses, original agreement text, messages and payment evidence are preserved. Backup snapshots and existing administrative audit history have their own retention/access controls and are not rewritten by this migration.

No production migration has been run by this coding change. Plan/apply/idempotency and historical preservation are exercised on synthetic demo-emulator records. Pilot with two accounts: compare providers in Messages, block across both booking/inquiry entry points, inspect a legacy conversation, set coverage and leave, try an expired offer, and review both sides of an accepted contract.

## Verification record

See [the local verification record](discovery-safety-verification.json) for test counts, release build checks, the APK fingerprint and remaining manual pilot checks.
