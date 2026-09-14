#!/usr/bin/env bash
# ==============================================================================
# AgyFreeAgent - Linux Kernel Swappiness Optimizer
# Tunes vm.swappiness to 20 to prevent premature swap thrashing during heavy
# autonomous compilations (Rust, TypeScript, large monorepos).
# ==============================================================================

set -euo pipefail

TARGET_SWAPPINESS=20
CURRENT_SWAPPINESS="$(cat /proc/sys/vm/swappiness 2>/dev/null || echo 60)"

echo "=========================================================="
echo "          AgyFreeAgent Kernel Swappiness Optimizer        "
echo "=========================================================="
echo "[*] Current vm.swappiness: ${CURRENT_SWAPPINESS}"
echo "[*] Target vm.swappiness:  ${TARGET_SWAPPINESS}"

if [[ "${CURRENT_SWAPPINESS}" -eq "${TARGET_SWAPPINESS}" ]]; then
  echo "[✓] Kernel swappiness is already optimized for agent performance."
  exit 0
fi

echo "[*] Applying vm.swappiness=${TARGET_SWAPPINESS}..."

if [[ $EUID -eq 0 ]]; then
  sysctl -w vm.swappiness="${TARGET_SWAPPINESS}"
  echo "vm.swappiness = ${TARGET_SWAPPINESS}" > /etc/sysctl.d/99-agy-swappiness.conf
else
  sudo sysctl -w vm.swappiness="${TARGET_SWAPPINESS}"
  echo "vm.swappiness = ${TARGET_SWAPPINESS}" | sudo tee /etc/sysctl.d/99-agy-swappiness.conf > /dev/null
fi

echo "[✓] Successfully tuned vm.swappiness to ${TARGET_SWAPPINESS} (persisted in /etc/sysctl.d/99-agy-swappiness.conf)."
echo "    Your host will now prioritize fast physical RAM over slow disk swap during agent builds."
