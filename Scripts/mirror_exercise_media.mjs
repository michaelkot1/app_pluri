#!/usr/bin/env node
// Mirrors WorkoutX exercise GIFs into Pluri's own Supabase Storage as small
// looping MP4s, then records the public CDN URL on `public.exercises`
// (SPEC §14 #79).
//
// Why this exists: `exercises.gif_url` points at api.workoutxapp.com, which
// answers 401 without an `X-WorkoutX-Key` header. Shipping that key in the iOS
// bundle is not an option (AGENTS.md §2), and the free plan only allows ~500
// requests/month — so each GIF is fetched exactly once, here, by the owner.
//
// Requires: node >= 20 and `ffmpeg` on PATH (brew install ffmpeg).
// Reads WORKOUTX_API_KEY / SUPABASE_URL and a server-side Supabase key
// (SUPABASE_SECRET_KEY, else SUPABASE_SERVICE_ROLE_KEY) from the repo-root .env,
// which is gitignored. No key material is ever logged.
//
// Usage (from the repo root):
//   node Scripts/mirror_exercise_media.mjs --hot-set --dry-run
//   node Scripts/mirror_exercise_media.mjs --hot-set --limit=25
//   node Scripts/mirror_exercise_media.mjs --ids=0001,0002
//   node Scripts/mirror_exercise_media.mjs --limit=50        # backfill the rest
//
// Flags:
//   --hot-set        Only exercises referenced by `workout_exercises` (~89).
//   --ids=a,b,c      Explicit exercise ids.
//   --limit=N        Max exercises this run (default 25 — quota is ~500/month).
//   --delay-ms=N     Pause between WorkoutX fetches (default 1500).
//   --concurrency=N  Parallel workers, capped at 2 (default 1).
//   --force          Re-mirror even when `video_path` is already set.
//   --dry-run        Resolve targets and print the plan; no fetch/upload/write.

import { spawn } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BUCKET = 'exercise-media';
const OBJECT_PREFIX = 'exercises';
const DEFAULT_LIMIT = 25;
const DEFAULT_DELAY_MS = 1500;
const MAX_CONCURRENCY = 2;

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

// ---------------------------------------------------------------- env + args

/** Parses `KEY="value"` lines out of the repo-root .env without extra deps. */
async function loadEnv() {
  const envPath = path.join(REPO_ROOT, '.env');
  let raw;
  try {
    raw = await readFile(envPath, 'utf8');
  } catch {
    fail(`${envPath} not found. Copy .env.example to .env and fill in values.`);
  }

  const env = {};
  for (const line of raw.split('\n')) {
    const match = /^\s*([A-Z0-9_]+)\s*=\s*(.*)$/.exec(line);
    if (!match) continue;
    let value = match[2].trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    env[match[1]] = value;
  }
  return env;
}

function parseArgs(argv) {
  const options = {
    hotSet: false,
    ids: null,
    limit: DEFAULT_LIMIT,
    delayMs: DEFAULT_DELAY_MS,
    concurrency: 1,
    force: false,
    dryRun: false,
  };

  for (const arg of argv) {
    if (arg === '--hot-set') options.hotSet = true;
    else if (arg === '--force') options.force = true;
    else if (arg === '--dry-run') options.dryRun = true;
    else if (arg.startsWith('--ids=')) {
      options.ids = arg
        .slice('--ids='.length)
        .split(',')
        .map((id) => id.trim())
        .filter(Boolean);
    } else if (arg.startsWith('--limit=')) {
      options.limit = intArgument(arg);
    } else if (arg.startsWith('--delay-ms=')) {
      options.delayMs = intArgument(arg, { allowZero: true });
    } else if (arg.startsWith('--concurrency=')) {
      options.concurrency = Math.min(MAX_CONCURRENCY, intArgument(arg));
    } else {
      fail(`Unknown argument: ${arg}`);
    }
  }
  return options;
}

function intArgument(arg, { allowZero = false } = {}) {
  const parsed = Number.parseInt(arg.slice(arg.indexOf('=') + 1), 10);
  if (!Number.isInteger(parsed) || parsed < (allowZero ? 0 : 1)) {
    fail(`Invalid value in ${arg}`);
  }
  return parsed;
}

