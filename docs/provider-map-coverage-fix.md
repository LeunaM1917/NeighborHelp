# Provider map coverage repair

The live eligible provider had approved identity verification, an active approved Door Repair listing, a current matching certificate, a valid base barangay, all 40 service barangays selected, and a current public projection. The provider was excluded by geographic coverage filtering, rather than account or listing eligibility.

The bundled barangay shapes were independently simplified with a tolerance of 0.005 degrees. This leaves gaps between some polygons. The public Panabo map center (7.3081, 125.6842) was not inside any of the 40 simplified shapes. Two active customers with saved locations were also excluded despite being less than one kilometre from the provider's approximate base.

Client and server now use the same coverage rules:

- Preserve membership in existing barangay polygons, including their edges.
- Never extend a selected area into an existing unselected polygon or an excluded hole.
- For a point falling between polygons, require it to be inside the Panabo city envelope and within the upstream simplification tolerance of a barangay edge. Assign that gap to the nearest indicative barangay using a deterministic tie rule.
- Preserve invalid-ID, out-of-city, verification, listing, certificate, distance and availability restrictions.

This is bounded handling of indicative geometry, not an authoritative legal boundary determination. It does not move customer locations or change provider selections. No identity, certificate or listing approvals are altered. The existing interface is preserved.

The city envelope uses the [same source snapshot](https://github.com/bendlikeabamboo/barangay-boundaries-repository/blob/main/2023-10-24/hierarchical_t0p005/component_cities.geojson) as the existing barangays. Its source hash and attribution are retained in `functions/panabo_city.json`. See the [upstream simplification documentation](https://github.com/bendlikeabamboo/barangay-boundaries-repository#key-features) and existing [data license](barangay-data-license.txt). Generate both city artifacts with `python scripts/build_panabo_city_boundary.py PATH_TO_COMPONENT_CITIES_GEOJSON`.

Shared fixtures cover the original city-center failure, selected/unselected barangays, invalid selections and out-of-city points. Flutter tests cover the map pin and recommendation; a Firebase emulator test covers creation and acceptance of a booking at the former coverage gap. A read-only check against current production data found that the repaired filter includes the eligible provider for both active customers with saved locations, without changing any database records.

Release the updated `bookingCommand` function and web client together so discovery and booking use consistent coverage checks. No rule, approval or public-profile migration is required.

The updated booking function and web client were deployed to `neighborhelp-63771` / https://neighborhelp.web.app on November 12, 2026 (Asia/Manila). Static analysis, the full Flutter suite, backend unit tests and Firebase emulator suite passed. The extra edge fixtures passed in both client and server tests. Existing browser sessions should hard-refresh to load the repaired client.
