#!/usr/bin/env bash
# ==============================================================================
# AgyFreeAgent - 24/7 Server Keep-Awake & Laptop Lid Optimizer
# Turns any Linux laptop, mini-PC, or home server into an unattended 24/7 host:
#   1. Ignores laptop lid close (no sleep, no suspend, screen off to save power).
#   2. Masks systemd sleep targets (sleep, suspend, hibernate, hybrid-sleep).
#   3. Disables Wi-Fi power saving (prevents Wi-Fi adapter sleeping on idle).
# ==============================================================================

set -euo pipefail

# Visual Palette
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
  BOLD="\033[1m"
  RESET="\033[0m"
  CYAN="\033[38;5;39m"
  GREEN="\033[38;5;78m"
  AMBER="\033[38;5;214m"
  RED="\033[38;5;203m"
  SLATE="\033[38;5;244m"
  PURPLE="\033[38;5;141m"
else
  BOLD=""
  RESET=""
  CYAN=""
  GREEN=""
  AMBER=""
  RED=""
  SLATE=""
  PURPLE=""
fi

LOGIND_DROPIN_DIR="/etc/systemd/logind.conf.d"
LOGIND_DROPIN_FILE="${LOGIND_DROPIN_DIR}/99-agy-keepawake.conf"
NM_DROPIN_DIR="/etc/NetworkManager/conf.d"
NM_DROPIN_FILE="${NM_DROPIN_DIR}/99-agy-wifi-powersave.conf"

show_status() {
  echo ""
  echo -e "${PURPLE}╭───────────────────────────────────────────────────────────────────╮${RESET}"
  echo -e "${PURPLE}│${RESET}   ${BOLD}${CYAN}✦ AgyFreeAgent Host Keep-Awake Telemetry ✦${RESET}                      ${PURPLE}│${RESET}"
  echo -e "${PURPLE}╰───────────────────────────────────────────────────────────────────╯${RESET}"
  echo ""

  # Check lid switch in logind
  echo -e "  ${BOLD}1. Systemd Logind Lid Switch:${RESET}"
  local lid_active="default (suspend)"
  if [[ -f "${LOGIND_DROPIN_FILE}" ]]; then
    lid_active="ignore (custom drop-in)"
  elif grep -q "^HandleLidSwitch=ignore" /etc/systemd/logind.conf 2>/dev/null; then
    lid_active="ignore (logind.conf)"
  fi
  echo -e "     Status: $([[ "${lid_active}" =~ "ignore" ]] && echo -e "${GREEN}✔ ${lid_active}${RESET}" || echo -e "${AMBER}● ${lid_active}${RESET}")"

  # Check sleep targets
  echo -e "\n  ${BOLD}2. Systemd Sleep Targets:${RESET}"
  for target in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
    local state
    state="$(systemctl is-enabled "${target}" 2>&1 | head -n1 || true)"
    if [[ "${state}" == "masked" ]]; then
      echo -e "     ${GREEN}✔ ${target}:${RESET} masked (system will never sleep)"
    else
      echo -e "     ${AMBER}● ${target}:${RESET} ${state:-unknown}"
    fi
  done

  # Check Wi-Fi power save
  echo -e "\n  ${BOLD}3. Wi-Fi Power Management:${RESET}"
  if command -v iwconfig &>/dev/null; then
    local wifi_ps
    wifi_ps="$(iwconfig 2>/dev/null | grep -i "power management" || echo "")"
    if [[ -n "${wifi_ps}" ]]; then
      echo -e "     Interface: ${SLATE}${wifi_ps}${RESET}"
    fi
  elif [[ -f "${NM_DROPIN_FILE}" ]]; then
    echo -e "     ${GREEN}✔ NetworkManager power save disabled via ${NM_DROPIN_FILE}${RESET}"
  else
    echo -e "     ${SLATE}Default Wi-Fi power save configuration${RESET}"
  fi
  echo ""
}

