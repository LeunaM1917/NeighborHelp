# NeighborHelp HCI accessibility handoff

Status: local design specification prepared; Stitch project access returns HTTP 401.
No screens have been generated or synchronized. These are generation request templates,
not a verified Stitch-to-Figma export. The current Flutter source was inspected; a deployed
app or live Firebase data was not accessed.

## Flutter source of truth

Use `lib/figma_ui/guest_marketing_root.dart`, `marketing_layout.dart`,
`pages/figma_home_page.dart`, `figma_layout.dart`, `widgets/figma_brand_row.dart`,
`marketing_service_catalog.dart`, `marketing_featured_services.dart`, and
`lib/theme/app_colors.dart`. Preserve the guest marketing page and its source order.
The marketing header is a custom 64-unit row, rather than a Flutter `AppBar` widget.
Map the requested AppBar icon to this header's actions. A new accessibility icon,
settings controls, skip link, focus styles, and semantics are proposed additions.

| Parameter | Existing Flutter value | Figma mapping |
| --- | --- | --- |
| Units | Flutter logical pixels | Figma px at a 1:1 design scale |
| Content width | min(1280, viewport - 2 * side padding) | Centered frame, fill width, max 1280 |
| Side padding | 16 below 640; 24 at 640–1023; 32 from 1024 | Responsive frame padding |
| Header | Height 64; logo 52; wordmark Inter 19/700 | Fixed height at default text size |
| Desktop nav and hero | Viewport >= 768 | Desktop nav; hero horizontal Auto Layout |
| Hero | Equal columns; gap 48; vertical padding 64 | 616-unit columns in a 1440 frame |
| Compact hero | Viewport < 768 | Vertical Auto Layout; gap 48; content width 358 at 390 |
| Hero title | Inter 48/700, line height 1.1 | 52.8 line height |
| Hero description | Inter 18/400, line height 1.45 | 26.1 line height |
| Hero image | Height 384; outer padding 4; radii 16/12 | Image fill in editable rounded frame |
| Hero badge | Right -16, bottom -16; padding 16; radius 12 | Absolute child of image frame |
| Main sections | Vertical padding 64 | Vertical Auto Layout |
| Section headings | Inter 30/700 | Editable heading layers |
| Category grid | Available content >=1024: 5; >=768: 4; otherwise 2 | Measure content width, not viewport |
| Category grid gaps | 16 horizontally and vertically | Grid/wrapped Auto Layout gap 16 |
| Category aspect ratios | 1.15 for 5 columns; 1.22 for 4; 1.02 for 2 | Default-size reference constraints |
| Category card | Radius 12; border 2; padding 16 horizontal/18 vertical | Editable frame; icon 44 x 44, glyph 24 |
| Steps | Available content >=768: horizontal; otherwise vertical | Gap 32 wide, bottom spacing 24 compact |
| Step card | Padding 32; radius 12; icon circle 56/glyph 30 | Editable nested components |
| Featured grid | Available content >=768: 3 columns; otherwise 1 | Gap 24; heights 320 wide/300 compact |
| Featured card | Radius 12; border 2; image height 192; body padding 20 | Separate image, rating pill, title, metadata |
| Footer | Background #111827; vertical padding 48 | 4 equal columns at viewport >=768; stacked below |

At 1440: content x=80, width=1280, hero column=616, category cell=243.2,
featured cell=(1280-48)/3. At 390: content x=16, width=358, category cell=171,
one featured column. At 768: header and hero are wide, but content width=720,
so categories still have two columns, steps stack, and featured cards have one column.
Do not collapse these separate breakpoints into one.

At 200% text size, a fixed 64-unit header and fixed-height grids can clip content.
Keep the baseline measurements above, and add explicitly named `TextScale=200%`
variants with growing row/card heights, wrapping labels, and a stacked search field/button.
For compact headers, move nav, location, login, and signup into the existing menu when
the added 48-unit accessibility target would overflow. This is a proposed adaptation,
not a claim about current Flutter behavior. Preserve all actions in the menu.

