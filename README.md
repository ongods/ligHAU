<!--
  This is your project's front page. Replace every placeholder below.
  It is the first thing your instructor and any future employer will read, and
  the live link in it is how your project gets opened for grading.

  New here? Read START-HERE.md first. Delete this comment when you are done.
-->

# App Name

> One sentence: what this app does, and who it is for.

**Live demo:** https://YOURUSERNAME.github.io/YOUR-REPO/ <!-- GitHub Pages is set up already; replace if you host elsewhere -->
**Demo video:** `docs/demo.mp4` (link it here once it exists)
**Course:** Applications Development and Emerging Technologies (6ADET), Holy Angel University
**Author:** Your Name

This repository lives in the author's own GitHub account and is public on
purpose. There is no `student.json` here and there should not be one: see
`docs/06-security-and-privacy.md` for what a public repo means for secrets and
personal data.

---

## Screenshots

Put two or three real screenshots at phone size in `docs/assets/`, then replace
this paragraph with them:

```markdown
| Home | Detail | Add |
| --- | --- | --- |
| ![Home](docs/assets/screen-home.png) | ![Detail](docs/assets/screen-detail.png) | ![Add](docs/assets/screen-add.png) |
```

A repo without screenshots reads as abandoned, whatever the code says.

## What it does

Three to five bullets. What can a user actually do?

- ...
- ...
- ...

## Built with

| | |
| --- | --- |
| Framework | Flutter (Dart) |
| State | `setState` / provider / riverpod (say which) |
| Storage | shared_preferences / Hive / Drift / Firebase / Supabase / other |
| Other packages | list the ones that matter, with a word on why |

## Running it yourself

```bash
flutter pub get
cp .env.example .env      # only if your app needs keys, see below
powershell -NoProfile -ExecutionPolicy Bypass -File tools/sync-map-config.ps1
flutter run -d chrome --web-port 53923
```

Chrome opens automatically. Requires Flutter (run `flutter --version` and
put yours here).

On Windows, `./tools/run-web.ps1` starts Chrome with `.env` automatically.
The launcher and VS Code Chrome launch configuration use app port `53923` and
the backend uses port `8787`. The launcher reuses a healthy backend and stops
if the app port is already occupied, without starting another Flutter server.
For app updates, press `r` (hot reload) or `R` (hot restart) in the existing
Flutter terminal. Quit with `q` before relaunching on the same port.
Always include `--web-port 53923` when running Flutter directly; the plain
`flutter run -d chrome` command otherwise chooses a random port.

### Environment variables

This project reads its configuration from a `.env` file that is **not** in the
repository. Copy `.env.example`, fill in your own values, and never commit the
result.

| Variable | What it is | Where to get one |
| --- | --- | --- |
| `EXAMPLE_API_KEY` | ... | ... |
| `MAPTILER_KEY` | Browser map API key; required for the campus map | MapTiler Cloud; restrict allowed origins to your app |
| `MAPTILER_STYLE_ID` | Map style identifier (defaults to `streets-v4`) | MapTiler Cloud |

For `flutter run -d chrome --web-port 53923`, the setup command creates a git-ignored
`assets/config/map.local.json` containing only the browser map key and style ID.
Run the setup command again after changing these values, then restart Flutter.
The Windows launcher updates this file automatically. For a local web build, use
`flutter build web`. Never pass the entire `.env` file to Flutter: the Gemini key
is backend-only. For GitHub Pages, configure the
`MAPTILER_KEY` repository secret before deploying.

### Gemini campus chatbot

Requires Node.js 22.14 or newer for the built-in SQLite database. Put `GEMINI_API_KEY` in `.env`, then start the
backend in a separate terminal from the project root:

```powershell
node --env-file=.env server/chat-server.mjs
```

Keep it running while you use `flutter run -d chrome --web-port 53923`. It listens on
`127.0.0.1:8787`. The Windows launcher can start this backend automatically.
The backend defaults to `gemini-3.5-flash-lite`; override with `GEMINI_MODEL`
in `.env`. Keep `CHAT_PORT=8787` for local development. A hosted frontend must
use the backend's public HTTPS origin through `CHAT_API_BASE_URL` or a same-origin
`/api/*` proxy; hosting is not configured yet.

Answers use the shared campus catalog, initially seeded from the 22 facility records in `lib/data/mock_data.dart`, and
support follow-up questions. Facility buttons open the matching details or
return to a verified map location. Hours are explicitly unverified prototype
data; unknown floor counts and missing locations are not invented.

The Dart facility records seed the catalog on its first start. After that, admin
changes update the saved catalog used by the chatbot. Tests: `node --test server/*.test.mjs` and
`flutter test`. The six most recent question/answer pairs are sent to Gemini;
conversations stay in memory and are not written to disk.

Static GitHub Pages cannot run the backend. A published chatbot requires a
hosted backend, authentication and abuse controls, and `CHAT_API_BASE_URL`
pointing at it. This implementation is a localhost prototype.

## Privacy and secrets