apply_keepawake() {
  echo ""
  echo -e "${PURPLE}╭───────────────────────────────────────────────────────────────────╮${RESET}"
  echo -e "${PURPLE}│${RESET}   ${BOLD}${CYAN}✦ Applying 24/7 Keep-Awake Host Configuration ✦${RESET}                 ${PURPLE}│${RESET}"
  echo -e "${PURPLE}╰───────────────────────────────────────────────────────────────────╯${RESET}"
  echo ""

  # 1. Configure systemd-logind drop-in for lid close
  echo -e "  ${CYAN}ℹ [1/3] Configuring systemd-logind lid switch to 'ignore'...${RESET}"
  sudo mkdir -p "${LOGIND_DROPIN_DIR}"
  sudo tee "${LOGIND_DROPIN_FILE}" >/dev/null << 'EOF'
[Login]
# Auto-configured by AgyFreeAgent for 24/7 host operations
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
LidSwitchIgnoreInhibited=no
EOF
  echo -e "  ${GREEN}✔ Saved drop-in configuration at ${LOGIND_DROPIN_FILE}${RESET}"

  # 2. Mask systemd sleep and suspend targets
  echo -e "  ${CYAN}ℹ [2/3] Masking kernel sleep, suspend, and hibernation targets...${RESET}"
  sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
  echo -e "  ${GREEN}✔ Sleep targets masked successfully.${RESET}"

  # 3. Disable Wi-Fi power management to prevent connection drops on idle
  echo -e "  ${CYAN}ℹ [3/3] Disabling Wi-Fi power saving (prevents radio sleeping on idle)...${RESET}"
  if command -v nmcli &>/dev/null || [[ -d "/etc/NetworkManager" ]]; then
    sudo mkdir -p "${NM_DROPIN_DIR}"
    sudo tee "${NM_DROPIN_FILE}" >/dev/null << 'EOF'
[connection]
# 2 = disable powersave, 3 = enable powersave
wifi.powersave = 2
EOF
    echo -e "  ${GREEN}✔ NetworkManager Wi-Fi powersave pinned to 2 (disabled).${RESET}"
  fi

  # Restart logind to apply lid settings immediately
  echo -e "  ${CYAN}ℹ Reloading systemd-logind daemon...${RESET}"
  sudo systemctl restart systemd-logind 2>/dev/null || true
  echo -e "  ${GREEN}✔ systemd-logind restarted successfully.${RESET}"

  echo ""
  echo -e "${GREEN}╭───────────────────────────────────────────────────────────────────╮${RESET}"
  echo -e "${GREEN}│${RESET}   ${BOLD}✦ Your machine will now run 24/7 with the lid closed! ✦${RESET}         ${GREEN}│${RESET}"
  echo -e "${GREEN}╰───────────────────────────────────────────────────────────────────╯${RESET}"
  echo ""
  echo -e "  ${SLATE}You can safely close the laptop lid or walk away.${RESET}"
  echo -e "  ${SLATE}Your AI agents, background tasks, and SSH connections will stay alive forever.${RESET}"
  echo -e "  ${SLATE}(To revert later, run: ./scripts/keep-awake.sh --revert)${RESET}"
  echo ""
}

revert_keepawake() {
  echo ""
  echo -e "${AMBER}╭───────────────────────────────────────────────────────────────────╮${RESET}"
  echo -e "${AMBER}│${RESET}   ${BOLD}✦ Reverting 24/7 Keep-Awake Configuration ✦${RESET}                     ${AMBER}│${RESET}"
  echo -e "${AMBER}╰───────────────────────────────────────────────────────────────────╯${RESET}"
  echo ""

  # Remove logind drop-in
  if [[ -f "${LOGIND_DROPIN_FILE}" ]]; then
    sudo rm -f "${LOGIND_DROPIN_FILE}"
    echo -e "  ${GREEN}✔ Removed ${LOGIND_DROPIN_FILE}${RESET}"
  fi

  # Remove NetworkManager drop-in
  if [[ -f "${NM_DROPIN_FILE}" ]]; then
    sudo rm -f "${NM_DROPIN_FILE}"
    echo -e "  ${GREEN}✔ Removed ${NM_DROPIN_FILE}${RESET}"
  fi

  # Unmask sleep targets
  echo -e "  ${CYAN}ℹ Unmasking sleep targets...${RESET}"
  sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
  echo -e "  ${GREEN}✔ Sleep targets restored to system defaults.${RESET}"

  # Restart logind
  sudo systemctl restart systemd-logind 2>/dev/null || true
  echo -e "  ${GREEN}✔ systemd-logind restarted.${RESET}"
  echo ""
  echo -e "  ${GREEN}✔ Host power configuration reverted to factory behavior.${RESET}"
  echo ""
}

# Command dispatch
ACTION="${1:-apply}"

case "${ACTION}" in
  --status|-s|status)
    show_status
    ;;
  --revert|-r|revert)
    revert_keepawake
    ;;
  --apply|-a|apply|"")
    apply_keepawake
    ;;
  --help|-h|help)
    echo "Usage: $0 [apply|status|revert]"
    echo ""
    echo "Commands:"
    echo "  apply   (default) Configure laptop lid to ignore close & mask sleep targets"
    echo "  status  Inspect current systemd lid and sleep target states"
    echo "  revert  Restore original laptop power and sleep behavior"
    echo ""
    ;;
  *)
    echo "Unknown option: ${ACTION}"
    echo "Run $0 --help for usage."
    exit 1
    ;;
esac
