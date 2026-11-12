# Current service catalog

Plumbing Repair and Electrical Repair are offered under Repair and Technical
Services. Their customer cards, featured services, provider listing choices,
certificate matching, discovery projections, booking commands, and Firestore
submission rules use the same catalog entries.

Plumbing Repair maps to Plumbing NC II. Electrical Repair maps to Electrical
Installation and Maintenance NC II. The qualification names are listed in the
[TESDA downloads catalog](https://www.tesda.gov.ph/download/). Existing identity,
administrator service review, certificate review, expiry, and schedule checks
still apply; adding a catalog entry does not approve any provider or listing.

Both services use the existing project photographs from
`assets/service_picture/3. Repair and Technical Services/`. Their optimized WebP
copies are bundled with the app, avoiding network photo fallbacks. Source images
are preserved. `scripts/service-image-sources.json` records the selections and
`scripts/optimize-service-images.py` generates the asset mapping and size report.

The following eight standard Construction options were removed from the catalog:

- Masonry
- Concrete Block Laying
- Bricklaying
- Wall Plastering
- Construction Carpentry
- Tile Installation
- Tile Repair
- Construction Painting

The empty Construction category is absent from browsing and new listing choices.
Existing records and transaction history are retained. Retired standard titles
are not eligible for new discovery or bookings. Separate administrator-approved
custom service proposals continue to require their own approved qualification.

The layout, navigation, and booking flow are unchanged. The preview category
label can wrap within its existing row so the long technical category name does
not overflow a narrow card.

Validation includes Flutter catalog, bundled asset, certificate eligibility,
provider form and draft-retention tests; backend domain tests; and the complete
Firebase emulator suite. Emulator cases cover direct booking acceptance for both
new services, wrong-certificate rejection, and denial of retired submissions.
