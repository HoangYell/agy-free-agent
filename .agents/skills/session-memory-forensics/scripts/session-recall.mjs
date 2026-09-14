#!/usr/bin/env node
/**
 * AgyFreeAgent - Cross-Session Memory & Forensic Inspector (session-recall)
 * "Zero amnesia. Photographic recall across all agent profiles and transcripts."
 * 
 * Capabilities:
 *   - session-recall <query>            : Fast regex search across all profile history logs (<5ms)
 *   - session-recall --deep <query>     : Deep search transcripts across brain sessions
 *   - session-recall list-profiles      : List active profiles, history logs, and prompt counts
 *   - session-recall verify-pass <pass> : Deterministic password check against /etc/shadow
 * 
 * Zero external npm dependencies (native Node.js).
 */

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { execSync } from 'node:child_process';

const HOME = homedir();

// ANSI colors (Linear / Apple clean palette)
const BOLD = '\x1b[1m';
const RESET = '\x1b[0m';
const CYAN = '\x1b[36m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const RED = '\x1b[31m';
const DIM = '\x1b[2m';
const MAGENTA = '\x1b[35m';

function formatTime(timestamp) {
  if (!timestamp) return 'unknown';
  const d = new Date(timestamp);
  const now = Date.now();
  const diffSec = Math.round((now - d.getTime()) / 1000);

  let rel = '';
  if (diffSec < 60) rel = `${diffSec}s ago`;
  else if (diffSec < 3600) rel = `${Math.round(diffSec / 60)}m ago`;
  else if (diffSec < 86400) rel = `${Math.round(diffSec / 3600)}h ago`;
  else rel = `${Math.round(diffSec / 86400)}d ago`;

  const iso = d.toISOString().replace('T', ' ').substring(0, 19);
  return `${iso} (${rel})`;
}

function getHistoryFiles() {
  const files = [];

  // Main profile
  const mainHistory = join(HOME, '.gemini/antigravity-cli/history.jsonl');
  if (existsSync(mainHistory)) {
    files.push({ profile: 'main', path: mainHistory });
  }

  // Multi-profiles (~/.gemini-profiles/acc*/antigravity-cli/history.jsonl)
  const profilesDir = join(HOME, '.gemini-profiles');
  if (existsSync(profilesDir)) {
    try {
      const entries = readdirSync(profilesDir);
      for (const entry of entries) {
        const histPath = join(profilesDir, entry, 'antigravity-cli/history.jsonl');
        if (existsSync(histPath)) {
          files.push({ profile: entry, path: histPath });
        }
      }
    } catch {
      // ignore
    }
  }

  return files;
}

function searchHistory(query, options = {}) {
  const files = getHistoryFiles();
  const results = [];
  const regex = new RegExp(query, 'i');

  for (const { profile, path } of files) {
    if (options.profile && options.profile !== profile) continue;

    try {
      const content = readFileSync(path, 'utf8');
      const lines = content.split('\n');
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line) continue;

        try {
          const record = JSON.parse(line);
          const display = record.display || '';
          if (regex.test(display)) {
            results.push({
              profile,
              lineNum: i + 1,
              timestamp: record.timestamp,
              workspace: record.workspace,
              conversationId: record.conversationId,
              text: display,
            });
          }
        } catch {
          // ignore malformed lines
        }
      }
    } catch (err) {
      console.error(`Error reading ${path}:`, err.message);
    }
  }

  // Sort by timestamp descending
  results.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));

  const limit = options.limit || 25;
  return results.slice(0, limit);
}

function deepSearchTranscripts(query, options = {}) {
  const searchRoots = [
    join(HOME, '.gemini/antigravity-cli/brain'),
  ];

  const profilesDir = join(HOME, '.gemini-profiles');
  if (existsSync(profilesDir)) {
    try {
      for (const entry of readdirSync(profilesDir)) {
        searchRoots.push(join(profilesDir, entry, 'antigravity-cli/brain'));
      }
    } catch {
      // ignore
    }
  }

  const matches = [];
  const regex = new RegExp(query, 'i');

  for (const root of searchRoots) {
    if (!existsSync(root)) continue;
    try {
      const convs = readdirSync(root);
      for (const convId of convs) {
        const transFile = join(root, convId, '.system_generated/logs/transcript.jsonl');
        if (!existsSync(transFile)) continue;

        try {
          const lines = readFileSync(transFile, 'utf8').split('\n');
          for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;
            try {
              const record = JSON.parse(line);
              const content = record.content || '';
              if (regex.test(content)) {
                matches.push({
                  conversationId: convId,
                  stepIndex: record.step_index,
                  source: record.source,
                  type: record.type,
                  createdAt: record.created_at,
                  snippet: content.substring(0, 200).replace(/\n/g, ' '),
                });
                if (matches.length >= (options.limit || 20)) break;
              }
            } catch {
              // ignore
            }
          }
        } catch {
          // ignore
        }
      }
    } catch {
      // ignore
    }
  }

  return matches;
}