function fail(message) {
  console.error(`error: ${message}`);
  process.exit(1);
}

/**
 * Picks a key that can write Storage and `public.exercises`. The project's
 * `SUPABASE_SERVICE_ROLE_KEY` slot currently holds the anon JWT (the M0-11
 * owner gap in SPEC §15), so the newer `sb_secret_…` key is preferred and an
 * anon-role JWT is rejected loudly rather than failing later as empty reads.
 */
function resolveServerKey(env) {
  const candidates = [
    ['SUPABASE_SECRET_KEY', env.SUPABASE_SECRET_KEY],
    ['SUPABASE_SERVICE_ROLE_KEY', env.SUPABASE_SERVICE_ROLE_KEY],
  ].filter(([, value]) => Boolean(value));

  for (const [name, value] of candidates) {
    if (jwtRole(value) === 'anon') {
      console.warn(`warn: ${name} in .env is an anon-role key — skipping it.`);
      continue;
    }
    return { name, value };
  }

  fail(
    'No server-side Supabase key in .env. Set SUPABASE_SECRET_KEY (sb_secret_…) ' +
      'or a real SUPABASE_SERVICE_ROLE_KEY. Anon keys cannot write Storage.'
  );
}

function jwtRole(key) {
  const segments = key.split('.');
  if (segments.length !== 3) return null;
  try {
    return JSON.parse(Buffer.from(segments[1], 'base64url').toString('utf8')).role ?? null;
  } catch {
    return null;
  }
}

// ------------------------------------------------------------------ supabase

class Supabase {
  constructor(url, serviceRoleKey) {
    this.url = url.replace(/\/+$/, '');
    this.key = serviceRoleKey;
  }

  get #authHeaders() {
    return { apikey: this.key, Authorization: `Bearer ${this.key}` };
  }

  /**
   * Reads every matching row. PostgREST caps a plain request at ~1,000 rows,
   * which both the 1,327-row catalog and a growing `workout_exercises` table
   * silently exceed — so page explicitly with Range headers.
   */
  async select(pathAndQuery, pageSize = 500) {
    const rows = [];
    for (let offset = 0; ; offset += pageSize) {
      const response = await fetch(`${this.url}/rest/v1/${pathAndQuery}`, {
        headers: {
          ...this.#authHeaders,
          Accept: 'application/json',
          Range: `${offset}-${offset + pageSize - 1}`,
          'Range-Unit': 'items',
        },
      });
      if (!response.ok) {
        throw new Error(`PostgREST GET ${pathAndQuery} failed: ${response.status}`);
      }
      const page = await response.json();
      rows.push(...page);
      if (page.length < pageSize) return rows;
    }
  }

  async updateExercise(id, patch) {
    const response = await fetch(
      `${this.url}/rest/v1/exercises?id=eq.${encodeURIComponent(id)}`,
      {
        method: 'PATCH',
        headers: {
          ...this.#authHeaders,
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        body: JSON.stringify(patch),
      }
    );
    if (!response.ok) {
      throw new Error(
        `PostgREST PATCH exercises/${id} failed: ${response.status} ${await safeText(response)}`
      );
    }
  }

  async upload(objectPath, bytes, contentType) {
    const response = await fetch(
      `${this.url}/storage/v1/object/${BUCKET}/${objectPath}`,
      {
        method: 'POST',
        headers: {
          ...this.#authHeaders,
          'Content-Type': contentType,
          'Cache-Control': 'max-age=31536000, immutable',
          'x-upsert': 'true',
        },
        body: bytes,
      }
    );
    if (!response.ok) {
      throw new Error(
        `Storage upload ${objectPath} failed: ${response.status} ${await safeText(response)}`
      );
    }
  }

  publicURL(objectPath) {
    return `${this.url}/storage/v1/object/public/${BUCKET}/${objectPath}`;
  }
}

async function safeText(response) {
  try {
    return (await response.text()).slice(0, 300);
  } catch {
    return '';
  }
}

// ------------------------------------------------------------------- targets

