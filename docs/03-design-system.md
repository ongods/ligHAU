# Design system

**Project:** ligHAU · **Author:** Ong, Sean Keiffer S. · **Section:** CS-302

**Submitted:** September 20, 2026 · **Updated:** October 11, 2026

Source: *Final Design System (Revised)*, pages 1–8. The submission establishes the burgundy/gold palette, semantic Flutter styles, spacing constants, and reusable components. This document records that direction alongside the implemented differences.

ligHAU uses warm ivory backgrounds, white information panels, burgundy actions, and gold highlights. Material 3 and a manually defined, light-only `ColorScheme.light()` preserve the submitted palette. [AppTheme](../lib/theme/app_theme.dart) centralizes the visual tokens.

## Palette

| Role | Color | Use |
| --- | --- | --- |
| Primary / HAU Maroon | `#780F25` | Branding, primary actions, selected controls |
| On primary | `#FFFFFF` | Text and icons on burgundy |
| Secondary / Angelite Gold | `#D5A02B` | Photo accents, map highlights, brand location dot |
| Background | `#F8F7F3` | Warm ivory page background |
| Surface | `#FFFFFF` | Directory, fields, cards, dialogs |
| On surface / on secondary | `#242424` | Main text and text on gold |
| Secondary text | `#6B6B6B` | Supporting copy; named `border` in code |
| Outline / pathway | `#E7E2D8` | Subtle dividers and standard card boundaries |
| Panel border | `#C9C1B5` | Visible chat/map frame edges |
| Primary container | `#F5EAED` | Pale burgundy selections |
| Secondary container | `#FAF1DB` | Pale gold accents |
| Error | `#B3261E` | Validation and failure states |

The PDF defines primary, on-primary, secondary, surface, on-surface, and error roles. Background, border, and tint tokens extend the palette. Gold uses dark text; small white text on gold is avoided. The PDF states a 4.5:1 contrast target, but that is not a certification of every implemented color pair or photo overlay. Rendered contrast and assistive-technology checks remain separate review tasks.

## Type scale

The PDF proposes **Inter through `google_fonts`**, with 24 px `headlineSmall`, 20 px `titleLarge`, 16 px `bodyMedium`, and 12 px `labelSmall`. The implementation uses **bundled Manrope**, avoiding font network requests. [Manrope.ttf](../assets/fonts/Manrope.ttf) and its [SIL Open Font License](../assets/fonts/OFL.txt) are included.

| Flutter role | Size | Weight | Line height | Main use |
| --- | --- | --- | --- | --- |
| `displaySmall` | 44 | 800 | 1.15 | Desktop welcome |
| `headlineLarge` | 34 | 800 | 1.20 | Compact welcome |
| `headlineSmall` | 26 | 800 | 1.25 | Page headline |
| `titleLarge` | 20 | 700 | 1.30 | Section heading |
| `titleMedium` | 15 | 700 | 1.40 | Place titles |
| `bodyLarge` | 16 | Inherited regular | 1.60 | Prominent body text |
| `bodyMedium` | 14 | Inherited regular | 1.55 | Descriptions and chat |
| `bodySmall` | 12 | Inherited regular | 1.50 | Supporting copy |
| `labelLarge` | 13 | 700 | Inherited | Buttons |
| `labelSmall` | 11 | 600 | 1.40 | Captions |

Headings use tighter letter spacing. Body text supports multi-line descriptions. Facility cards wrap names to two lines before ellipsis; full titles are available on the details page. Screens reuse named styles with local adjustments where space requires them.

## Spacing and layout

The submitted system uses an 8 px base unit, 24 px screen edges, 8 px list gaps, and 16 px section gaps. Implemented `AppSpacing` adds two larger tokens:

| Token | Pixels | Typical use |
| --- | --- | --- |
| `xs` | 4 | Tight metadata gaps |
| `sm` | 8 | List/chip gaps |
| `md` | 16 | Mobile gutters |
| `lg` | 24 | Page padding |
| `xl` | 32 | Larger section gaps |
| `xxl` | 48 | Desktop breathing room |

Cards use 16–24 px corner radii, restrained shadows, and 1 px borders. Fields have 14 px radii and a burgundy 1.5 px focus outline. Filled/outlined buttons have 48 × 48 px minimum sizes; text buttons have 48 × 44 px minimums. This does not claim every control has a 48 px target.

At 900 px and wider, the directory occupies a 340 px sidebar with a 20 px gap before the map. On mobile, search and categories sit above the map; Browse opens a scrollable directory sheet. Zoom/recenter controls are in the map header, attribution has a footer, and selected-place information sits below the canvas. Short viewports scroll so labels and selection remain reachable.

