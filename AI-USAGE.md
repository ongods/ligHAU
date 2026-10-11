# AI usage

**Project:** ligHAU · **Author:** Sean Keiffer S. Ong (`ongods`)

**Record prepared:** October 11, 2026

I built the initial Flutter frontend scaffolding: the theme, facility model, reusable controls, screen layouts, and basic button/navigation behavior. Those versions appear in the September 29–October 2 commits. I later used AI assistance to extend the map and backend, improve responsive layouts, and fix interaction problems.

This is a retrospective record assembled from the implementation history and development discussion. Dates below are commit dates, and requests are summarized rather than quoted from saved prompt transcripts. The current files combine my original work with later AI-assisted revisions; the original commits identify the scaffolding I contributed. I do not claim an exact percentage of independently written code from commit counts alone.

## 1. How I used AI

### 2026-10-05 — Replace the mock campus map with an interactive map

- **Tool:** Codex / ChatGPT coding assistance.
- **What I asked for:** Help develop the campus map beyond the initial frontend prototype so users could select actual campus buildings.
- **What it gave back:** MapLibre/MapTiler integration, OpenStreetMap campus geometry, map configuration, and map-data/style checks.
- **What I kept, what I changed, and why:** I kept the interactive map and directory connection. Buildings without verified map positions remain available in the directory with a missing-location state. This avoids treating the prototype's relative marker positions as real coordinates.
- **Commit:** [Add campus vector map and MapTiler configuration](https://github.com/ongods/ligHAU/commit/aa20ed656ad48bf03836e8c913da6de547939ecc).

### 2026-10-05 — Refine the theme and responsive frontend

- **Tool:** Codex / ChatGPT coding assistance.
- **What I asked for:** Improve the appearance and consistency of the existing screens while retaining the campus app's burgundy and gold direction.
- **What it gave back:** Bundled Manrope typography, reusable branding and headers, revised cards/forms, responsive welcome and directory layouts, and layout tests.
- **What I kept, what I changed, and why:** I kept the shared styles and responsive layout direction. Facility details were revised to avoid unverified accessibility badges and invented floor counts. The original screen structure remained the starting point, while individual layouts and controls were refined.
- **Commits:** [Theme, typography, and branding](https://github.com/ongods/ligHAU/commit/fe6d9d14c3bd8dc76b1b1e4a82743a68583becef); [Facility screens and responsive layouts](https://github.com/ongods/ligHAU/commit/c79d108466839d203f85e4b96d2df867fed2e211).

### 2026-10-08 — Add persistent storage and server-verified administrator access

- **Tool:** Codex / ChatGPT coding assistance.
- **What I asked for:** Help turn the management prototype into shared, persistent campus data with authenticated administrator writes and a working chatbot backend.
- **What it gave back:** A Node API, SQLite storage, password hashing, expiring sessions, validated catalog CRUD, Gemini requests, rate limits, usage records, auditing, and backend tests.
- **What I kept, what I changed, and why:** I kept provider credentials and write authorization on the server. The earlier local administrator check was replaced with real backend verification. Public visitors can read the catalog, but changing records requires an authorized administrator session.
- **Commit:** [Persistent campus backend, admin authentication, and chatbot limits](https://github.com/ongods/ligHAU/commit/e6c0e8f342ff05fa51e385637fd646b863fad922).

### 2026-10-08 — Connect the screens to one shared catalog

- **Tool:** Codex / ChatGPT coding assistance.
- **What I asked for:** Connect the frontend to saved data so map, search, details, administration, and chatbot actions use the same records.
- **What it gave back:** `FacilityRepository`, HTTP services, administrator editing forms, catalog status feedback, shared updates, and interaction tests.
- **What I kept, what I changed, and why:** I kept the shared repository rather than independent copies of the sample list. It refreshes active views, exposes stale/sample states, and submits record versions so conflicting edits can be rejected. Backend failures now produce an explicit state rather than presenting sample data as a successful live load.
- **Commit:** [Backend connection and catalog synchronization](https://github.com/ongods/ligHAU/commit/590012ad5982a61ca88381470c7d9b65dd5b7511).

### 2026-10-08 — Improve local development and release checks

- **Tool:** Codex / ChatGPT coding assistance.
- **What I asked for:** Help make local startup repeatable and verify the app before deployment.
- **What it gave back:** A web launch script, map-config synchronization, smoke/soak tools, private-credential checks for generated web assets, and required workflow checks.
- **What I kept, what I changed, and why:** I kept the frontend on port 53923 and the backend on 8787. The workflow separates browser-safe configuration from private backend credentials. Local development should reuse the project sessions rather than start duplicate servers when a port is occupied.
- **Commit:** [Development tooling and deployment verification gates](https://github.com/ongods/ligHAU/commit/379384b5bf06aefb7783343b8cfcf39a0c1c0fca).

### 2026-10-10 — Add PostgreSQL support and deployment packaging

- **Tool:** Codex / ChatGPT coding assistance.
- **What I asked for:** Help support shared hosted storage and package the backend separately from the Flutter web frontend.
- **What it gave back:** A private PostgreSQL schema, a restricted runtime role and RLS policies, PostgreSQL services, SQLite import tooling, Docker configuration, and an updated Pages workflow.
- **What I kept, what I changed, and why:** I kept SQLite for local use and PostgreSQL support for hosting. Database connections stay server-side; schema-owner credentials are separate from runtime credentials. The Flutter build receives only browser configuration. Deployment files and tests exist, but that alone does not prove a live deployment or live database permissions are correct.
- **Commits:** [Private PostgreSQL schema](https://github.com/ongods/ligHAU/commit/76234faa0715534762d819b3f4df5b70f21f3cad); [PostgreSQL storage and hosting support](https://github.com/ongods/ligHAU/commit/b2510b601708242126cfd3a71cd824935a092d3d); [Docker and Pages packaging](https://github.com/ongods/ligHAU/commit/8129e9dd6022d953f4d6a7f02c65b4b55993f242).

### 2026-10-10 — Verify chatbot actions and fix map selection

- **Tool:** Codex / ChatGPT coding assistance.
- **What I asked for:** Help make building results and map actions reliable after catalog updates and during map interaction.
- **What it gave back:** Chat endpoint handling, a test for resolving newly added buildings from the live catalog, building fill/outline layers, corrected selection identifiers, and pin visibility changes.
- **What I kept, what I changed, and why:** I kept catalog-backed chatbot actions and checks for newly added records. Map selection now uses the facility's resolved location/feature identifier. Campus pins remain visible when basemap labels would otherwise suppress them.
- **Commits:** [Chatbot catalog matching and regression coverage](https://github.com/ongods/ligHAU/commit/eeb145af99321d85fb4e79d6dc500097fca86e8d); [Building highlights and map pin visibility](https://github.com/ongods/ligHAU/commit/03a75fdeee583a69d72a348734a73bfc9869058c).

### 2026-10-11 — Improve multiple building matches, panel borders, and the welcome photo

- **Tool:** Codex / ChatGPT coding assistance.
- **What I asked for:** Improve chatbot replies when several buildings match, fix the chat panel's missing-looking sides, keep map borders and controls clear, and integrate my uploaded campus photo into the welcome design.
- **What it gave back:** Numbered building-match cards with individual details/map actions, selectable reply text, complete panel frames, separated map controls/attribution/selection, and a photo-based welcome hero.
- **What I kept, what I changed, and why:** I requested another UI pass after the assistant panel looked stripped at the sides and map elements overlapped. I kept the full border treatment and clearer match cards. I supplied the photograph and asked for coordinated gradients, spacing, and typography instead of simply inserting the image. The photo is supplied material, not an AI-generated image.
- **Commit:** [Chatbot, map, and welcome UI improvements](https://github.com/ongods/ligHAU/commit/1b9355f9cec045775e31c3ccebdaee783b46696b).

### Documentation assistance in the current working tree

AI also helped draft the proposal, mockup, design system, security/privacy record, and this usage log from the supplied PDFs and repository. These documentation changes are currently uncommitted, so the implementation links above do not claim to include them. I corrected the security checklist rewrite: its original statements were restored, and checkbox states were then updated using actual test/scan evidence. Live RLS and final-video checks remain incomplete rather than being recorded as passed.

## 2. Where the AI got it wrong

### Case 1 — A local administrator guard was only a prototype

- **What it gave me:** The AI-assisted administrator prototype compared a username/password in Flutter and stored an authenticated flag in memory.
- **What was wrong with it:** That can demonstrate screen navigation, but it cannot protect a shared service. Browser code is visible, and a frontend flag does not authorize a backend write. It needed to remain explicitly a prototype.
- **What I did instead:** The later revision uses server-verified passwords, hashed account storage, expiring bearer sessions, and permission checks on protected API requests. The ordinary visitor sign-in is still a prototype, and I do not describe it as student authentication.
- **Commits:** [Original local prototype](https://github.com/ongods/ligHAU/commit/7eb55e94543679e389197c941157d18f364a9f8f); [Server authentication](https://github.com/ongods/ligHAU/commit/e6c0e8f342ff05fa51e385637fd646b863fad922); [Frontend session connection](https://github.com/ongods/ligHAU/commit/590012ad5982a61ca88381470c7d9b65dd5b7511).

### Case 2 — Map pins and selected buildings were not consistently visible

- **What it gave me:** The earlier map integration used label-placement collision rules for campus pins and compared tapped feature identifiers directly with OSM way identifiers.
- **What was wrong with it:** Pins could disappear when the basemap's labels changed with zoom. The direct identifier comparison did not cover every facility identity, and the selected building needed a clear fill/outline.
- **What I did instead:** The corrected version resolves the facility's location and feature identifier, adds building fill/outline layers, updates them when selection changes, and allows campus pins to remain visible despite label placement. Tests cover the map data and selection behavior.
- **Commit:** [Building highlights and map pin visibility fix](https://github.com/ongods/ligHAU/commit/03a75fdeee583a69d72a348734a73bfc9869058c).

### Case 3 — The chat/map layout needed another QA pass

- **What it gave me:** The earlier responsive layout had useful content but the chat panel looked as though its sides had been removed, and map controls/selection did not have sufficiently clear separate regions.
- **What was wrong with it:** The boundaries were difficult to see, controls could cover map content, and long replies with several matches were harder to follow. Scrolling to the very end could also hide the beginning of a new answer.
- **What I did instead:** I asked for the border and overlap problems to be corrected. The revision adds `PanelFrame`, paints the outline above clipped children, separates map regions, provides numbered match cards, and scrolls the newest reply into view. Narrow/short layouts, enlarged text, and keyboard space are included in the layout checks.
- **Commit:** [Panel, chatbot, and map UI correction](https://github.com/ongods/ligHAU/commit/1b9355f9cec045775e31c3ccebdaee783b46696b).

## 3. Who wrote what

### Written by me — `ongods`

My main independent contribution was the initial frontend scaffold and basic interactions. I established the screens and reusable controls before the later map, backend, and UI-refinement work. The links below point to those original versions; they do not claim that every line in the current version is still mine.

| Original file(s) | Commit | What I built and why |
| --- | --- | --- |
| [app_theme.dart](lib/theme/app_theme.dart) | [566d2b8](https://github.com/ongods/ligHAU/commit/566d2b88cf6c4a6979a51d7b2031240c0b2e0503) | The first centralized light theme, campus palette, spacing constants, and button/field styles. Sharing them avoids repeating the same styling in each screen. |
| [facility.dart](lib/models/facility.dart), [mock_data.dart](lib/data/mock_data.dart) | [847d22f](https://github.com/ongods/ligHAU/commit/847d22fc4b610dd3f8333b7d8111c3a5b709e5c8) | A facility model and sample directory used to build the UI before a backend existed. The initial data was prototype content, not a verified campus database. |
| [facility_card.dart](lib/widgets/facility_card.dart), [category_filter.dart](lib/widgets/category_filter.dart), original `chatbot_button.dart` | [6f74b93](https://github.com/ongods/ligHAU/commit/6f74b930631b82ec919ed4466c9a347611f67ab3) | Reusable list cards, category chips, and chatbot access. Callbacks let the parent screen decide what a tap does. The standalone chatbot-button file was later removed when navigation changed. |
| [login_screen.dart](lib/screens/login_screen.dart) | [73d9d2b](https://github.com/ongods/ligHAU/commit/73d9d2b93a1b34b146af7ec84b992331cb328e6d) | Account fields, password show/hide, nonempty-input feedback, Sign In, Continue as Guest, and an administrator entry button. `setState` updates password visibility; navigator calls open the next screen. This was navigation scaffolding, not real authentication. |
| [map_screen.dart](lib/screens/map_screen.dart) | [07bdaae](https://github.com/ongods/ligHAU/commit/07bdaae37accc2ac33e5fe992e63242763a6739c) | The first map-screen structure: mock building markers, category selection, search access, selected-building state, and links to other screens. It let me establish the interaction flow before connecting a real map provider. |
| [building_info_screen.dart](lib/screens/building_info_screen.dart), [search_screen.dart](lib/screens/search_screen.dart) | [0997a13](https://github.com/ongods/ligHAU/commit/0997a13d94fbe393409c69619ec9b7a2feefe2ad), [7e78673](https://github.com/ongods/ligHAU/commit/7e78673cd2b088f1324a0d8300e61641485a9f19) | The initial details layout and keyword-search screen. Search filtered the sample list by name/category/location and opened the chosen facility's details. |
| [chatbot_screen.dart](lib/screens/chatbot_screen.dart) | [fdebeb0](https://github.com/ongods/ligHAU/commit/fdebeb05757b490fbad36855a406a2e81e63fb5d) | The initial message model, user/assistant bubbles, input field, send button, scrolling, and placeholder response. This established chat interaction before Gemini was connected. |
| [admin_dashboard_screen.dart](lib/screens/admin_dashboard_screen.dart) | [ccbe2b6](https://github.com/ongods/ligHAU/commit/ccbe2b672e3d8552ec7bd61817fc52cbb6beddc3) | The initial administration layout, sample building list, edit-dialog fields, action buttons, and logout navigation. The first dialogs were a UI prototype; persistence and permission checks came later. |
| [main.dart](lib/main.dart) | [455797a](https://github.com/ongods/ligHAU/commit/455797aded319b5b419533b87e7102d8d13960fd) | The application entry point that runs `LigHAUApp`, applies the shared theme, sets the title, and opens the login screen. |

I also supplied the campus photograph and directed the later UI corrections: clearer building matches, complete chat borders, and map controls with no overlapping elements. Those are my inputs and design decisions; the resulting implementation changes were AI-assisted.

### AI-assisted implementation

AI contributed substantial code to the real map renderer and geometry handling, HTTP services, shared catalog synchronization, server persistence/authentication, provider limits/usage, PostgreSQL support, deployment tooling, tests, and later UI refinements. I distinguish these from my original screen/button scaffolding even when they modify the same files.

### The AI-written part I understand best

- **File:** [lib/services/facility_repository.dart](lib/services/facility_repository.dart).
- **Commit:** [Shared catalog integration](https://github.com/ongods/ligHAU/commit/590012ad5982a61ca88381470c7d9b65dd5b7511).
- **What it does and why we kept it:** `FacilityRepository` is a shared `ValueNotifier<List<Facility>>`. Screens listen to one catalog instead of holding unrelated copies. A refresh reads `/api/facilities`, decodes records, and notifies listeners when the catalog or sync status changes. While the app is active and has listeners, it polls approximately every 10 seconds; it stops polling when no view needs it or the app is inactive. Saves/deletes send the administrator bearer token and record version to the backend. Version checks let the server reject conflicting edits. If a refresh fails, the repository distinguishes previously loaded data from sample fallback data. This keeps map, search, details, and management consistent without requiring each screen to implement its own storage logic.

## Verification and limits

The checklist review on October 11 ran 22 backend tests successfully and found no configured private credentials in the existing web build. The real PostgreSQL integration suite did not run because Docker's engine was stopped. The [security and privacy record](docs/06-security-and-privacy.md) keeps that check and the final-video review incomplete and records a privileged key in ignored local configuration. This log does not claim verified production deployment, full accessibility compliance, or an exact manual/AI code percentage.
