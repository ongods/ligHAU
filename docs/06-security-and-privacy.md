# Security and privacy

**Project:** ligHAU · **Last checked:** October 11, 2026

The [proposal](01-proposal.md) records plans for shared campus data, administrator access, Supabase persistence, and git-ignored configuration. This document describes protections found in the repository and verified by local tests, file/history scans, and review of existing images. Live host configuration, live database permissions, and provider retention settings remain outside this local review.

## What this app stores

| Data | Where it lives | Who can see it |
| --- | --- | --- |
| Building/facility names, locations, coordinates, descriptions, hours, floors, and services | Bundled seed data and shared backend SQLite/PostgreSQL catalog | Public visitors through the read API; only authenticated administrators may modify it. |
| Campus map geometry | Bundled `assets/data/hau_osm.json` | Public; included in the web build. |
| Administrator username, role, disabled flag, salted password hash | Backend account table | Backend/database operators; no public account-list API. Plaintext passwords are not stored. |
| Administrator session digest, account name, and expiry | Backend session table; bearer token held only in browser memory | Backend and the signed-in administrator's browser. The server stores a SHA-256 digest rather than the bearer token. |
| Chat questions, replies, and recent history | Flutter screen memory; current question and recent history sent through Node to Gemini | Current browser session, backend during processing, and AI provider. Application databases do not store chat transcripts. |
| Catalog cache and selected place | Flutter memory | Current browser session; no persistent visitor preference store is implemented. |
| Rate-limit counters | Backend database, keyed using hashes of client identifiers/usernames | Backend operators. Hashing is pseudonymization, not guaranteed anonymity. |
| Catalog/admin audit events | Backend database: actor, time, operation, facility identifier, before/after records | Backend/database operators; not public. |
| Provider request/token counts and usage summaries | Backend database | Authorized administrators through API usage; backend/database operators. |

The app does not request GPS access, track the visitor's live position, or maintain student profiles. The ordinary welcome sign-in form only checks nonempty fields and opens the public map; it is **not student authentication** and does not send those fields to an authentication service. Administrator login is a separate server-verified flow.

### External processing and retention

Gemini receives the question, up to 12 previous conversation messages, and campus catalog context. MapTiler receives browser requests for styles/tiles, including the public map key and requested map area. Those services and hosting infrastructure may process network metadata such as IP addresses. Provider and hosting retention settings were not reviewed here, so the lack of application transcript storage is not a promise that no external logs or records exist.

Administrator sessions expire after two hours by default. Logout clears the browser token immediately and attempts server revocation; if that request fails, the server session can remain usable until expiry. Provider event records older than 24 hours are pruned when new events start, daily usage buckets retain up to 90 recorded calendar days, and lifetime usage totals remain. The repository does not define an automatic deletion schedule for accounts, catalog audit history, or backups. No self-service data export/deletion feature is implemented.

## Secrets

| Configuration name | Classification | Where it belongs |
| --- | --- | --- |
| `GEMINI_API_KEY` | Private AI provider credential | Local git-ignored `.env`; production backend host secret. Never a Flutter asset or dart define. |
| `MAPTILER_SERVICE_TOKEN` | Private provider-management/usage credential | Backend environment only. Distinct from the browser map key. |
| `DATABASE_URL` | Private runtime connection string | Backend environment only, using the restricted application role. |
| `DATABASE_MIGRATION_URL` | Private schema-owner connection string | Migration/provisioning tooling only; not the public app or runtime connection. |
| `SUPABASE_SECRET_KEY` | Privileged Supabase API credential found in local configuration | Present in ignored `.env`; not used by the current Flutter/Node source. Keep out of source control and browser assets. |
| `MAPTILER_KEY` | Browser-visible map delivery key | Local generated map configuration or Flutter dart define; GitHub Actions repository secret supplies it during web builds. It remains visible to visitors after compilation. |
| `CHAT_API_BASE_URL` | Public backend origin | Flutter dart define; GitHub Actions repository variable. Must contain no credentials. |

