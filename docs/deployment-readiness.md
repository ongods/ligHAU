# Deployment readiness assessment

Assessment date: 8 October 2026 (Asia/Singapore). Decision: **proceed with deployment configuration and a controlled staging environment; do not release publicly yet**. Local checks support that next step. Browser flow verification is incomplete, and hosted HTTPS, persistence, domain restrictions and chatbot connectivity still need validation. The project owner has accepted the existing free-tier chatbot controls and service limits; item 4 is resolved for the current project scope. No hosting configuration or deployment was performed during this assessment.

## Executed checks

| Check | Result |
| --- | --- |
| `flutter build web --release` | Passed; output in `build/web` |
| `flutter analyze` | Passed; no issues |
| `flutter test` | Passed; 59 tests |
| Backend unit/integration suites | Passed; 21 tests |
| Isolated stress test and five-minute soak | Passed; 301,597 HTTP requests, no unexpected response statuses or client timeouts |
| Release secret scan | Passed after repository cleanup; 40 files scanned, neither configured Gemini key nor MapTiler service token found |
| Existing app/backend HTTP smoke checks | Passed on ports 53923/8787; live catalog burst of 500 reads at concurrency 20, final p95 59 ms; protected usage returned 401 to an anonymous caller |
| One real Gemini request | Passed in about 1.4 seconds; a short answer and one matching facility were returned. No additional real chat requests were made |
| MapTiler HTTP checks | Passed: style, source metadata and campus vector tile returned 200; tile payload 111,561 bytes at the source's supported zoom 15 |
| Existing Chrome DOM inspection | Passed: Flutter view loaded; current screen had no map canvas, so this is not proof of map rendering |
| Interactive browser guest/map/zoom/mobile/exit flow | Incomplete; initial attempt did not complete, and the Chrome debugging endpoint subsequently became unavailable. No browser flow pass is claimed |

Repository cleanup preserved the submission Markdown files and screenshots. Backend administration and recovery instructions were consolidated into the main README; the separate operations document and regenerable smoke-result files were removed. The unused floating chatbot widget, unused logo asset and redundant screenshot-folder placeholder were removed. Four unused direct dependencies were removed, reducing the lockfile from 104 to 50 packages; Cupertino icons were retained because the release build references their font. Analysis, all 59 Flutter tests, all 21 backend tests and a fresh release build passed. A stale generated plugin registration was cleared and regenerated during build verification.

The stress test creates its own ephemeral test server and temporary SQLite database, then removes them. It does not alter live building records or spend provider quota. The existing development servers stayed on ports 53923 and 8787. The separate live smoke check verified that all 22 campus records were unchanged. Raw stress measurements and environment are retained in [stress-results.json](stress-results.json). Other diagnostic results are summarized above; their regenerable JSON reports are not retained in the repository.

Reproduce the five-minute load test with `node server/stress-test.mjs --soak-seconds=300`. Scan a fresh release build with `node tools/check-release-secrets.mjs`. Run `node tools/local-readiness-smoke.mjs` against existing local servers; `--one-chat` explicitly adds one real Gemini call. The optional `--browser-port=PORT` reads an already-running Chrome debugging endpoint. The final local smoke check was a map diagnostic rerun without another chat call; the single real answer is recorded in the executed checks above. Diagnostic JSON reports are git-ignored.

## Load results

| Scenario | Load | Result | p95 latency |
| --- | --- | --- | --- |
| Catalog reads | 2,000 requests, concurrency 50 | All 200; about 974 requests/second | 92.5 ms |
| Persistent creates | 200 requests, concurrency 10 | All 200; all records present after reloading disk storage | 77.1 ms |
| Mixed catalog updates/deletes | 400 writes plus 400 reads, concurrency 20 | All 200; final persisted record count correct | 267.5 ms per write/read pair |
| Unauthenticated writes | 100 requests, concurrency 20 | All rejected with 401 | 28.1 ms |
| Chat burst | 100 concurrent requests; simulated 250 ms provider | 2 successes, 98 expected busy responses (429); maximum provider concurrency 2 | 337 ms across successes and rejections |
| Remaining chat allowance | 28 sequential requests | All successful; 30 simulated provider calls total | 277.1 ms |
| Exhausted chat allowance | 100 requests, concurrency 20 | All rejected with 429; backend health remained available | 114.9 ms |
| Five-minute catalog soak | 298,267 requests, concurrency 10 | All 200; about 994 requests/second | 19 ms |

The mixed scenario latency includes its follow-up read. Chat burst percentiles mostly measure rejection speed, not answer speed. Stress-only client/RPM overrides and a zero queue isolate global/concurrency limits; production defaults and bounded queue behavior are tested separately. Simulated provider load does not prove Gemini capacity. The separate single real answer proves current connectivity, not sustained latency or model correctness. Map HTTP success does not prove browser rendering. This is a single-process Windows localhost test with a catalog growing from 22 to 222 records; it does not establish WAN, multi-instance or hosting-provider capacity. Peak observed process RSS was 178.4 MB and event-loop p99 delay was 72.2 ms; a five-minute measurement does not establish long-term memory stability.

