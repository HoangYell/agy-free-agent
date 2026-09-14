#!/usr/bin/env bash
# ==============================================================================
# AgyFreeAgent - Log Management & Host Hygiene Script
# Prunes stale session logs, vacuum-cleans journald, and purges orphaned caches.
# ==============================================================================

set -euo pipefail

PROFILES_BASE="${HOME}/.gemini-profiles"
DEFAULT_PROFILE="${HOME}/.gemini/antigravity-cli"
OPS_LOG_DIR="${HOME}/.ops/logs"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

echo "=========================================================="
echo "          AgyFreeAgent Log & Hygiene Manager              "
echo "=========================================================="
echo "[*] Retention window: ${RETENTION_DAYS} days"

# 1. Clean primary profile logs
if [[ -d "${DEFAULT_PROFILE}/log" ]]; then
  echo "[*] Pruning logs older than ${RETENTION_DAYS} days in primary profile..."
  find "${DEFAULT_PROFILE}/log" -type f -name "*.log" -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true
fi

# 2. Clean multi-profile logs
if [[ -d "${PROFILES_BASE}" ]]; then
  echo "[*] Pruning multi-profile logs in ${PROFILES_BASE}..."
  find "${PROFILES_BASE}" -type f -path "*/antigravity-cli/log/*.log" -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true
fi

# 3. Clean operational background logs
if [[ -d "${OPS_LOG_DIR}" ]]; then
  echo "[*] Pruning ops logs in ${OPS_LOG_DIR}..."
  find "${OPS_LOG_DIR}" -type f -name "*.log" -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true
fi

# 4. Clean ephemeral browser artifacts & temporary caches in /tmp
echo "[*] Cleaning ephemeral browser and build caches in /tmp..."
find /tmp -maxdepth 1 -name "tmp.*" -mtime +2 -exec rm -rf {} + 2>/dev/null || true
rm -rf /tmp/.org.chromium.* /tmp/core.* 2>/dev/null || true

# 5. Vacuum journalctl logs if available
if command -v journalctl >/dev/null 2>&1; then
  echo "[*] Vacuuming journalctl log retention (>200MB or >${RETENTION_DAYS}d)..."
  journalctl --user --vacuum-size=200M --vacuum-time="${RETENTION_DAYS}d" 2>/dev/null || true
fi

echo "[✓] Log hygiene completed successfully. Disk space reclaimed."