The welcome screen uses two columns from 900 px wide and a single scrollable column below, with a 1120 px maximum width. Details/search/chat are constrained to 760 px; administrator content to 1000 px. Chat retains inner gutters and uses the scaffold's keyboard space handling.

## Photography and branding

The desktop welcome hero uses the supplied [campus photograph](../assets/branding/campus-welcome.jpg) with `BoxFit.cover`. A burgundy fade supports the white “Your campus. A little closer.” headline, and a gold accent connects the image to the theme. A subtle shadow and 32 px rounded corners integrate it with the form. Below 900 px, the welcome screen uses the ligHAU brand header and a 48 px gap before the form headline, without a photo hero.

The ligHAU mark is app branding, not an official university seal. Its direction arrow and gold location dot also appear in the browser favicon. Welcome, map, and secondary-page headers use coordinated mark variants.

## Components

| Component | Implementation | Contract and purpose |
| --- | --- | --- |
| `BrandLockup` / `BrandMark` | [brand_lockup.dart](../lib/widgets/brand_lockup.dart) | Shared wordmark/direction mark with size and layout variants. |
| `AppHeader` / `PageBody` | [app_header.dart](../lib/widgets/app_header.dart) | Header `title`/optional `actions`; body `child`/`maxWidth`. |
| `PanelFrame` | [panel_frame.dart](../lib/widgets/panel_frame.dart) | `child`, `color`, `radius`; paints the border above clipped content so children cannot cover its edges. |
| `FacilityCard` | [facility_card.dart](../lib/widgets/facility_card.dart) | `facility`, `onTap`, optional selection/subtitle/margin/border; shared catalog card. |
| `CategoryFilter` | [category_filter.dart](../lib/widgets/category_filter.dart) | `categories`, `selected`, `onSelected`, optional padding/border; scrollable category chips. |
| `CatalogStatusBanner` | [catalog_status_banner.dart](../lib/widgets/catalog_status_banner.dart) | Shared catalog loading/fallback and retry feedback. |
| `BuildingEditorDialog` | [building_editor_dialog.dart](../lib/widgets/building_editor_dialog.dart) | Validated administrator add/edit form. |
| `CampusVectorMap` | [campus_vector_map.dart](../lib/widgets/campus_vector_map.dart) | Map rendering and selection. |
| `AppTheme` | [app_theme.dart](../lib/theme/app_theme.dart) | Palette, typography, buttons, fields, chips, cards. |

The PDF also proposes `AppSideNav`, `TopAppBar`, and a floating `ChatbotButton` with callbacks controlled by parent screens. Those files are not implemented. Responsive screen navigation and shared headers serve those roles; assistant access is in the map header.

## Interaction and feedback

- **Map:** separate header, canvas, attribution, and selection regions keep controls from covering map content. Unmapped places show a missing-location message.
- **Chat:** the complete panel outline stays visible. Replies are selectable; numbered building matches show individual location/description context and details/map actions.
- **Forms:** labels, validation, focus borders, loading states, and disabled submission explain progress. Administrator errors distinguish credentials, throttling, and connection problems.
- **Catalog:** loading, stale/sample data, failure, and retry states are explicit. Unknown floors and unverified attributes are not replaced with invented badges.

The [mockup document](02-mockup.md) embeds the submitted screen designs and explains current behavior. `welcome-mobile.png` and `welcome-desktop.png` show the current welcome layouts. `place-mobile.png` is an earlier implementation preview that predates the latest panel changes.

## Validation

Existing automated checks include:

- [responsive_layout_test.dart](../test/responsive_layout_test.dart): seven screen types at 320 and 1440 px, covering welcome, details, directory, assistant, management, administrator sign-in, and map.
- [campus_layout_test.dart](../test/campus_layout_test.dart): narrow/short maps, desktop layout, 1.3× text scaling, separated controls/selection, and chat with a visible keyboard.
- [campus_chat_test.dart](../test/campus_chat_test.dart): multiple building matches and navigation to map selection.

The mobile welcome restoration passed analysis and all 20 tests in the responsive-layout and administrator-access suites. These are implementation checks, not a complete accessibility audit. Manual keyboard navigation, screen-reader behavior, and contrast over the desktop photo should be reviewed before claiming accessibility compliance.

## Changes since the last version

**September 20, 2026 — submitted revision:** mapped palette tokens to `ColorScheme`, type sizes to `TextTheme`, and repeated UI elements to proposed widget files with explicit callbacks.

**October 4, 2026 — implementation:** introduced bundled Manrope, shared branding, responsive navigation, and coordinated secondary pages. Removed unverified accessibility badges; the return action says “Back to map.”

**October 11, 2026 — UI refinement/documentation:** integrated the photograph, added map/chat frames, separated map controls and attribution, and clarified multiple chatbot matches. Updated tokens, component contracts, and coverage to match the repository.