async function resolveTargets(supabase, options) {
  const columns = 'id,name,gif_url,video_path';

  if (options.ids) {
    const list = options.ids.map((id) => encodeURIComponent(id)).join(',');
    const rows = await supabase.select(`exercises?select=${columns}&id=in.(${list})`);
    const found = new Set(rows.map((row) => row.id));
    for (const id of options.ids) {
      if (!found.has(id)) console.warn(`warn: exercise ${id} not found in public.exercises`);
    }
    return rows;
  }

  if (options.hotSet) {
    const used = await supabase.select(
      'workout_exercises?select=workoutx_exercise_id&order=workoutx_exercise_id'
    );
    const ids = [...new Set(used.map((row) => row.workoutx_exercise_id).filter(Boolean))];
    if (ids.length === 0) return [];
    // Chunked so a large hot set can't blow past the URL length limit.
    const rows = [];
    for (let index = 0; index < ids.length; index += 100) {
      const chunk = ids.slice(index, index + 100).map((id) => encodeURIComponent(id));
      rows.push(
        ...(await supabase.select(`exercises?select=${columns}&id=in.(${chunk.join(',')})`))
      );
    }
    return rows.sort((a, b) => a.id.localeCompare(b.id));
  }

  // Backfill: most-used-looking exercises first so early runs cover what
  // plan generation is most likely to surface.
  const unmirroredOnly = options.force ? '' : '&video_path=is.null';
  return supabase.select(
    `exercises?select=${columns}${unmirroredOnly}&gif_url=not.is.null` +
      '&order=popularity_rank.asc.nullslast,id.asc'
  );
}

// ------------------------------------------------------------------ pipeline

async function downloadGIF(gifURL, apiKey) {
  const response = await fetch(gifURL, {
    headers: { 'X-WorkoutX-Key': apiKey, Accept: 'image/gif' },
  });

  const quota = {
    quotaRemaining: response.headers.get('x-quota-remaining'),
    quotaLimit: response.headers.get('x-quota-limit'),
    uniqueGifRemaining: response.headers.get('x-unique-gif-remaining'),
    rateRemaining: response.headers.get('x-ratelimit-remaining'),
  };

  if (response.status === 429) {
    const error = new Error('WorkoutX rate limited (429) — stopping this run.');
    error.stopRun = true;
    error.quota = quota;
    throw error;
  }
  if (response.status === 401 || response.status === 403) {
    const error = new Error(
      `WorkoutX rejected the key (${response.status}) — check WORKOUTX_API_KEY.`
    );
    error.stopRun = true;
    throw error;
  }
  if (!response.ok) {
    throw Object.assign(new Error(`GIF fetch failed: ${response.status}`), { quota });
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.byteLength === 0) throw Object.assign(new Error('GIF was empty'), { quota });
  return { bytes, quota };
}

/**
 * GIF → small looping MP4. Downscaled to at most 480px wide with even
 * dimensions (yuv420p needs them), 15 fps, no audio track, and `+faststart`
 * so AVPlayer can start on the first range request.
 */
