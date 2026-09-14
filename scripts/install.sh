#!/usr/bin/env bash
# ==============================================================================
# AgyFreeAgent - Universal Installer & Setup Script
# "No API keys. No credit cards. Just your Google accounts."
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${HOME}/.local/bin"
PROFILES_BASE="${HOME}/.gemini-profiles"
WORKSPACES_DIR="${HOME}/workspaces"

echo "=========================================================="
echo "          AgyFreeAgent Installer & Quickstart             "
echo "  The Autonomous AI Engineer for Linux (Zero API Keys)    "
echo "=========================================================="
echo ""

# 1. Check OS
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "[!] Note: AgyFreeAgent multi-profile isolation utilizes Linux bubblewrap."
  echo "    On macOS/Windows, use WSL2 (Windows Subsystem for Linux) or a Linux VM."
fi

# 2. Check & Install Bubblewrap
echo "[*] Checking Linux user-space namespace tool (bubblewrap)..."
if ! command -v bwrap &>/dev/null; then
  echo "[!] 'bwrap' is missing. Attempting to install via package manager..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y bubblewrap
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y bubblewrap
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm bubblewrap
  else
    echo "[!] Please install 'bubblewrap' manually on your system."
  fi
fi

if command -v bwrap &>/dev/null; then
  echo "[✓] bubblewrap is installed ($(bwrap --version 2>/dev/null || echo 'ready'))."
else
  echo "[!] Warning: bwrap could not be verified. Multi-profile may fail without bwrap."
fi

# 3. Check agy binary
echo "[*] Checking Google Antigravity CLI (agy)..."
if command -v agy &>/dev/null || [[ -x "${BIN_DIR}/agy" ]]; then
  echo "[✓] 'agy' CLI binary detected."
else
  echo "[!] Notice: 'agy' command not found in PATH or ${BIN_DIR}."
  echo "    Get Antigravity CLI from https://antigravity.google.com or copy 'agy' to ~/.local/bin/agy."
fi

# 4. Create target directories
mkdir -p "${BIN_DIR}"
mkdir -p "${PROFILES_BASE}"
mkdir -p "${WORKSPACES_DIR}"

# 4. Link CLI tools into ~/.local/bin
echo "[*] Linking CLI tools into ${BIN_DIR}..."
ln -sf "${ROOT_DIR}/bin/agy-setup" "${BIN_DIR}/agy-setup"
ln -sf "${ROOT_DIR}/bin/q" "${BIN_DIR}/q"
ln -sf "${ROOT_DIR}/bin/cleanroom-guard" "${BIN_DIR}/cleanroom-guard"
ln -sf "${ROOT_DIR}/bin/agy-clean-logs" "${BIN_DIR}/agy-clean-logs"
ln -sf "${ROOT_DIR}/bin/telegram-notify" "${BIN_DIR}/telegram-notify"

chmod +x "${ROOT_DIR}/bin/agy-setup" "${ROOT_DIR}/bin/q" "${ROOT_DIR}/bin/cleanroom-guard" "${ROOT_DIR}/bin/agy-clean-logs" "${ROOT_DIR}/bin/telegram-notify" "${ROOT_DIR}/scripts/clean-logs.sh" "${ROOT_DIR}/scripts/telegram-notify.sh"

# Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "[!] Tip: Add ~/.local/bin to your PATH in ~/.bashrc or ~/.zshrc:"
  echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# 5. Initialize agy1 (Primary profile)
echo "[*] Initializing Primary Profile (agy1)..."
"${ROOT_DIR}/bin/agy-setup" 1

# 6. Copy default persona GEMINI.md to ~/GEMINI.md if not present
if [[ ! -f "${HOME}/GEMINI.md" && -f "${ROOT_DIR}/templates/GEMINI.md" ]]; then
  echo "[*] Deploying battle-tested autonomous engineer persona to ~/GEMINI.md..."
  cp "${ROOT_DIR}/templates/GEMINI.md" "${HOME}/GEMINI.md"
fi

# 7. Setup git pre-commit hook in repo if in git
if [[ -d "${ROOT_DIR}/.git" ]]; then
  echo "[*] Installing clean-room pre-commit shield..."
  cat << 'HOOK' > "${ROOT_DIR}/.git/hooks/pre-commit"
#!/usr/bin/env bash
exec ./bin/cleanroom-guard
HOOK
  chmod +x "${ROOT_DIR}/.git/hooks/pre-commit"
fi

echo ""
echo "=========================================================="
echo "          [✓] AgyFreeAgent Installation Complete!         "
echo "=========================================================="
echo ""
echo "Quickstart Commands:"
echo "  1. Launch Primary Profile:   agy1  (or agy)"
echo "  2. Provision New Profile:    agy-setup 2 (adds account 2 -> command agy2)"
echo "  3. Check Live Quotas:        q"
echo "  4. Setup Sudo Permissions:   ./scripts/setup-sudo.sh"
echo ""
echo "All your coding projects should live in: ~/workspaces/<project-name>"
echo "Happy hacking with full autonomous engineering!"
echo ""