The compact marketing frame represents Flutter web at phone width. Android/iOS enter
through `MobileAuthGate`; they do not use this guest landing as their normal home.
For a later app implementation, reuse the same settings in `AppShellLayout`, keep
bottom navigation, use a sheet on native/compact app screens, and hide marketing footers.

## Required variants

### Accessibility Dropdown Overlay

Name: `NeighborHelp / Landing / AccessibilityOpen / Desktop` and a compact counterpart.
Add `Icons.accessibility_new_rounded` (24 glyph, minimum 48 x 48 target), labeled
"Accessibility settings", in the header actions before location/login/signup.
Desktop panel: reuse the existing location overlay's width 288, radius 8,
2-unit border, vertical offset 8, and maximum scrollable height 384.
Align to the icon, clamp to an 8-unit viewport margin, and scroll internally when needed.
All new control rows have a minimum 48-unit target and grow with text.

Use a settings dialog/popover containing form controls, not an ARIA menu full of selects.
Keep these exact visible groups:

- **High Contrast Mode**: toggle, explicit On/Off state.
- **Text Resizing (Large/Dyslexic Font)**: independent size selector
  (100%, 125%, 150%, 200%) and font selector (Inter, OpenDyslexic).
- **Screen Reader Hints**: toggle controlling additional explanatory hints.

Include an explicit Close control and Reset to defaults. Enter/Space opens the panel;
focus moves to Close, then High Contrast, size, font, hints, Reset. Tab/Shift+Tab stay
within the modal settings dialog; Escape and Close dismiss it and restore focus to
the accessibility icon. Outside-click dismissal also restores focus. At compact web
width keep the anchored, clamped dialog if it fits; native app adaptation uses a sheet.
Do not require hints to be enabled for baseline labels, roles, or keyboard access.
OpenDyslexic must be installed or bundled before export; use Inter as an explicit
fallback if unavailable. Do not claim a specialized font guarantees reading improvement.

### High-Contrast Variant

Name: `NeighborHelp / Landing / HighContrast / Desktop` and a compact counterpart.
Retain the blue-to-white hero, section ordering, images, cards, and navy branding.
Use primary text #111827; all secondary text/placeholder text #374151;
primary button #1E3A5F with #FFFFFF label; hover/pressed #152D47 with #FFFFFF label;
green interactive accent #2D5018 with #FFFFFF label.
Use #1E3A5F for informative icons, rating stars, and control/card borders on light
surfaces; pair selection with a check/underline and text, not color alone.
Use white footer text and icons on #111827. Ratings stay on an opaque white pill.
No functional text sits directly on an uncontrolled photograph.

Every listed normal-text pair exceeds 7:1 (AAA SC 1.4.6), including the darkest hero
gradient endpoint. Essential control boundaries and informative icons exceed 3:1
(AA SC 1.4.11). Focus on light surfaces uses a 3-unit navy outline with a 2-unit white
gap; dark/footer/filled controls use a white inner and navy outer indication where
needed. Keep focus fully visible and ensure the fixed header does not cover it.
Check actual exported fills, opacity, focus, hover, and pressed states after generation.
These calculations establish palette contrast, not complete WCAG conformance.

### Screen Reader / Tab-Navigation Flow

Name: `NeighborHelp / Landing / AssistiveFlow / Desktop` and a compact counterpart.
Preserve the landing layout; put numbered badges and leader lines on a separate,
noninteractive annotation layer so annotations do not change page geometry or semantics.

Desktop keyboard focus sequence:

1. Skip to main content (visible on focus; proposed addition).
2. NeighborHelp home link.
3. Home, Browse Services, How It Works, For Providers, About Us.
4. Accessibility settings.
5. Location ("Location, Panabo City, Philippines").
6. Log In, Sign Up.
7. Service Needed, selected (one toggle in the current page; do not invent a provider toggle).
8. Service search text field (persistent semantic label "What service do you need?").
9. Search button.
10. All 11 category buttons in source order, row by row.
11. All 12 featured service cards in source order, row by row.
12. Footer links: Browse Services, How It Works, Safety; Become a Provider, Resources,
    Success Stories; About Us, Contact, Privacy Policy.