function transcode(inputPath, outputPath) {
  const args = [
    '-hide_banner',
    '-loglevel', 'error',
    '-y',
    '-i', inputPath,
    '-an',
    '-vf', "fps=15,scale='trunc(min(iw,480)/2)*2':-2:flags=lanczos",
    '-c:v', 'libx264',
    '-profile:v', 'baseline',
    '-level', '3.1',
    '-preset', 'veryslow',
    '-crf', '30',
    '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart',
    outputPath,
  ];

  return new Promise((resolve, reject) => {
    const child = spawn('ffmpeg', args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });
    child.on('error', (error) =>
      reject(new Error(`ffmpeg could not be started (${error.message}). Is it on PATH?`))
    );
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg exited ${code}: ${stderr.trim().slice(0, 300)}`));
    });
  });
}

async function mirrorOne(exercise, { supabase, apiKey, workDirectory }) {
  const { bytes: gifBytes, quota } = await downloadGIF(exercise.gif_url, apiKey);

  const gifPath = path.join(workDirectory, `${exercise.id}.gif`);
  const mp4Path = path.join(workDirectory, `${exercise.id}.mp4`);
  await writeFile(gifPath, gifBytes);
  try {
    await transcode(gifPath, mp4Path);
    const mp4Bytes = await readFile(mp4Path);
    const objectPath = `${OBJECT_PREFIX}/${exercise.id}.mp4`;

    await supabase.upload(objectPath, mp4Bytes, 'video/mp4');
    await supabase.updateExercise(exercise.id, {
      video_path: objectPath,
      video_url: supabase.publicURL(objectPath),
      video_bytes: mp4Bytes.byteLength,
      video_mirrored_at: new Date().toISOString(),
    });

    return { gifBytes: gifBytes.byteLength, mp4Bytes: mp4Bytes.byteLength, quota };
  } finally {
    await rm(gifPath, { force: true });
    await rm(mp4Path, { force: true });
  }
}

// ----------------------------------------------------------------- run loop

function kilobytes(byteCount) {
  return `${(byteCount / 1024).toFixed(0)} KB`;
}

function describeQuota(quota) {
  if (!quota) return '';
  const parts = [];
  if (quota.quotaRemaining != null) {
    parts.push(`quota ${quota.quotaRemaining}${quota.quotaLimit ? `/${quota.quotaLimit}` : ''}`);
  }
  if (quota.uniqueGifRemaining != null) parts.push(`unique-gif ${quota.uniqueGifRemaining}`);
  if (quota.rateRemaining != null) parts.push(`burst ${quota.rateRemaining}`);
  return parts.length > 0 ? ` [${parts.join(', ')}]` : '';
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const env = await loadEnv();

  const supabaseURL = env.SUPABASE_URL;
  const apiKey = env.WORKOUTX_API_KEY;

  if (!supabaseURL) fail('SUPABASE_URL missing from .env');
  if (!apiKey && !options.dryRun) fail('WORKOUTX_API_KEY missing from .env');

  const serverKey = resolveServerKey(env);
  console.log(`using ${serverKey.name} for Supabase writes`);
  const supabase = new Supabase(supabaseURL, serverKey.value);

  const all = await resolveTargets(supabase, options);
  const eligible = all.filter((exercise) => {
    if (!exercise.gif_url) {
      console.warn(`skip ${exercise.id}: no gif_url`);
      return false;
    }
    if (exercise.video_path && !options.force) return false;
    return true;
  });
  const targets = eligible.slice(0, options.limit);

  const mode = options.ids ? 'explicit ids' : options.hotSet ? 'hot set' : 'backfill';
  console.log(
    `mode=${mode} matched=${all.length} needs-mirror=${eligible.length} ` +
      `this-run=${targets.length} (limit ${options.limit}) concurrency=${options.concurrency}` +
      `${options.force ? ' force' : ''}`
  );

  if (targets.length === 0) {
    console.log('Nothing to do.');
    return;
  }

  if (options.dryRun) {
    for (const exercise of targets) console.log(`  would mirror ${exercise.id}  ${exercise.name}`);
    console.log('dry run — no GIF fetched, nothing uploaded.');
    return;
  }

  const workDirectory = await mkdtemp(path.join(tmpdir(), 'pluri-exercise-media-'));
  const queue = [...targets];
  const results = { ok: 0, failed: 0 };
  let stopped = false;

  const worker = async () => {
    while (!stopped) {
      const exercise = queue.shift();
      if (!exercise) return;
      try {
        const outcome = await mirrorOne(exercise, { supabase, apiKey, workDirectory });
        results.ok += 1;
        console.log(
          `ok   ${exercise.id}  ${kilobytes(outcome.gifBytes)} gif → ` +
            `${kilobytes(outcome.mp4Bytes)} mp4${describeQuota(outcome.quota)}`
        );
      } catch (error) {
        results.failed += 1;
        console.error(`fail ${exercise.id}: ${error.message}${describeQuota(error.quota)}`);
        if (error.stopRun) {
          stopped = true;
          return;
        }
      }
      if (options.delayMs > 0 && queue.length > 0) {
        await new Promise((resolve) => setTimeout(resolve, options.delayMs));
      }
    }
  };

  try {
    await Promise.all(Array.from({ length: options.concurrency }, worker));
  } finally {
    await rm(workDirectory, { recursive: true, force: true });
  }

  console.log(`done: ${results.ok} mirrored, ${results.failed} failed`);
  const remaining = eligible.length - results.ok;
  if (remaining > 0) {
    console.log(`${remaining} exercise(s) still unmirrored — re-run to continue.`);
  }
  if (results.failed > 0) process.exitCode = 1;
}

await main();