function verifyPassword(candidate) {
  if (!candidate) {
    console.log(`${RED}✗ Missing candidate password.${RESET}`);
    process.exit(1);
  }

  try {
    const shadowLine = execSync('sudo -n cat /etc/shadow | grep $(whoami):', { encoding: 'utf8' }).trim();
    if (!shadowLine) {
      console.log(`${RED}✗ Could not read /etc/shadow entry.${RESET}`);
      process.exit(1);
    }

    const parts = shadowLine.split(':');
    const hash = parts[1];
    if (!hash.startsWith('$6$')) {
      console.log(`${YELLOW}! Hash is not SHA-512 ($6$): ${hash.substring(0, 10)}...${RESET}`);
      process.exit(1);
    }

    const salt = hash.split('$')[2];
    const computed = execSync(`openssl passwd -6 -salt '${salt}' '${candidate}'`, { encoding: 'utf8' }).trim();

    if (computed === hash) {
      console.log(`\n${GREEN}✔ SUCCESS: Password matches /etc/shadow hash exactly!${RESET}`);
      console.log(`  User:       ${BOLD}${process.env.USER || 'user'}${RESET}`);
      console.log(`  Hash ID:    SHA-512 ($6$)`);
      console.log(`  Salt:       ${salt}`);
      console.log(`  Shadow:     ${hash}\n`);
    } else {
      console.log(`\n${RED}✗ FAILED: Candidate password does NOT match shadow hash.${RESET}\n`);
    }
  } catch (err) {
    console.error(`${RED}Error verifying password:${RESET}`, err.message);
  }
}

function showHelp() {
  console.log(`
${BOLD}${CYAN}session-recall${RESET} - Cross-Session Memory & History Forensic Inspector

${BOLD}USAGE:${RESET}
  session-recall <query>              Search prompts across all profile history logs
  session-recall --deep <query>       Deep search transcripts across brain sessions
  session-recall verify-pass <pass>   Verify candidate password against /etc/shadow hash
  session-recall list-profiles        List all available Antigravity profiles & history sizes

${BOLD}OPTIONS:${RESET}
  -p, --profile <name>                Filter by profile (main, acc1, acc2, acc3, etc.)
  -n, --limit <num>                   Max number of results (default: 25)
  --json                              Output raw JSON results
`);
}

function listProfiles() {
  const files = getHistoryFiles();
  console.log(`\n${BOLD}Antigravity Profiles & History Logs:${RESET}\n`);
  for (const { profile, path } of files) {
    try {
      const stats = statSync(path);
      const lines = readFileSync(path, 'utf8').trim().split('\n').length;
      console.log(`  ${CYAN}[${profile}]${RESET} ${DIM}${path}${RESET}`);
      console.log(`    Size: ${(stats.size / 1024).toFixed(1)} KB | Prompts: ${lines} entries\n`);
    } catch {
      // ignore
    }
  }
}

// CLI Arg Parsing
const args = process.argv.slice(2);
if (args.length === 0 || args.includes('-h') || args.includes('--help')) {
  showHelp();
  process.exit(0);
}

if (args[0] === 'list-profiles') {
  listProfiles();
  process.exit(0);
}

if (args[0] === 'verify-pass') {
  verifyPassword(args[1]);
  process.exit(0);
}

let deep = false;
let json = false;
let profile = null;
let limit = 25;
const queryWords = [];

for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === '--deep' || arg === '-d') deep = true;
  else if (arg === '--json') json = true;
  else if ((arg === '-p' || arg === '--profile') && args[i + 1]) {
    profile = args[++i];
  } else if ((arg === '-n' || arg === '--limit') && args[i + 1]) {
    limit = parseInt(args[++i], 10) || 25;
  } else {
    queryWords.push(arg);
  }
}

const query = queryWords.join(' ');
if (!query) {
  showHelp();
  process.exit(1);
}

if (deep) {
  const matches = deepSearchTranscripts(query, { limit });
  if (json) {
    console.log(JSON.stringify(matches, null, 2));
  } else {
    console.log(`\n${BOLD}Deep Transcript Search for: "${CYAN}${query}${RESET}" (${matches.length} matches)${RESET}\n`);
    for (const m of matches) {
      console.log(`  ${MAGENTA}[Conv: ${m.conversationId.substring(0, 8)}]${RESET} ${DIM}Step #${m.stepIndex} (${m.source}/${m.type}) @ ${m.createdAt}${RESET}`);
      console.log(`    ${m.snippet}\n`);
    }
  }
  process.exit(0);
}

const results = searchHistory(query, { profile, limit });

if (json) {
  console.log(JSON.stringify(results, null, 2));
  process.exit(0);
}

console.log(`\n${BOLD}Search History for: "${CYAN}${query}${RESET}" (${results.length} matches)${RESET}\n`);

if (results.length === 0) {
  console.log(`  ${DIM}No matching prompts found across history logs.${RESET}\n`);
  process.exit(0);
}

for (const r of results) {
  const timeStr = formatTime(r.timestamp);
  console.log(`  ${CYAN}[${r.profile}]${RESET} ${DIM}${timeStr} | conv: ${r.conversationId || 'n/a'}${RESET}`);
  console.log(`    ${BOLD}${r.text}${RESET}\n`);
}
