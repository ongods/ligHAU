import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const count = (value) => Number.isSafeInteger(value) && value >= 0 ? value : 0;
export const quota = (value) => value !== undefined && value !== '' && Number.isSafeInteger(Number(value)) && Number(value) >= 0 ? Number(value) : null;
export function pacificDay(time) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Los_Angeles', year: 'numeric', month: '2-digit', day: '2-digit' }).format(time);
}
const empty = () => ({ requests: 0, successes: 0, failures: 0, rateLimited: 0,
  inputTokens: 0, outputTokens: 0, totalTokens: 0, missingTokenReports: 0 });

// Stores counts only: no questions, answers, keys or credentials.
export class UsageStore {
  constructor({ file, now = Date.now } = {}) {
    this.file = file;
    this.now = now;
    this.recent = [];
    this.state = { since: new Date(now()).toISOString(), models: {} };
    this.storageError = false;
    if (file && existsSync(file)) {
      try {
        const data = JSON.parse(readFileSync(file, 'utf8'));
        if (typeof data.since !== 'string' || !data.models || typeof data.models !== 'object') throw new Error();
        this.state = data;
      } catch { this.storageError = true; }
    }
  }
  start(model) {
    const event = { model, at: this.now(), inputTokens: 0 };
    const entry = this.state.models[model] ??= { total: empty(), days: {} };
    const day = pacificDay(event.at);
    entry.days[day] ??= empty();
    entry.total.requests++;
    entry.days[day].requests++;
    this.recent = this.recent.filter((item) => item.at > event.at - 60000);
    this.recent.push(event);
    this.save();
    return event;
  }
  finish(event, { success, status, metadata }) {
    const entry = this.state.models[event.model];
    const stats = [entry.total, entry.days[pacificDay(event.at)]];
    event.inputTokens = count(metadata?.promptTokenCount);
    for (const item of stats) {
      item[success ? 'successes' : 'failures']++;
      if (status === 429) item.rateLimited++;
      if (!Number.isSafeInteger(metadata?.totalTokenCount)) item.missingTokenReports++;
      item.inputTokens += event.inputTokens;
      item.outputTokens += count(metadata?.candidatesTokenCount);
      item.totalTokens += count(metadata?.totalTokenCount);
    }
    // Keep daily buckets for the last 90 calendar days; lifetime totals remain.
    const days = Object.keys(entry.days).sort();
    for (const day of days.slice(0, Math.max(0, days.length - 90))) delete entry.days[day];
    this.save();
  }
  save() {
    if (!this.file || this.storageError) return;
    try {
      mkdirSync(dirname(this.file), { recursive: true });
      writeFileSync(`${this.file}.tmp`, JSON.stringify(this.state), { mode: 0o600 });
      renameSync(`${this.file}.tmp`, this.file);
    } catch { this.storageError = true; }
  }
  snapshot(model) {
    const now = this.now();
    const entry = this.state.models[model];
    const recent = this.recent.filter((item) => item.model === model && item.at > now - 60000);
    return { since: this.state.since, day: pacificDay(now), persistent: Boolean(this.file) && !this.storageError,
      today: entry?.days[pacificDay(now)] ?? empty(), total: entry?.total ?? empty(),
      minute: { requests: recent.length, inputTokens: recent.reduce((sum, item) => sum + item.inputTokens, 0) } };
  }
}

export async function mapTilerUsage({ token, fetchImpl = fetch, requestQuota, sessionQuota }) {
  const limits = { requests: quota(requestQuota), sessions: quota(sessionQuota) };
  if (!token) return { status: 'not_configured', limits };
  try {
    const response = await fetchImpl('https://service.maptiler.com/v1/analytics/api_usage/timeline?period=current_billing_period&classifier=services', {
      headers: { Authorization: `Token ${token}` }, signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) return { status: 'unavailable', limits };
    const data = await response.json();
    if (!Array.isArray(data.datasets) || typeof data.since !== 'string' || typeof data.until !== 'string') throw new Error();
    const totals = { requests: 0, sessions: 0 };
    let estimated = false;
    for (const dataset of data.datasets) {
      const key = { request: 'requests', session: 'sessions' }[dataset.group_id];
      if (!key) continue;
      if (!Array.isArray(dataset.data)) throw new Error();
      totals[key] += dataset.data.reduce((sum, item) => sum + count(item.value), 0);
      // Estimated data is a separate date from finalized data; avoid counting twice.
      if (dataset.estimated_data && !dataset.data.some((item) => item.date === dataset.estimated_data.date)) {
        totals[key] += count(dataset.estimated_data.value);
        estimated = true;
      }
    }
    return { status: 'connected', since: data.since, until: data.until, estimated, ...totals, limits };
  } catch { return { status: 'unavailable', limits }; }
}