Admin credentials are verified by the backend; there is no built-in demo account.
Create an individual admin from an interactive terminal with
`node --env-file=.env server/manage-admin.mjs create YOUR_USERNAME`.
The password prompt is hidden and requires 15–128 characters. Passwords use
salted scrypt hashes. Sessions expire after two hours and are revoked on logout,
password reset, or account disable. Browser session tokens stay in memory.
Production mode requires HTTPS and an explicitly configured persistent database.

### Local admin accounts

Run these commands from the project root in an interactive terminal:

```powershell
node --env-file=.env server/manage-admin.mjs create YOUR_USERNAME
node --env-file=.env server/manage-admin.mjs list
node --env-file=.env server/manage-admin.mjs reset YOUR_USERNAME
node --env-file=.env server/manage-admin.mjs disable YOUR_USERNAME
```

Usernames contain 3–100 characters; passwords contain 15–128 characters and
are entered twice with typing hidden. No admin is created by default, and there
is no public registration endpoint. Login is throttled by account and client IP.
Resetting or disabling an account revokes its sessions. Offline logout clears
the browser token immediately, with backend revocation attempted when reachable.
Protect operator access to the database and its backups.

### Shared campus catalog

Admin Add, Edit, and Delete now save through the local backend. The campus map,
directory, details pages, and Gemini chatbot use the same catalog. Saved records
live in git-ignored `server/.local/campus.sqlite` and survive app/backend
restarts. Existing buildings keep their original map geometry when renamed;
the Add/Edit form accepts optional latitude and longitude in decimal degrees.
New buildings with both coordinates have selectable map pins; existing verified
footprints remain intact. Clear both coordinates to restore an original mapped
location, if one exists.
Keep `node --env-file=.env server/chat-server.mjs` running while managing data.
The app displays a save error if the backend is unavailable. Earlier edits made
by the session-only dashboard must be entered and saved again. For a main app
already open in another browser tab, catalog polling loads changes every 10
seconds while active and refreshes on returning to the app. Failed refreshes show
a visible notice identifying sample or previously loaded data, with a Retry button.
Record versions reject conflicting edits/deletions; changes and their admin actor
are recorded together in the database audit trail. Existing JSON catalog and usage
files are imported once when the database is first initialized, then retained as
legacy copies rather than updated. Back up the SQLite database for recovery.
HTTP 412 rejects a stale record version; HTTP 428 rejects a missing version.
The app refreshes after a conflict so the admin can reopen and review the edit.

### Backend storage and recovery

`CAMPUS_DB_PATH` selects the database; localhost defaults to
`server/.local/campus.sqlite`. SQLite transactions, WAL journaling, foreign keys
and full synchronous commits are enabled. Run one backend on a persistent local
disk/volume, keep its WAL files on that disk, and schedule protected off-machine
backups. A deployment across multiple hosts requires a shared database service;
do not put this SQLite database on a network filesystem.

Create a consistent snapshot while the backend is running, using a new filename
each time:

```powershell
node --env-file=.env server/backup.mjs backup server/.local/backups/campus-2026-10-08.sqlite
```

Restore into a new database file:

```powershell
node --env-file=.env server/backup.mjs restore server/.local/backups/campus-2026-10-08.sqlite server/.local/restored.sqlite
```

The commands verify integrity and refuse to overwrite existing destinations.
Restore revokes saved sessions and provider leases. Stop the backend, set
`CAMPUS_DB_PATH` in `.env` to the restored file, restart on port 8787, then
check facility records, usage totals, admin login and an edit. Keep the original
database until recovery is verified. Backups contain password hashes and must
be restricted to operators.

Production requires `NODE_ENV=production`, an explicit persistent
`CAMPUS_DB_PATH`, HTTPS and `CHAT_ALLOWED_ORIGINS` matching the frontend origin.
The backend rejects plaintext production requests and does not trust proxy
headers by default; a TLS/reverse-proxy setup still needs to be configured.

### Admin API monitoring

Open the **API usage & quota** button under Overview in the admin dashboard. The chat
backend independently verifies the admin session and role before returning
metrics. Gemini counts begin when this monitoring version is first started;
previous calls and calls made by other apps are not included. Counts and reported
token totals are stored in git-ignored `server/.local/campus.sqlite` across
restarts. Usage records contain no chat messages or API keys. Request limits and
provider minute counters are shared through SQLite and survive restart; daily counts use
Pacific time, matching Gemini's daily reset. Reported total tokens can include
thinking tokens; responses without usage metadata are marked incomplete.