Compact web: skip link, brand, menu button, accessibility icon, remaining visible header
actions, then the same main content sequence. Hidden drawer links are excluded until
the drawer is open. When overflow actions move into the drawer, preserve the desktop
navigation order within it and restore focus to the menu trigger on dismissal.

Screen-reader reading sequence is separate: banner and navigation; main; hero h1,
description and search group; trust statements and provider summary; categories h2
and list; how-it-works h2 and three step headings/descriptions; featured-services h2
and list; contentinfo and footer groups. Headings, paragraphs, trust statements and
step descriptions are read but do not become ordinary Tab stops. Decorative photos,
avatars and icons are excluded when their adjacent text already conveys the meaning.

Category semantics: one button per card, e.g. "Cleaning, 15 services". Service semantics:
one button per card, e.g. "House Cleaning, 4.9 out of 5, 127 reviews, from 350 pesos
per hour"; do not create separate focus stops for image, star, price and reviews.
Selected state, expanded state and setting changes are announced. Use Enter/Space
for controls, normal text-entry keys in the search input, and Shift+Tab for reverse
navigation. Do not assign positive HTML tabindex values.

Flutter implementation mapping: `Semantics` for labels, headings and states;
`ExcludeSemantics` for duplicate decorative children; `FocusTraversalGroup` and
`OrderedTraversalPolicy` if required; `FocusNode` restoration and `Shortcuts/Actions`
for Escape. These are prototype annotations; no Flutter behavior has been changed.
The current Search callback and some footer callbacks are empty, so prototype
destinations are demonstration states rather than verified application navigation.

## Editable Figma handoff

Use separate top-level 1440-wide desktop and 390-wide compact frames, with full-page
content and vertical-scroll prototype viewports (900 and 844 respectively). Names
above are requested layer/frame names, not verified names created by Stitch.
Use horizontal/vertical Auto Layout for Rows/Columns, fill/hug sizing for
Expanded/intrinsic content, and separate reusable instances for header, search,
category card, step card, service card, footer and accessibility controls.
Images remain image fills; typography, vector icons, strokes and annotation text
remain editable. Add component properties `Contrast`, `TextScale`, `Font`, `Hints`,
`AccessibilityOpen`, and `FocusState`. Record Flutter paths on component descriptions.
Do not flatten the page into a screenshot or outline text glyphs.

Prototype links: landing icon -> overlay; High Contrast On -> high-contrast frame;
size/font -> corresponding resize state; hints -> hints-enabled state; Close/Escape
-> originating landing state. A Figma keyboard demo and focus-order annotations do
not establish that a exported Figma prototype works with an actual screen reader.

The MCP tool schemas retrieved in this session support screen generation and
variants. They do not expose a separate Figma synchronization/bridge command.
The exact bridge plugin and its requirements were not provided. After successful
Stitch generation, inspect returned screens and any `figmaExport` resource, then
validate the user's export workflow. Editable Auto Layout cannot be guaranteed from
a generation prompt alone.

## Evidence and verification

`stitch-requests.json` contains six credential-free request templates and calculated
contrast pairs. `sync-stitch.mjs --list` checks authentication without mutation;
`--project PROJECT_ID --sync` sends each prepared generation request once.
Do not retry a timed-out generation; inspect project screens for completion instead.
Confirm saved screens, actual dimensions, typography, contrast and Figma editability
before reporting synchronization complete. No Dart files were modified.

References:
- [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-enhanced.html)
- [Non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)
- [Resize text](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html)
- [Modal dialog keyboard behavior](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/)
- [Stitch SDK authentication](https://github.com/google-labs-code/stitch-sdk)