The map probe initially selected an empty overlay source and then requested a zoom above the selected source's advertised maximum, producing false failures. The corrected probe selects a tile-bearing source and honors its maximum zoom. An intervening network connection attempt also failed. The final HTTP check passed; browser rendering remains unverified. The optional browser script is prepared but its complete guest flow has not passed locally. Repeat it with an available Chrome debugging endpoint using `node tools/local-browser-smoke.mjs --browser-port=PORT`, or use the prepared staging Playwright smoke test after hosting is configured.

## Required before public deployment

1. **Authentication implemented locally.** Public demo credentials have been removed. Individual admins are created through a local hidden-password command; salted scrypt hashes, server-verified admin roles, hashed opaque sessions, expiry/revocation and account/IP login throttles are implemented. Production mode rejects plaintext and untrusted proxy headers. Create real operator accounts and validate HTTPS when hosting is chosen. See [admin account instructions](../README.md#local-admin-accounts) and [OWASP authentication guidance](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html).

2. **Host and connect the backend.** `.github/workflows/deploy-web.yml` deploys static Flutter files only. It neither runs Node nor supplies `CHAT_API_BASE_URL`. The browser then requests `/api/*` on the Pages origin, which has no such backend. Deploy the backend with HTTPS and either route `/api/*` to it or compile its public HTTPS origin into the frontend. Configure `CHAT_ALLOWED_ORIGINS` for the exact frontend origin. The backend currently binds to `127.0.0.1` and reads `CHAT_PORT`, so hosting must provide a compatible reverse proxy or adapt the listener to the platform. Store Gemini and MapTiler private credentials only in backend secrets. Verify live map key origin restrictions and attribution on the intended domain.

3. **Storage safeguards implemented locally.** SQLite transactions now own records, accounts, sessions, usage and admission counters. Existing JSON data migrates once. Versions prevent lost edits/deletions; catalog changes and their actor/before/after audit rows commit atomically. Backup and restore commands are tested, including integrity and restored-session revocation. Operate one backend on a persistent local volume with scheduled protected off-machine backups; a multi-host rollout still needs a shared database service.

4. **Resolved: conservative free-tier controls accepted.** The project owner confirmed that the project will use Gemini's free tier, with no planned paid subscription unless needed, and accepted the existing guardrails and limitations as sufficient for this scope. Client-IP, global window, daily and minute limits are enforced in SQLite alongside shared provider leases. A bounded queue, client cancellation, provider cooldown, Retry-After guidance, output-token cap and admin metrics are implemented and tested. Provider concurrency remains two. The default five questions per IP per ten minutes, including the shared-campus-IP limitation, and temporary unavailability when free-tier limits are reached are accepted operational constraints. Defaults are documented in [the chatbot free-tier policy](../README.md#chatbot-free-tier-policy). No paid subscription, increased capacity or additional quota-validation requirement blocks deployment configuration under this decision. Revisit this item if the project's traffic or availability requirements change.

5. **Verification gates implemented; hosted validation deferred.** Analysis, Flutter tests, backend tests and a local stress/30-second soak now block CI publication on failure. Backend tests cover HTTP auth/CRUD/chat map actions, persistence after restart, backups and shared limits. Optional HTTPS staging smoke/browser checks and a five-minute catalog soak are prepared, with zero failed reads and catalog p95 below one second as acceptance criteria. They have not run against staging because hosting (#2) is explicitly deferred. Hosted TLS, restart recovery, browser map rendering and chatbot connectivity must still pass before a public rollout. Free-tier capacity is accepted under item 4. Preserve request limits/timeouts behind the hosting proxy; see [Node HTTP timeout guidance](https://nodejs.org/api/http.html#serverrequesttimeout).

## Follow-up fixes implemented

Follow-up validation: 59 Flutter tests and 21 backend tests passed; Flutter analysis
reported no issues, the release web build succeeded, and its secret scan found no
configured private keys in the 40 browser files after repository cleanup.

- Admin Add/Edit supports validated latitude/longitude pairs. New records with coordinates have selectable map pins and chatbot map actions; existing OSM outlines remain intact. Coordinates can be edited or cleared. No building footprint is invented for a coordinate-only pin.
- Active catalog views poll every 10 seconds and refresh when the app resumes. Polling stops when there are no subscribers or the app is backgrounded. Unchanged catalogs do not rebuild the map; edits, additions and deletions synchronize across instances. Background browser scheduling can delay polling until the tab is active again.
- Map, directory, details and admin display a loading or unavailable-data notice. Refresh failures distinguish sample data from previously loaded data, provide Retry, and automatically clear the warning after recovery. Malformed responses preserve the last good catalog, and old in-flight refreshes cannot replace a newer saved catalog.

Operating hours remain a campus content verification task rather than a permanent technical limitation. Hosting and hosted validation remain required before public deployment.

Once these requirements are met, evaluate a hosted staging build rather than promoting this localhost result directly to public production. No deployment was performed during this assessment.
