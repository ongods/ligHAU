# Proposal: ligHAU

**Author:** Ong, Sean Keiffer S. · **Section:** CS-302 · **Course:** Computer Science

**Institution:** Holy Angel University

**Submitted proposal:** September 20, 2026 · **Documentation updated:** October 11, 2026

Source: *Final Project Proposal (Revised)*, pages 1–9. The submitted scope is summarized below; implementation notes describe the repository as of the documentation update.

## The problem, in one sentence

Students and visitors need an accessible, up-to-date guide to locate classrooms, offices, restrooms, parking, and dining facilities across the Holy Angel University campus.

The proposal grew from the author's difficulty finding locations during freshman enrollment. Physical campus maps are available only in certain places and provide limited facility detail. ligHAU brings the map and directory into a browser, with a conversational assistant for campus questions.

## Who it is for

The submitted proposal identifies **administrators and maintainers** as the primary audience responsible for keeping campus information accurate. **Students, visitors, and other campus stakeholders** use that information to find places and understand their purpose.

Public visitors can browse without an account. Administrators use a separate, authenticated management area. The ordinary sign-in form remains a prototype entry flow: it checks that fields are filled and opens the public map; it does not authenticate student accounts.

## Core features

| Submitted MVP feature | Purpose and original effort estimate | Current implementation |
| --- | --- | --- |
| Interactive 2D campus map | Pan, zoom, and select building markers; 5 hours | MapLibre renders MapTiler tiles and campus outlines derived from OpenStreetMap. Building selection connects to directory details. |
| Building information | Show descriptions and available rooms/services in a pane or bottom sheet; 3 hours | A dedicated details page shows category, location, description, hours, floor count when available, and listed facilities. |
| Search and filters | Find buildings or facilities by keyword and category; 3–5 hours | Inline map search, category chips, a desktop directory, and a mobile Browse sheet. A separate search screen also exists. |
| Campus chatbot | Ask questions, display responses and conversation history; 5 hours | A Node backend calls Gemini with catalog context. Replies can include up to four recognized building matches, each with details and map actions. |
| Administrator CRUD | Add, edit, and delete shared campus information; 5 hours | Server-authenticated facility management, validated editor forms, version conflict detection, audit records, and API usage monitoring. |

The original total was **21–23 working hours**, an estimate rather than a record of actual development time. The PDFs also planned a Supabase connection spike by September 22 and a clickable map spike by September 25; those dates describe the submitted plan, not verified completion dates.

The main public flow is welcome → guest/prototype sign-in → campus map → directory, details, or assistant. Administration follows welcome → administrator sign-in → management dashboard. See the [mockup and screen flow](02-mockup.md).

## Out of scope, and why

- **3D campus visualization and custom CAD models:** the revised proposal moved these to stretch goals to keep the MVP achievable. The current map does not implement building extrusion, a 2D/3D toggle, or custom 3D models.
- **Community ratings and reviews:** require user authentication, moderation, and additional persistent data; not implemented.
- **GPS navigation and turn-by-turn directions:** were not required by the proposal and are not implemented. Map actions select or focus a known building; they do not calculate a route from the visitor's position.
- **Student account management, password recovery, and personal preferences:** are not completed features. The public directory does not require a student account.
- **Dedicated room tables and chatbot knowledge editing:** proposed as part of the data model, but the current editor manages facility records and their service lists. There is no separate room editor or chatbot training dashboard.

## Data the app remembers, and where it is saved

The submitted plan selected Supabase for roughly **100–300 shared campus records**. Proposed tables were `buildings`, `rooms`, `facilities`, `profiles`, and `chatbot_knowledge`, with Supabase Auth for administrator profiles. Personal preferences were not part of the plan.

The implementation now uses a **Node API** between Flutter and storage. Local development uses SQLite at `server/.local/campus.sqlite`; the backend also supports PostgreSQL, including a Supabase-hosted database, through a restricted server-side database role. Flutter does not connect directly through `supabase_flutter` or use Supabase Auth.

| Current data | Storage and behavior |
| --- | --- |
| Campus catalog | Shared SQLite/PostgreSQL facility records: identifier, version, source name, optional coordinates, name, category, location, description, hours, optional floors, and a list of services. |
| Map geometry | Bundled campus OpenStreetMap data in `assets/data/hau_osm.json`. |
| Administrator access | Backend account records contain salted password hashes and roles; session records contain token digests and expiration times. The browser keeps its bearer token in memory. |
| Catalog cache | In-memory Flutter repository; checks for shared changes approximately every 10 seconds while active and observed. Sample/stale-data notices explain fallback states. |
| Chat conversation | In-memory screen history. A request sends the current question and up to 12 previous messages to the backend and Gemini. Application storage does not save chat transcripts. |
| Operational records | Backend audit events, rate-limit counters, and provider usage records. See [security and privacy](06-security-and-privacy.md) for access and retention details. |

The bundled catalog contains **22 facilities**, rather than the proposed 100–300 records. Seventeen match campus map outlines; five lack verified map positions and remain searchable with a missing-location state. Hours in the seed data are prototype values and need campus confirmation. A missing floor count is kept unknown rather than invented. Data provenance and coverage are documented in [campus map data](campus-map-data.md).

## Risks

| Risk | Response and remaining limitation |
| --- | --- |
| Inaccurate campus information | Keep source names, distinguish missing coordinates and unknown floor counts, and allow administrator corrections. Operating hours, service lists, and unmatched locations still need campus verification. |
| Unauthorized catalog changes | Authenticate administrators on the server, validate writes, use expiring sessions, and record changes. Public browsing is intentionally read-only. |
| Concurrent edits or stale information | Check record versions when saving and poll for shared changes. Polling is not instant synchronization, and offline views may use fallback data. |
| Map or AI provider outages and quotas | Show loading, failure, and retry states; directory information remains usable independently of successful AI responses. Tile display still depends on valid MapTiler configuration and network access. |
| Misleading chatbot answers | Ground requests in the current catalog and link recognized matches to actual records. AI text can still be incorrect; the catalog also needs verification. |
| Browser and small-screen layout | Use shared responsive components, scrolling, wrapping text, and separate map controls. Layout and interaction tests cover narrow screens and enlarged text. |
| Credential exposure or deployment mismatch | Keep provider credentials on the backend, expose only browser-safe configuration, and use the documented release checks. Production host settings and secret history require a separate deployment review. |

## Changes since the last version

**September 20, 2026 — revised proposal:** moved 3D mapping to stretch scope, specified administrator CRUD, chose shared Supabase persistence, and mapped the MVP to Flutter widgets and course activities.

**October 4, 2026 — implementation update:** introduced bundled Manrope typography, shared branding, responsive directory navigation, and verified campus map geometry. The implementation uses MapLibre rather than the proposed `flutter_map` stack.

**October 11, 2026 — current documentation:** records the Node/SQLite/PostgreSQL architecture and authenticated administrator workflow. The welcome design now incorporates the supplied campus photograph; chat responses distinguish multiple building matches; map and chat panels have consistent visible borders with controls arranged outside the map canvas. Planned features are explicitly separated from implemented behavior.
