#!/usr/bin/env bash
# ==============================================================================
# AgyFreeAgent - Clean Uninstaller
# Safely removes CLI symlinks, profile wrappers, and sudoers configs.
# Note: Your project code in ~/workspaces is NEVER deleted.
# ==============================================================================

set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
PROFILES_BASE="${HOME}/.gemini-profiles"
SUDOERS_FILE="/etc/sudoers.d/agy-agent"

# Colors
GREEN="\033[38;5;78m"
AMBER="\033[38;5;214m"
RED="\033[38;5;203m"
CYAN="\033[38;5;39m"
BOLD="\033[1m"
RESET="\033[0m"

echo ""
echo -e "${AMBER}╭───────────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${AMBER}│${RESET}   ${BOLD}✦ AgyFreeAgent Uninstaller ✦${RESET}                                   ${AMBER}│${RESET}"
echo -e "${AMBER}╰───────────────────────────────────────────────────────────────────╯${RESET}"
echo ""
echo "This script will remove:"
echo "  1. CLI tool symlinks in ${BIN_DIR} (agy1..agyn, agy-setup, q, etc.)"
echo "  2. (Optional) Passwordless sudoers rule at ${SUDOERS_FILE}"
echo "  3. (Optional) Multi-profile session folders at ${PROFILES_BASE}"
echo ""
echo -e "  ${GREEN}✔ Note:${RESET} Your personal code in ~/workspaces will NOT be touched."
echo ""

read -r -p "Are you sure you want to proceed? [y/N]: " confirm || true
if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
  echo "Uninstallation cancelled."
  exit 0
fi

echo ""
echo "[*] Removing CLI symlinks and profile wrappers in ${BIN_DIR}..."
rm -f "${BIN_DIR}/agy-setup"
rm -f "${BIN_DIR}/q"
rm -f "${BIN_DIR}/cleanroom-guard"
rm -f "${BIN_DIR}/agy-clean-logs"
rm -f "${BIN_DIR}/telegram-notify"
rm -f "${BIN_DIR}/post-to-x"
rm -f "${BIN_DIR}/agy"[0-9]* 2>/dev/null || true
echo -e "  ${GREEN}✔ CLI symlinks removed.${RESET}"

if [[ -f "${SUDOERS_FILE}" ]]; then
  echo ""
  read -r -p "Remove passwordless sudoers rule (${SUDOERS_FILE})? [y/N]: " rm_sudo || true
  if [[ "${rm_sudo}" =~ ^[Yy]$ ]]; then
    sudo rm -f "${SUDOERS_FILE}"
    echo -e "  ${GREEN}✔ Removed ${SUDOERS_FILE}.${RESET}"
  fi
fi

if [[ -d "${PROFILES_BASE}" ]]; then
  echo ""
  read -r -p "Remove multi-profile session storage (${PROFILES_BASE})? [y/N]: " rm_profiles || true
  if [[ "${rm_profiles}" =~ ^[Yy]$ ]]; then
    rm -rf "${PROFILES_BASE}"
    echo -e "  ${GREEN}✔ Removed ${PROFILES_BASE}.${RESET}"
  fi
fi

echo ""
echo -e "${GREEN}╭───────────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${GREEN}│${RESET}   ${BOLD}✦ AgyFreeAgent uninstallation complete. ✦${RESET}                      ${GREEN}│${RESET}"
echo -e "${GREEN}╰───────────────────────────────────────────────────────────────────╯${RESET}"
echo ""