Optional `.env` values `GEMINI_QUOTA_RPM`, `GEMINI_QUOTA_TPM`, and
`GEMINI_QUOTA_RPD` display reference quotas copied from the current model's
[AI Studio limits](https://ai.google.dev/gemini-api/docs/rate-limits). Blank
values show **Quota unavailable**, and remaining Gemini quota is an app-only
estimate. These values do not enforce or change Google's project-wide quotas.

### Chatbot free-tier policy

Conservative defaults are 5 questions per client IP per 10 minutes, 30 globally
per 10 minutes, 100 per Pacific calendar day, 5 per minute, and 2 provider calls
running at once. A bounded queue holds at most 4 distinct waiting client IPs per
process and waits at most 5 seconds; responses are capped at 768 output tokens.
Client disconnects cancel queued/provider work. Provider quota failures trigger
a shared 60-second cooldown and Retry-After guidance, without automatic provider
retries. See `.env.example` for request-limit settings. Known RPM/RPD provider
quotas can lower app caps. These controls do not enable billing or change provider quotas.

`CHAT_CLIENT_LIMIT`, `CHAT_GLOBAL_LIMIT`, `CHAT_DAILY_LIMIT` and `CHAT_RPM_LIMIT`
configure backend limits. Shared-IP limits and temporary unavailability when
free-tier limits are reached are accepted for this project; no paid subscription
or increased capacity is required for the current scope. Reassess that policy
if traffic or availability requirements change. Admin monitoring shows active
and queued questions, provider failures and recent p95 backend latency. Usage
totals persist, while process HTTP metrics reset when the backend restarts.

### MapTiler usage

To show MapTiler account usage in the app, add `MAPTILER_SERVICE_TOKEN` from
MapTiler Cloud's **Credentials** page to `.env`. This private token is distinct
from the browser map key and stays on the backend. The backend reads the
[Analytics API](https://docs.maptiler.com/cloud/admin-api/analytics/) and caches
the result for 60 seconds. Optional `MAPTILER_QUOTA_REQUESTS` and
`MAPTILER_QUOTA_SESSIONS` display the account plan's billing-period allowances.
Without a service token, the screen links to the provider dashboard. Restart
`node --env-file=.env server/chat-server.mjs` after changing these settings.

Required section. Two or three honest sentences:

- What personal data this app stores, if any, and where it goes.
- Where the secrets live (`.env` locally, repository secrets in the deploy
  workflow) and what protects the data on the service side (Firestore rules,
  Supabase RLS, or "nothing leaves the device").
- Confirm that all sample data, screenshots and the video contain **no real
  personal information**.

## Verification before deployment

Run the required local checks from the project root:

```powershell
flutter analyze
flutter test
node --test server/*.test.mjs
node server/stress-test.mjs --soak-seconds=300
flutter build web --release
node tools/check-release-secrets.mjs
```

CI gates publication on analysis, Flutter/backend tests and an isolated
30-second stress soak. The local stress test uses a temporary SQLite database
and simulated Gemini responses, leaving live records and provider quota alone.
It checks expected statuses, catalog p95 below one second, persistence and
provider concurrency at most two. The latest retained evidence is
[stress-results.json](docs/stress-results.json); it does not prove hosted capacity.

Once HTTPS staging exists, set `SMOKE_APP_URL`, `SMOKE_API_URL`,
`SMOKE_ADMIN_USERNAME` and `SMOKE_ADMIN_PASSWORD` in a private operator environment:

```powershell
node tools/staging-smoke.mjs --allow-staging-writes
node tools/staging-soak.mjs
```

The smoke test creates, edits and deletes one temporary staging record, checking
authentication, catalog and usage. Optional `--one-chat` makes one real Gemini
request; `--browser` checks map tiles and rendering with Playwright and Chrome
installed on the runner. The staging soak reads the public catalog for five
minutes at concurrency 10; acceptance is zero failed reads and p95 below one
second. `SOAK_SECONDS` and `SOAK_CONCURRENCY` can change its traffic target.
Verify hosted restart persistence, backup/restore, map rendering and chatbot
connectivity separately before public release. Local/browser/staging diagnostic
reports are generated when those tools run and are git-ignored.
See [deployment readiness](docs/deployment-readiness.md) for the current assessment.

## Project documentation

| Document | |
| --- | --- |
| [Proposal](docs/01-proposal.md) | the problem, the users, the scope |
| [Mockup and wireframes](docs/02-mockup.md) | what it looks like, and the screen flow |
| [Design system](docs/03-design-system.md) | colors, type, spacing, components |
| [Weekly reports](docs/04-weekly-reports.md) | what happened each week |
| [Demo video](docs/05-demo-video.md) | the recording and what it shows |
| [Start here](START-HERE.md) | how this repo works (delete once you have read it) |
| [Security and privacy](docs/06-security-and-privacy.md) | the checklist, filled in |

## Status and what is next

Be honest. What works, what is half done, what you would build next. An honest
"known issues" section reads better than a claim the reader disproves in thirty
seconds.

## Credits

- Packages: see `pubspec.yaml`
- Assets, icons, 3D models, sounds: name the author and the licence for each
- People who helped, and how

## AI use

If you used AI while building this, say so here. Honest disclosure is the
standard in this course and increasingly outside it, and reporting heavy use
accurately costs you nothing.

This section is the last 10 points of the finals badge, and it wants three
things:

![Built with AI assistance](https://img.shields.io/badge/built%20with-AI%20assistance-0b5fff)

- the badge above, or one you like better
- a line naming which assistant you used and how much of the work it touched
- a link to [AI-USAGE.md](AI-USAGE.md), where the full account lives

Keep the detail in `AI-USAGE.md` rather than here. This section is the summary a
visitor reads; that file is the record the badge is graded from.

## Licence

MIT, see [LICENSE](LICENSE). Change it if you want different terms.
