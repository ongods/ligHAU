import { readFileSync } from 'node:fs';

const stringPattern = /'((?:\\.|[^'\\])*)'/g;
function strings(value) {
  return [...value.matchAll(stringPattern)].map((match) =>
    match[1].replace(/\\(['\\nrt])/g, (_, char) => ({ n: '\n', r: '\r', t: '\t' }[char] ?? char)));
}

// Read the existing Dart directory rather than maintaining a second catalogue.
// Supports its current literal Facility records and campusHours constant; never evals code.
export function loadCampusData() {
  const source = readFileSync(new URL('../lib/data/mock_data.dart', import.meta.url), 'utf8');
  const geometry = JSON.parse(readFileSync(new URL('../assets/data/hau_osm.json', import.meta.url), 'utf8').replace(/^\uFEFF/, ''));
  const mapped = new Set(geometry.facilities.map((entry) => entry.name));
  const hours = strings(source.match(/const String campusHours\s*=\s*([^;]+);/)?.[1] ?? '')[0];
  if (!hours) throw new Error('Unsupported campus hours format.');
  const records = [...source.matchAll(/\bFacility\(\s*\n([\s\S]*?)\n\s*\),/g)];
  if (!records.length || records.length !== (source.match(/\bFacility\(/g) ?? []).length) {
    throw new Error('Unsupported campus directory format.');
  }
  return records.map((match) => {
    const fields = {};
    for (const entry of match[1].matchAll(/^\s*(\w+):\s*([\s\S]*?)(?=\n\s*\w+:|$)/gm)) {
      const [, name, value] = entry;
      if (['name', 'category', 'location', 'description'].includes(name)) fields[name] = strings(value).join('');
      if (name === 'facilities') fields.facilities = strings(value);
      if (name === 'floors') fields.floors = /^null/.test(value) ? null : Number.parseInt(value, 10);
      if (name === 'hours') fields.hours = value.trim().startsWith('campusHours') ? hours : strings(value).join('');
    }
    if (!fields.name || !fields.description || !Array.isArray(fields.facilities) || !fields.hours) {
      throw new Error('Unsupported facility record.');
    }
    return { ...fields, hoursVerified: false, hasMapLocation: mapped.has(fields.name) };
  });
}
