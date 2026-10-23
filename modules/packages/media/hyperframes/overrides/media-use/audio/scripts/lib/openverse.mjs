// Sound effects and music from Openverse (https://api.openverse.org): free, no key.
// Anonymous use is rate limited (20 requests a minute, 200 a day); callers fall
// back to the bundled library when it is unavailable.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

const OPENVERSE_AUDIO_URL = "https://api.openverse.org/v1/audio/";
// The only licences media-use accepts: no NonCommercial, ShareAlike or NoDerivatives.
export const OPENVERSE_SFX_LICENSES = new Set(["cc0", "by"]);
const PLAYABLE_FILETYPES = new Set(["mp3", "wav", "ogg", "flac"]);
const MAX_SFX_MS = 15000;
const IDEAL_SFX_MS = 4000;
const BY_PENALTY = 2;
const SEARCH_TIMEOUT_MS = 10000;
// A music query is far slower than a cue-sized one (tens of seconds), so it gets its own budget.
const MUSIC_SEARCH_TIMEOUT_MS = 90000;

// Openverse text lands in markdown and JSON: one line, no control or markdown-structure characters, bounded.
const oneLine = (text) =>
  String(text ?? "")
    .replace(/[\p{Cc}`[\]<>\\]+/gu, " ")
    .trim()
    .slice(0, 300);
// Openverse's audio providers (api.openverse.org/v1/audio/stats/); a new provider's link is dropped until listed.
const SOURCE_HOSTS = new Set(["freesound.org", "www.jamendo.com", "commons.wikimedia.org"]);
function httpsUrl(url, hosts) {
  try {
    const parsed = new URL(url);
    return parsed.protocol === "https:" && (!hosts || hosts.has(parsed.hostname))
      ? oneLine(parsed.href)
      : "";
  } catch {
    return "";
  }
}

/** Openverse could not answer (offline, rate limited, server error): stop asking it this run. */
export class OpenverseUnavailableError extends Error {
  constructor(message) {
    super(message);
    this.name = "OpenverseUnavailableError";
  }
}

function usable(result) {
  return (
    OPENVERSE_SFX_LICENSES.has(result?.license) &&
    PLAYABLE_FILETYPES.has(result.filetype) &&
    typeof result.url === "string" &&
    result.url.startsWith("https://") &&
    Number.isFinite(result.duration) &&
    result.duration > 0 &&
    result.duration <= MAX_SFX_MS
  );
}

// Lower is better: relevance position, then seconds past a typical cue length, then CC0 over CC BY.
function penalty(result, position) {
  const longBy = Math.max(0, result.duration - IDEAL_SFX_MS) / 1000;
  return position + longBy + (result.license === "by" ? BY_PENALTY : 0);
}

/** Best usable sound in Openverse's relevance-ordered results, or null. */
export function pickOpenverseSfx(results) {
  let best = null;
  results.forEach((result, position) => {
    if (!usable(result)) return;
    const score = penalty(result, position);
    if (!best || score < best.score) best = { result, score };
  });
  if (!best) return null;
  const r = best.result;
  return {
    id: r.id,
    url: r.url,
    ext: `.${r.filetype}`,
    title: oneLine(r.title),
    creator: oneLine(r.creator),
    license: r.license,
    licenseUrl: httpsUrl(r.license_url),
    sourceUrl: httpsUrl(r.foreign_landing_url, SOURCE_HOSTS),
    credit: oneLine(r.attribution),
    durationS: Math.round(r.duration) / 1000,
  };
}

/** Best licensed sound effect for `query`, null on no match; throws OpenverseUnavailableError. */
export async function searchOpenverseSfx(query, { fetchImpl = fetch } = {}) {
  const params = new URLSearchParams({
    q: query,
    page_size: "20",
    license: [...OPENVERSE_SFX_LICENSES].join(","),
  });
  let response;
  try {
    response = await fetchImpl(`${OPENVERSE_AUDIO_URL}?${params}`, {
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(SEARCH_TIMEOUT_MS),
    });
  } catch (error) {
    throw new OpenverseUnavailableError(`Openverse unreachable (${error.message})`);
  }
  if (response.status === 429)
    throw new OpenverseUnavailableError("Openverse rate limit reached (HTTP 429)");
  if (!response.ok) throw new OpenverseUnavailableError(`Openverse HTTP ${response.status}`);
  let body;
  try {
    body = await response.json();
  } catch {
    throw new OpenverseUnavailableError("Openverse returned non-JSON");
  }
  return pickOpenverseSfx(Array.isArray(body?.results) ? body.results : []);
}

/** Record a CC BY sound's credit for `file` in the project's credits file (one line per file). */
export function writeSfxCredit(creditsPath, file, sound) {
  writeCredit(creditsPath, file, sound, "# Sound effect credits", "sounds");
}

/** Record a CC BY music track's credit for `file` in the project's credits file (one line per file). */
export function writeMusicCredit(creditsPath, file, track) {
  writeCredit(creditsPath, file, track, "# Music credits", "tracks");
}

function writeCredit(creditsPath, file, sound, title, noun) {
  if (sound.license !== "by") return;
  // The sound may come from a saved record, not this run's pick: clean it again here.
  const sourceUrl = httpsUrl(sound.sourceUrl, SOURCE_HOSTS);
  const source = sourceUrl ? ` Source: ${sourceUrl}` : "";
  const line = `- \`${file}\`: ${oneLine(sound.credit)}${source}`;
  let prior = "";
  try {
    prior = readFileSync(creditsPath, "utf8");
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  const kept = prior
    .split("\n")
    .filter((l) => l.startsWith("- ") && !l.startsWith(`- \`${file}\`:`));
  const headerText = `# ${title}\n\nThese ${noun} are licensed CC BY: credit them wherever the video is published.\n\n`;
  mkdirSync(dirname(creditsPath), { recursive: true });
  writeFileSync(creditsPath, `${headerText}${[...kept, line].join("\n")}\n`);
}

// Music file types Openverse reports; jamendo's "mp32" is its mp3-320 code and serves audio/mpeg.
const MUSIC_FILETYPES = new Map([
  ["mp3", ".mp3"],
  ["mp32", ".mp3"],
  ["wav", ".wav"],
  ["ogg", ".ogg"],
  ["flac", ".flac"],
]);
const MIN_MUSIC_MS = 5000;
const MAX_MUSIC_MS = 600000;
const IDEAL_MUSIC_MS = 90000;

function usableMusic(result) {
  return (
    OPENVERSE_SFX_LICENSES.has(result?.license) &&
    MUSIC_FILETYPES.has(result.filetype) &&
    typeof result.url === "string" &&
    result.url.startsWith("https://") &&
    Number.isFinite(result.duration) &&
    result.duration >= MIN_MUSIC_MS &&
    result.duration <= MAX_MUSIC_MS
  );
}

// Lower is better: relevance position, then seconds past a bed length, then CC0 over CC BY.
function musicPenalty(result, position) {
  const longBy = Math.max(0, result.duration - IDEAL_MUSIC_MS) / 1000;
  return position + longBy + (result.license === "by" ? BY_PENALTY : 0);
}

/** Best licensed music track in Openverse's relevance-ordered results, or null. */
export function pickOpenverseMusic(results) {
  let best = null;
  results.forEach((result, position) => {
    if (!usableMusic(result)) return;
    const score = musicPenalty(result, position);
    if (!best || score < best.score) best = { result, score };
  });
  if (!best) return null;
  const r = best.result;
  return {
    id: r.id,
    url: r.url,
    ext: MUSIC_FILETYPES.get(r.filetype),
    title: oneLine(r.title),
    creator: oneLine(r.creator),
    license: r.license,
    licenseUrl: httpsUrl(r.license_url),
    sourceUrl: httpsUrl(r.foreign_landing_url, SOURCE_HOSTS),
    credit: oneLine(r.attribution),
    durationS: Math.round(r.duration) / 1000,
  };
}

/** Best licensed music track for `query`, null on no match; throws OpenverseUnavailableError. */
export async function searchOpenverseMusic(query, { fetchImpl = fetch } = {}) {
  const params = new URLSearchParams({
    q: query,
    category: "music",
    page_size: "20",
    license: [...OPENVERSE_SFX_LICENSES].join(","),
  });
  let response;
  try {
    response = await fetchImpl(`${OPENVERSE_AUDIO_URL}?${params}`, {
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(MUSIC_SEARCH_TIMEOUT_MS),
    });
  } catch (error) {
    throw new OpenverseUnavailableError(`Openverse unreachable (${error.message})`);
  }
  if (response.status === 429)
    throw new OpenverseUnavailableError("Openverse rate limit reached (HTTP 429)");
  if (!response.ok) throw new OpenverseUnavailableError(`Openverse HTTP ${response.status}`);
  let body;
  try {
    body = await response.json();
  } catch {
    throw new OpenverseUnavailableError("Openverse returned non-JSON");
  }
  return pickOpenverseMusic(Array.isArray(body?.results) ? body.results : []);
}