Map style identifiers and the backend URL are also public configuration. The MapTiler browser key should be restricted to intended frontend origins and quotas; its visibility does not justify exposing the private service token. The current Flutter app does not need a Supabase browser key or a `service_role` key.

The ignored local `.env` contains `SUPABASE_SECRET_KEY` in the `sb_secret_...` format. Supabase documents this as an elevated key that resolves to `service_role`; see [API key types](https://supabase.com/docs/guides/getting-started/api-keys). Its presence in local ignored configuration does not establish a public leak, but the checklist's strict “anywhere” statement is left unchecked. No removal or rotation was performed.

[.gitignore](../.gitignore) excludes `.env`/`.env.*` except [.env.example](../.env.example), generated `assets/config/map.local.json`, backend `.local` storage, build/tool output, service-account filenames, and signing keystores. Ignore rules do not remove previously committed secrets from Git history.

The [web deployment workflow](../.github/workflows/deploy-web.yml) injects only `MAPTILER_KEY` and `CHAT_API_BASE_URL` into the static build. Database/provider secrets must be set on the separately hosted backend. [check-release-secrets.mjs](../tools/check-release-secrets.mjs) can check a generated web build against configured private credentials; it does not replace a repository-history scan.

## What protects the data on the service side

### Authentication and API authorization

The server verifies administrator passwords with salted `scrypt` hashes (`N=32768`, `r=8`, `p=3`) and timing-safe comparison. Unknown usernames follow a dummy password-derivation path. Account tooling requires passwords of 15–128 characters; account creation is an operator action, not a public registration endpoint.

Successful login returns a random 32-byte bearer token with a two-hour default lifetime. Protected requests recheck its digest, expiry, administrator role, and account disabled state on the server. The Flutter token is kept in memory, not cookies or local storage. Server authorization remains necessary even if someone bypasses the UI.

Login throttling limits attempts to 10 per client identifier and 5 per username per 15-minute window. Chat has client/global limits and provider-budget controls. Public facility reads are intentional; catalog writes and API usage endpoints require administrator authorization. CORS origin checks constrain browser requests but do not authenticate callers or make a public endpoint private.

Request size and schema validation bound chat and catalog inputs. Facility validation checks names, coordinate pairs/ranges, floor values, and duplicate names. Queries are parameterized. Catalog writes use transactions, version checks, and audit records so conflicting changes are rejected rather than silently overwritten. Provider errors are sanitized before returning them to the browser.

Production requires HTTPS. Forwarded client/protocol information is accepted only under configured trusted-proxy or platform rules. Correct production origins, proxy settings, TLS, and host access controls still need deployment verification. Local development uses the existing frontend on port **53923** and backend on **8787**.

### SQLite and PostgreSQL/Supabase access

SQLite is server-side storage, not a publicly served asset. Its files and backups must remain outside the web build and under appropriate host filesystem permissions. The code attempts restrictive file permissions; Windows ACLs and production volume permissions need independent verification.

The PostgreSQL option uses the [repository migration](../supabase/migrations/20261009150153_lighau_postgres.sql):

- Data lives in the private `lighau` schema. Schema/table/sequence access is revoked from `PUBLIC` and, when present, Supabase `anon`, `authenticated`, and `service_role` roles.
- The runtime role `lighau_backend` is created with `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOREPLICATION`, and `NOBYPASSRLS`. The server rejects superuser/RLS-bypass runtime roles.
- RLS is enabled for application tables. `backend_access` policies permit rows only to `lighau_backend`; they are not unrestricted browser policies. Administrator write authorization is enforced by Node before using that trusted database role.
- Audit access for the runtime role is limited to `SELECT` and `INSERT`, with matching policies. It receives no audit `UPDATE` or `DELETE` grant.
- Remote PostgreSQL connections verify TLS certificates. Disabling database TLS is limited to non-production loopback development.

The `USING (true)` / `WITH CHECK (true)` backend policies intentionally allow that server role to operate across the shared catalog; they do not implement per-student ownership rules. The app does not use Supabase Auth. Schema grants and RLS policies serve different purposes, as described in the [Supabase RLS documentation](https://supabase.com/docs/guides/database/postgres/row-level-security). Keeping the private schema out of exposed Data API schemas is an additional host configuration check; see [custom schema documentation](https://supabase.com/docs/guides/api/using-custom-schemas).

### Existing verification coverage

[hardening.test.mjs](../server/hardening.test.mjs), [chat-server.test.mjs](../server/chat-server.test.mjs), and [facility-store.test.mjs](../server/facility-store.test.mjs) cover authorization, session behavior, throttling, input rejection, safe errors, persistence, and auditing. [postgres.test.mjs](../server/postgres.test.mjs) and the [isolated Postgres runner](../tools/test-postgres.mjs) provide database migration/permission checks. The deployment workflow runs backend, Flutter, stress, and isolated PostgreSQL checks before building.

The local checklist review ran `node --test server/chat-server.test.mjs server/hardening.test.mjs server/facility-store.test.mjs server/postgres.test.mjs`: **22 tests passed, with no failures**. The real PostgreSQL integration suite was skipped because no disposable test database was configured. Docker's engine is stopped, so the isolated runner could not be used. The passing PostgreSQL configuration test does not prove the RLS policies work on a live database.

## Checklist

- [x] `.env` (or `env.json`) is in `.gitignore`, and `.env.example` is committed
- [x] `git log -p | grep -i "api_key\|secret\|password\|token"` finds nothing real
- [ ] No service account file, keystore or `service_role` key anywhere in the repo
- [ ] Security rules or RLS policies written and tested, not left open
- [ ] No real personal data in sample data, screenshots or the video
- [x] No course or university credentials anywhere
- [x] Anyone whose data appears in a test was asked first

If you found and revoked a key while doing this, say so here. Catching it is the
right outcome, not an embarrassment.

### Verification notes

The original checklist wording is preserved; only verified checkbox states were changed.

1. **Local configuration:** `git check-ignore` confirms `.env` and `env.json` are ignored; `git ls-files` confirms `.env.example` is committed. The template contains placeholders and environment references, not real private values.
2. **History and secrets:** scanned 128 tracked/non-ignored files, 228 historical blobs, and commit messages across the repository's refs; the history contains 394 lines matching the checklist keywords. Compared the four configured private credential values and checked common API-key, private-key, privileged JWT, credentialed-URL, and literal-secret patterns. Matches were synthetic test values, UI labels, and `env(...)` references; no real private credential was found. This is a scoped pattern/value scan, not a guarantee against every possible encoded or unknown secret.
3. **Privileged files/keys:** no service-account payload, private signing key/keystore, or privileged Supabase credential was found in tracked/non-ignored files or history. However, `SUPABASE_SECRET_KEY` exists in ignored local `.env`, so this strict item remains unchecked. The existing web build passed `node tools/check-release-secrets.mjs` for its four configured credentials, plus a separate exact-value check including `SUPABASE_SECRET_KEY`: 41 files checked against five private values, with no leaks. These checks apply to the existing build, not a future release artifact.
4. **RLS verification pending:** policies and restricted grants exist in the migration, and local API authorization tests passed. Keep this item unchecked until the isolated real PostgreSQL permission/RLS suite passes; production permissions also need separate verification.
5. **Video review pending:** seed data describes campus places, reviewed screenshots/mockups contain no real user records, and pictured usernames are placeholders. No final demo video is present or linked in `05-demo-video.md`, so the complete sample/screenshots/video item remains unchecked.
6. **University credentials:** no course or university login credentials were found in the reviewed app, configuration template, tests, or history. Test administrator passwords belong to disposable test fixtures, not university accounts.
7. **Consent is not applicable to the current tests:** tests use synthetic accounts such as `test-admin` and mocked tokens, with no real participant data. The checked item records that no consent-dependent test data is currently used; it does not claim that consent was obtained from real people. Recheck if real participant data is introduced.

No credential was revoked or rotated during this review.
