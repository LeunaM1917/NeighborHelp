# Customer map repair and system review

Reviewed November 3, 2026 (Asia/Manila), on `codex/capstone-nine-gaps`.

This is a focused review of the supplied terminal output, screenshots, customer discovery/maps, profile location settings, related server commands and security rules. It is not an exhaustive penetration test. No production customer/provider coordinates were changed, and no hosting deployment was performed.

## What caused the reported behavior

1. **No real coordinates were available.** A read-only database check found 17 user records without saved coordinates. Of 13 provider profiles, 12 held the old Manila signup placeholder and one had no coordinates. The map correctly could not plot real provider locations, but the old UI neither explained this nor let members fix it.
2. **Past hires were removed from Nearby.** The home page split all ranked providers into mutually exclusive discovery and hired lists. If all eligible providers had been hired before, discovery became empty even though those providers were still available.
3. **Map rendering depended on profile photos.** Marker setup waited for image downloads and could replace the map with a loading widget. Repeated list changes could repeat this work. Provider pins now render immediately without downloading photos.
4. **The customer marker used a fallback as if it were their location.** Panabo is useful as a browse center but is not evidence of a customer's actual position. The new UI only draws the customer marker after a real position is selected.
5. **The service carousel overflowed.** The terminal identified a 66 px bottom overflow in `customer_home_tab.dart`. Its fixed card height did not reliably accommodate all rating rows. The replacement card uses a bounded flexible body, ellipsized labels and a height that scales with text size.
6. **The grey tiles cleared when browser cache was bypassed.** The supplied Network screenshot showed HTTP 200 responses and a disk-cached `vt` tile. The project Maps metric showed successful map loads. After enabling Disable cache and refreshing, the project owner confirmed that the grey tiles disappeared. No key, billing or quota change was made for this issue.

## Implemented changes

- Customer home has **Set my location / Change my location**, a manual pin picker and explicit current-location action. Saving updates the private customer profile. No location permission is requested just by opening the page.
- Customer settings also save a map pin. Provider profile settings save a service-base pin and explain that customers can see that service location.
- New profiles start with no coordinates. Existing placeholder records are preserved and treated as unknown until their owners select a location. Validation excludes only the exact historic Manila placeholder, not an entire area around Manila.
- Nearby and map pins use the same coverage/radius rules. Past hires remain eligible for Nearby and also appear in the hired section. Providers without coordinates are reported as needing location setup, not mislabeled as nearby.
- The map stays mounted while marker data changes. Photos no longer block markers. The customer has a blue location dot; provider pins identify service bases. Camera fitting handles coincident points safely, uses normal road maps and limits zoom to 6–17. Reload map and Expand map controls sit outside the embedded map, avoiding web overlay click conflicts.
- Home provider avatars use the shared failure-safe initials fallback. The carousel no longer uses the overflowing private card layout.
- Address lookup failures now identify unavailable server configuration and direct users to manual pins/current location.

## Required local acceptance steps

1. Fully restart the local Flutter app and hard-refresh Chrome. The browser cache check already resolved the old grey tiles.
2. As a customer, use **Home → Your Area → Set my location**, choose a pin or use current location, then save. A blue dot should appear at that saved position.
3. As a provider, open **Profile settings → Service base on the map**, select the actual service base, check the service radius and save. This is necessary for the existing placeholder profiles; the application cannot infer their true location.
4. Return to the customer account. A verified provider with an approved eligible service appears if the customer's location is within both 15 km and that provider's service radius. Past hires can appear in both Nearby and Hired before.

## Remaining findings, in priority order

### 1. Profile field types and server coordinate checks need hardening — high

The profile update rules whitelist field names but do not validate all field types. A malformed public name or location can cause strict client casts or directory serialization to fail. Booking creation validates the customer's submitted coordinates, but checks the provider's saved coordinates using truthiness and a distance comparison; it does not independently reject non-finite/malformed provider points. A NaN distance does not satisfy a normal greater-than comparison.

Evidence: [profile rules](../firebase/firestore.rules), [public projection](../functions/platform_operations.js), [booking coverage check](../functions/booking_commands.js), and `AppUser`/`ServiceProviderProfile` Firestore parsers.

Suggested fix: validate string lengths, coordinate `latlng`/null types, timestamps and positive finite radius values in rules; sanitize public DTOs; independently validate the provider point/radius on the server before computing distance. Add malformed-data tests. This is a confirmed validation gap from code review; no production exploit was attempted.

### 2. Creation writes can forge audit attribution — high

Update rules use `actorValid()`, but user, provider, service and booking-report creation paths do not consistently apply it. The audit trigger prefers `after.updatedBy` over the inferred creator, so a client can supply someone else's UID as the recorded actor on a permitted create.

