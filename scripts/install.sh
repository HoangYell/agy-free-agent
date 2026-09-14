#!/usr/bin/env bash
# ==============================================================================
# AgyFreeAgent - Universal Installer & Setup Script
# "No API keys. No credit cards. Just your Google accounts."
# ==============================================================================

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"
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

# 3. Check Node.js and jq
echo "[*] Checking runtime dependencies (Node.js & jq)..."
if command -v node &>/dev/null; then
  echo "[✓] Node.js is installed ($(node -v))."
else
  echo "[!] Notice: 'node' (Node.js) is recommended for quota telemetry ('q')."
  echo "    Install via: sudo apt install -y nodejs (or https://nodejs.org)."
fi

if ! command -v jq &>/dev/null; then
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y jq 2>/dev/null || true
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y jq 2>/dev/null || true
  fi
fi

# 4. Check Git & Developer Identity
echo "[*] Checking Git & Developer Identity..."
if ! command -v git &>/dev/null; then
  echo "[!] 'git' is missing. Installing git..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y git
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y git
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm git
  fi
fi

if command -v git &>/dev/null; then
  GIT_USER="$(git config --global user.name 2>/dev/null || true)"
  GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"

  if [[ -z "${GIT_USER}" || -z "${GIT_EMAIL}" ]]; then
    echo "[!] Notice: Git author identity is incomplete."
    if [[ -t 0 ]]; then
      if [[ -z "${GIT_USER}" ]]; then
        read -r -p "    Enter your Git author name (e.g. John Doe): " input_user || true
        if [[ -n "${input_user:-}" ]]; then
          git config --global user.name "${input_user}"
          GIT_USER="${input_user}"
        fi
      fi
      if [[ -z "${GIT_EMAIL}" ]]; then
        read -r -p "    Enter your Git author email (e.g. john@example.com): " input_email || true
        if [[ -n "${input_email:-}" ]]; then
          git config --global user.email "${input_email}"
          GIT_EMAIL="${input_email}"
        fi
      fi
    fi
  fi

  if [[ -n "${GIT_USER}" && -n "${GIT_EMAIL}" ]]; then
    echo "[✓] Git identity configured: ${GIT_USER} <${GIT_EMAIL}>"
  else
    echo "[!] WARNING: Git author identity is not set."
    echo "    Autonomous agents will fail when running 'git commit' unless you configure:"
    echo "      git config --global user.name \"Your Name\""
    echo "      git config --global user.email \"your.email@example.com\""
  fi

  # Check GitHub Authentication (SSH or gh)
  if [[ -f "${HOME}/.ssh/id_ed25519" || -f "${HOME}/.ssh/id_rsa" ]] || (command -v gh &>/dev/null && gh auth status &>/dev/null); then
    echo "[✓] GitHub authentication detected (SSH key or gh CLI)."
  else
    echo "[*] Tip: For seamless autonomous git push/pull without password prompts:"
    echo "    - Setup GitHub CLI:  gh auth login"
    echo "    - Or create SSH key: ssh-keygen -t ed25519 -C \"${GIT_EMAIL:-git@agent}\""
  fi
fi

# 5. Check agy binary
echo "[*] Checking Google Antigravity CLI (agy)..."
if command -v agy &>/dev/null || [[ -x "${BIN_DIR}/agy" ]]; then
  echo "[✓] 'agy' CLI binary detected."
else
  echo "[!] Notice: 'agy' command not found in PATH or ${BIN_DIR}."
  echo "    Get Antigravity CLI from https://antigravity.google or copy 'agy' to ~/.local/bin/agy."
fi

# 6. Create target directories
mkdir -p "${BIN_DIR}"
mkdir -p "${PROFILES_BASE}"
mkdir -p "${WORKSPACES_DIR}"

# 7. Initialize .env from .env.example
if [[ ! -f "${ROOT_DIR}/.env" && -f "${ROOT_DIR}/.env.example" ]]; then
  cp "${ROOT_DIR}/.env.example" "${ROOT_DIR}/.env"
  echo "[✓] Initialized .env template."
fi

# 8. Link CLI tools into ~/.local/bin
echo "[*] Linking CLI tools into ${BIN_DIR}..."
ln -sf "${ROOT_DIR}/bin/agy-setup" "${BIN_DIR}/agy-setup"
ln -sf "${ROOT_DIR}/bin/q" "${BIN_DIR}/q"
ln -sf "${ROOT_DIR}/bin/cleanroom-guard" "${BIN_DIR}/cleanroom-guard"
ln -sf "${ROOT_DIR}/bin/agy-clean-logs" "${BIN_DIR}/agy-clean-logs"
ln -sf "${ROOT_DIR}/bin/telegram-notify" "${BIN_DIR}/telegram-notify"

chmod +x "${ROOT_DIR}/bin/agy-setup" "${ROOT_DIR}/bin/q" "${ROOT_DIR}/bin/cleanroom-guard" "${ROOT_DIR}/bin/agy-clean-logs" "${ROOT_DIR}/bin/telegram-notify" "${ROOT_DIR}/scripts/clean-logs.sh" "${ROOT_DIR}/scripts/telegram-notify.sh"

# 9. Ensure ~/.local/bin is in PATH automatically
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "[*] Configuring ~/.local/bin in shell configuration..."
  if [[ -f "${HOME}/.bashrc" ]] && ! grep -q 'export PATH=.*\.local/bin' "${HOME}/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
    echo "[✓] Added to ~/.bashrc"
  fi
  if [[ -f "${HOME}/.zshrc" ]] && ! grep -q 'export PATH=.*\.local/bin' "${HOME}/.zshrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.zshrc"
    echo "[✓] Added to ~/.zshrc"
  fi
  export PATH="${BIN_DIR}:${PATH}"
fi

# 10. Initialize agy1 (Primary profile)
echo "[*] Initializing Primary Profile (agy1)..."
"${ROOT_DIR}/bin/agy-setup" 1

# 11. Copy default persona GEMINI.md to ~/GEMINI.md if not present
if [[ ! -f "${HOME}/GEMINI.md" && -f "${ROOT_DIR}/templates/GEMINI.md" ]]; then
  echo "[*] Deploying battle-tested autonomous engineer persona to ~/GEMINI.md..."
  cp "${ROOT_DIR}/templates/GEMINI.md" "${HOME}/GEMINI.md"
fi

# 12. Setup git pre-commit hook in repo if in git
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
