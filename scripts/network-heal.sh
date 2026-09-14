#!/usr/bin/env bash
# ==============================================================================
# AgyFreeAgent - Network Self-Healing & Auto-Recovery
# Detects connection drops during unattended agent tasks and autonomously
# triggers adapter refresh or gateway reconnection.
# ==============================================================================

set -euo pipefail

CHECK_HOSTS=("1.1.1.1" "8.8.8.8")
CONNECTED=false

for host in "${CHECK_HOSTS[@]}"; do
  if ping -c 2 -W 3 "$host" &>/dev/null; then
    CONNECTED=true
    break
  fi
done

if [[ "$CONNECTED" == "true" ]]; then
  echo "[✓] Network connectivity is healthy."
  exit 0
fi

echo "[!] Connection loss detected. Initiating network self-healing..."

# 1. Try restarting NetworkManager or networking service
if command -v systemctl &>/dev/null; then
  echo "[*] Restarting networking services..."
  sudo systemctl restart NetworkManager 2>/dev/null || sudo systemctl restart systemd-networkd 2>/dev/null || true
fi

sleep 5

# 2. Re-verify connectivity
for host in "${CHECK_HOSTS[@]}"; do
  if ping -c 2 -W 3 "$host" &>/dev/null; then
    echo "[✓] Network successfully restored!"
    exit 0
  fi
done

echo "[!] Automatic reconnect failed. Check physical link or router upstream."
exit 1