Evidence: `actorValid()` and `allow create` paths in [Firestore rules](../firebase/firestore.rules); `actorId` selection in [audit triggers](../functions/platform_operations.js).

Suggested fix: enforce `updatedBy == request.auth.uid` whenever a client supplies that field on creation, or ignore it and use the known creator for creation events. Add explicit spoofed-attribution tests. Audit entries remain server-owned, but the attribution input needs this additional guard.

### 3. Authenticated customers still receive fabricated bookings — high

When the actual booking list is empty, the Bookings tab substitutes six demo records with dates, statuses and prices. These are UI-only records, but can be mistaken for real customer history and expose actions that cannot complete against a real booking.

Evidence: `_demoBookings()` fallback in [customer_bookings_tab.dart](../lib/screens/customer/tabs/customer_bookings_tab.dart).

Suggested fix: show a genuine empty state for authenticated accounts. Keep demonstrations in an explicitly labeled demo environment only.

### 4. Server address geocoding is not configured — medium

A read-only function configuration check found no Maps API key environment setting on the deployed `geocodeServiceAddress`. Its implementation requires `GOOGLE_MAPS_API_KEY`, so Locate address cannot complete until a suitable server key is configured. Manual map pins and device GPS work independently. The driving-distance function uses the same server-key helper and should be checked during that setup; the client can fall back to straight-line distances.

Evidence: `mapsApiKey()` and `geocodeServiceAddress` in [index.js](../functions/index.js); deployed function environment-name check. No key values are included in this report.

Suggested fix: configure a properly restricted server Maps key with the required APIs, then test geocoding and driving distance in the deployed environment. Do not reuse a browser/Android-restricted key without checking its restrictions.

### 5. Provider-role checks are inconsistent — medium

Some provider eligibility paths check an active owner and verified provider profile without requiring the owner's role to be Provider. Service creation rules likewise check ownership without a Provider role check. Historical stray provider profiles can therefore produce inconsistent role behavior, even though the current client routes by explicit role.

Evidence: `publicProvider()` in [platform_operations.js](../functions/platform_operations.js), service creation in [rules](../firebase/firestore.rules), and provider eligibility in [booking_commands.js](../functions/booking_commands.js).

Suggested fix: require the Provider role in these server/rules paths and review historical role/profile mismatches separately. Preserve transaction history during any migration.

### 6. Public eligibility projections can outlive certificate expiry — medium

Public provider projections are refreshed on document writes, while certificate expiry happens with time. The client merges those projections with bootstrap data. A stale projection can therefore continue advertising a technical listing after its certificate expires, even though server booking validation will reject it.

Evidence: certificate matching in [domain.js](../functions/domain.js), projection triggers in [platform_operations.js](../functions/platform_operations.js), and `_publicRecords()` merging in [firestore_service.dart](../lib/services/firestore_service.dart).

Suggested fix: store a projection validity deadline and enforce it when reading, or schedule projection refresh when certificates expire. Test expired projection behavior independently from booking rejection.

### 7. Tracked API-key inputs conflict with the local-secrets policy — medium

API-key literals remain in tracked Firebase/Android and web configuration files, including `lib/firebase_options.dart`, `android/app/google-services.json`, `android/app/src/main/AndroidManifest.xml`, `web/index.html` and `web/maps_loader.js`. The project instructions require ignored local inputs. Key values are intentionally omitted here.

Suggested fix: complete the existing local-secrets build workflow and verify app/API/referrer restrictions. Client keys remain visible in a shipped client, so moving build inputs alone is not access control. Review rotation if any key was exposed in a public repository.

## Terminal warnings that are not the map-pin bug

- Google's legacy `Marker` deprecation is a migration task; it is not a removal or an explanation for missing coordinates. See [Google's marker migration guidance](https://developers.google.com/maps/documentation/javascript/advanced-markers/migration).
- The DWDS "Cannot find context with specified id" messages concern debugger connection/deep links. Restarting the local debug run is appropriate; the supplied output does not establish them as the cause of the map data issue.

## Verification

Tests cover real versus placeholder coordinates, missing-location messaging, coverage boundaries, past hires in Nearby, immediate markers, stable map mounting, safe camera zoom, manual pin callbacks, GPS permission denial, device coordinate validation and carousel widths/text scales. Emulator tests verify that members can save only their own pins, customer coordinates remain private, and eligible provider service bases reach the public projection. Maps widget tests use a platform substitute rather than fetching real Google tiles. Browser tile recovery was confirmed by the project owner.

Final checks passed: 120 Flutter tests, 30 Firestore/Storage emulator tests, clean Dart analysis, a web release build and an Android debug APK build. Remaining findings above were reviewed and listed for follow-up; they were not silently deployed or represented as fixed.
