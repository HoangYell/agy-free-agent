#!/usr/bin/env bash
# ==============================================================================
# AgyFreeAgent - Sudo All Provisioner
# Grants passwordless sudo access to allow autonomous AI engineering agents
# to install dependencies, manage services, and execute system commands.
# ==============================================================================

set -euo pipefail

CURRENT_USER="$(whoami)"
SUDOERS_FILE="/etc/sudoers.d/agy-agent"

echo "=========================================================="
echo "          AgyFreeAgent Sudo All Configuration             "
echo "=========================================================="
echo ""
echo "Autonomous agents often need to:"
echo "  - Install system packages (apt-get, dnf, pacman)"
echo "  - Manage systemd daemons & docker containers"
echo "  - Inspect networking and system logs"
echo ""
echo "Without passwordless sudo, background agents hang waiting for user passwords."
echo ""

if [[ $EUID -eq 0 ]]; then
  TARGET_USER="${SUDO_USER:-$CURRENT_USER}"
else
  TARGET_USER="$CURRENT_USER"
fi

echo "[*] Configuring NOPASSWD for user: ${TARGET_USER}"

TMP_FILE="$(mktemp)"
cat << EOF > "${TMP_FILE}"
# AgyFreeAgent - Unhindered autonomous execution for ${TARGET_USER}
${TARGET_USER} ALL=(ALL) NOPASSWD: ALL
EOF

echo "[*] Validating sudoers syntax via visudo..."
if command -v visudo &>/dev/null; then
  visudo -cf "${TMP_FILE}"
fi

echo "[*] Installing to ${SUDOERS_FILE}..."
if [[ $EUID -eq 0 ]]; then
  cp "${TMP_FILE}" "${SUDOERS_FILE}"
  chmod 0440 "${SUDOERS_FILE}"
else
  sudo cp "${TMP_FILE}" "${SUDOERS_FILE}"
  sudo chmod 0440 "${SUDOERS_FILE}"
fi
rm -f "${TMP_FILE}"

echo ""
echo "[✓] Passwordless sudo successfully enabled for '${TARGET_USER}'!"
echo "Verification: Testing 'sudo whoami'..."
sudo whoami
echo "[✓] Verification succeeded. Your agent can now execute system engineering commands without hanging."
