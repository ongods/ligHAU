// Public catalog traffic only: no writes, admin credentials or Gemini calls.
import { performance } from 'node:perf_hooks';
import { writeFileSync } from 'node:fs';
const endpoint = new URL('/api/facilities', process.env.SMOKE_API_URL || 'https://invalid.example');
if (!process.env.SMOKE_API_URL || endpoint.protocol !== 'https:') throw new Error('Set SMOKE_API_URL to the HTTPS staging backend.');
const seconds = Number(process.env.SOAK_SECONDS || 300);
const concurrency = Number(process.env.SOAK_CONCURRENCY || 10);
if (!Number.isInteger(seconds) || seconds < 30 || seconds > 1800 || !Number.isInteger(concurrency) || concurrency < 1 || concurrency > 50) throw new Error('Use 30–1800 seconds and 1–50 concurrent requests.');
const start = performance.now();
const times = [];
let failed = 0;
await Promise.all(Array.from({ length: concurrency }, async () => {
  while (performance.now() - start < seconds * 1000) {
    const at = performance.now();
    try {
      const result = await fetch(endpoint, { signal: AbortSignal.timeout(10000) });
      if (result.status !== 200 || !Array.isArray((await result.json()).facilities)) failed++;
    } catch { failed++; }
    times.push(performance.now() - at);
  }
}));
times.sort((a,b) => a-b);
const p95Ms = times[Math.ceil(times.length * .95) - 1];
const report = { completedAt: new Date().toISOString(), seconds, concurrency, requests: times.length, failed,
  p95Ms: Math.round(p95Ms), passed: failed === 0 && p95Ms < 1000, scope: 'Staging public catalog only; no chatbot capacity or browser rendering inference.' };
writeFileSync(new URL('../docs/staging-soak-results.json', import.meta.url), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report));
if (!report.passed) process.exitCode = 1;
