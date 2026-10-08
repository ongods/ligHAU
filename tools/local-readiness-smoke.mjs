// Read-only checks of the existing local servers. --one-chat uses one provider request.
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { performance } from 'node:perf_hooks';
import { createHash } from 'node:crypto';

const app = 'http://localhost:53923';
const api = 'http://127.0.0.1:8787';
const checks = [];
const request = (url, options = {}) => fetch(url, { ...options, signal: AbortSignal.timeout(45000) });
async function check(name, action) {
  const start = performance.now();
  const progress = {};
  try {
    const details = await action(progress);
    checks.push({ name, passed: true, durationMs: Math.round(performance.now() - start), ...progress, ...details });
  } catch (error) {
    // URLs can contain the public map key: never print raw network exceptions.
    checks.push({ name, passed: false, durationMs: Math.round(performance.now() - start),
      errorType: error.name, errorCode: error.code || error.cause?.code, ...progress });
  }
  console.log(JSON.stringify(checks.at(-1)));
}
const catalog = async () => {
  const response = await request(`${api}/api/facilities`);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.ok(Array.isArray(body.facilities) && body.facilities.length > 0);
  return body.facilities;
};
const digest = (value) => createHash('sha256').update(JSON.stringify(value)).digest('hex');
let before;
await check('existing app and backend health', async () => {
  assert.equal((await request(app)).status, 200);
  assert.equal((await (await request(`${api}/health`)).json()).service, 'ligHAU-chat');
  before = await catalog();
  return { facilities: before.length };
});
await check('live catalog read burst', async () => {
  let next = 0;
  const times = [];
  await Promise.all(Array.from({ length: 20 }, async () => {
    while (next++ < 500) {
      const start = performance.now();
      assert.equal(digest(await catalog()), digest(before));
      times.push(performance.now() - start);
    }
  }));
  times.sort((a, b) => a - b);
  const p95Ms = Math.round(times[Math.ceil(times.length * .95) - 1]);
  assert.ok(p95Ms < 1000);
  return { requests: times.length, concurrency: 20, p95Ms };
});
await check('anonymous access to admin usage is rejected', async () => {
  assert.equal((await request(`${api}/api/admin/usage`)).status, 401);
});
await check('MapTiler style and campus vector tile', async (progress) => {
  const config = JSON.parse(readFileSync(new URL('../assets/config/map.local.json', import.meta.url), 'utf8'));
  assert.ok(config.MAPTILER_KEY);
  const styleResponse = await request(`https://api.maptiler.com/maps/${config.MAPTILER_STYLE_ID || 'streets-v4'}/style.json?key=${encodeURIComponent(config.MAPTILER_KEY)}`, { headers: { Referer: `${app}/`, Origin: app } });
  progress.styleStatus = styleResponse.status;
  assert.equal(styleResponse.status, 200);
  const style = await styleResponse.json();
  const source = Object.values(style.sources).find((item) => item.type === 'vector' && (item.url || item.tiles?.length));
  progress.vectorSourcePresent = !!source;
  assert.ok(source);
  let tiles = source.tiles;
  let maxZoom = source.maxzoom ?? 16;
  if (!tiles && source.url) {
    progress.sourceProtocol = new URL(source.url).protocol;
    progress.sourceHost = new URL(source.url).hostname;
    const sourceResponse = await request(source.url, { headers: { Referer: `${app}/`, Origin: app } });
    progress.sourceStatus = sourceResponse.status;
    assert.equal(sourceResponse.status, 200);
    const metadata = await sourceResponse.json();
    tiles = metadata.tiles;
    maxZoom = metadata.maxzoom ?? maxZoom;
  }
  assert.ok(tiles?.length);
  const zoom = Math.min(16, maxZoom);
  progress.tileZoom = zoom;
  const x = Math.floor((120.5901 + 180) / 360 * 2 ** zoom);
  const lat = 15.1325 * Math.PI / 180;
  const y = Math.floor((1 - Math.asinh(Math.tan(lat)) / Math.PI) / 2 * 2 ** zoom);
  const tileUrl = tiles[0].replace('{z}', zoom).replace('{x}', x).replace('{y}', y);
  const response = await request(tileUrl, { headers: { Referer: `${app}/`, Origin: app } });
  progress.tileStatus = response.status;
  assert.equal(response.status, 200);
  const bytes = (await response.arrayBuffer()).byteLength;
  assert.ok(bytes > 0);
  return { tileBytes: bytes, scope: 'HTTP access only; domain restrictions and rendering need hosted browser validation' };
});
if (process.argv.includes('--one-chat')) await check('one real Gemini answer through current backend', async () => {
  const response = await request(`${api}/api/chat`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ messages: [{ role: 'user', text: 'Where is the campus library? Give a short answer based on the campus records.' }] }) });
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.ok(typeof body.answer === 'string' && body.answer.length && Array.isArray(body.facilityNames));
  return { answerCharacters: body.answer.length, matchedFacilities: body.facilityNames.length };
});
const debugArg = process.argv.find((arg) => arg.startsWith('--browser-port='));
if (debugArg) await check('existing Chrome app DOM inspection', async () => {
  const port = Number(debugArg.split('=')[1]);
  assert.ok(Number.isInteger(port) && port > 0 && port < 65536);
  const targets = await (await request(`http://127.0.0.1:${port}/json/list`)).json();
  const target = targets.find((item) => item.type === 'page' && new URL(item.url).port === '53923');
  assert.ok(target);
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  const result = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => { ws.close(); reject(new Error('Inspection timed out')); }, 10000);
    ws.addEventListener('error', () => { clearTimeout(timer); reject(new Error('Inspection unavailable')); }, { once: true });
    ws.addEventListener('open', () => ws.send(JSON.stringify({ id: 1, method: 'Runtime.evaluate', params: {
      expression: "JSON.stringify({readyState:document.readyState,flutterViews:document.querySelectorAll('flutter-view,flt-glass-pane').length,mapCanvases:document.querySelectorAll('.maplibregl-map canvas').length,visibleMapError:/The map couldn.t load/.test(document.body.innerText)})",
      returnByValue: true,
    } })));
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.id !== 1) return;
      clearTimeout(timer); ws.close();
      if (message.error || message.result?.exceptionDetails) reject(new Error('Inspection failed'));
      else resolve(JSON.parse(message.result.result.value));
    });
  });
  assert.equal(result.readyState, 'complete');
  assert.ok(result.flutterViews > 0);
  assert.equal(result.visibleMapError, false);
  return { ...result, scope: 'Read-only DOM inspection of the current screen; no navigation or interaction stress' };
});
await check('live campus records unchanged', async () => {
  assert.ok(before);
  assert.equal(digest(await catalog()), digest(before));
});
const report = { completedAt: new Date().toISOString(), scope: 'Existing local ports only; no catalog writes, no account creation, at most one real chat',
  passed: checks.every((item) => item.passed), checks };
writeFileSync(new URL('../docs/local-smoke-results.json', import.meta.url), JSON.stringify(report, null, 2));
if (!report.passed) process.exitCode = 1;
