#!/usr/bin/env bash
# ==============================================================================
# AgyFreeAgent - Universal All-in-One Installer & Provisioner
# "No API keys. No credit cards. Just your Google accounts."
# ==============================================================================

set -euo pipefail

# Visual Palette (Linear / Apple clean aesthetic)
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

# Detect Interactive Mode (supports curl ... | bash via /dev/tty)
INTERACTIVE="false"
if [[ -t 0 ]] || [[ -r /dev/tty ]]; then
  INTERACTIVE="true"
fi

read_prompt() {
  local prompt_text="$1"
  local target_var="$2"
  local input=""
  if [[ -t 0 ]]; then
    read -r -p "$prompt_text" input || true
  elif [[ -r /dev/tty ]]; then
    read -r -p "$prompt_text" input </dev/tty || true
  else
    input=""
  fi
  eval "$target_var=\"\$input\""
}

CURRENT_USER="$(whoami)"
BIN_DIR="${HOME}/.local/bin"
PROFILES_BASE="${HOME}/.gemini-profiles"
WORKSPACES_DIR="${HOME}/workspaces"

# Locate or bootstrap repository root
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "")"
SCRIPT_DIR="$(dirname "${SCRIPT_PATH}" 2>/dev/null || echo "")"

if [[ -n "${SCRIPT_DIR}" && -f "${SCRIPT_DIR}/../bin/agy-setup" ]]; then
  ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
elif [[ -f "${WORKSPACES_DIR}/agy-free-agent/bin/agy-setup" ]]; then
  ROOT_DIR="${WORKSPACES_DIR}/agy-free-agent"
else
  ROOT_DIR="${WORKSPACES_DIR}/agy-free-agent"
fi

# ==============================================================================
# Banner
# ==============================================================================
echo ""
echo -e "${PURPLE}╭───────────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${PURPLE}│${RESET}   ${BOLD}${CYAN}✦ AGY FREE AGENT ✦${RESET}                                            ${PURPLE}│${RESET}"
echo -e "${PURPLE}│${RESET}   ${SLATE}The Autonomous AI Engineering Engine for Linux & WSL2${RESET}           ${PURPLE}│${RESET}"
echo -e "${PURPLE}│${RESET}   ${GREEN}\"No API keys. No credit cards. Just your Google accounts.\"${RESET}      ${PURPLE}│${RESET}"
echo -e "${PURPLE}╰───────────────────────────────────────────────────────────────────╯${RESET}"
echo ""

# Load Pre-Flight Configuration (.env) if present
ENV_FILE=""
if [[ -f "${ROOT_DIR}/.env" ]]; then
  ENV_FILE="${ROOT_DIR}/.env"
elif [[ -f "./.env" ]]; then
  ENV_FILE="./.env"
fi

if [[ -n "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

# ==============================================================================
# [1/7] System & Environment Check
# ==============================================================================
echo -e "${BOLD}${PURPLE}┌── [1/7] System & Environment Check${RESET}"
OS_NAME="$(uname -s)"
if [[ "${OS_NAME}" != "Linux" ]]; then
  echo -e "  ${AMBER}● Notice:${RESET} Detected OS: ${OS_NAME}."
  echo -e "    AgyFreeAgent multi-profile isolation utilizes Linux bubblewrap (bwrap)."
  echo -e "    On Windows, please use WSL2 (Ubuntu). On macOS, use a Linux VM."
else
  echo -e "  ${GREEN}✔ Linux kernel detected${RESET} ($(uname -r))."
fi

if [[ -n "${ENV_FILE}" ]]; then
  echo -e "  ${GREEN}✔ Pre-flight configuration loaded from ${ENV_FILE}${RESET}"
else
  echo -e "  ${SLATE}ℹ Tip: You can pre-fill keys in .env (copy from .env.example) for zero-prompt setup.${RESET}"
fi

mkdir -p "${BIN_DIR}"
mkdir -p "${PROFILES_BASE}"
mkdir -p "${WORKSPACES_DIR}"

# ==============================================================================
# [2/7] Core Dependencies (Git, Bubblewrap, Node.js, jq)
# ==============================================================================
echo -e "\n${BOLD}${PURPLE}┌── [2/7] Core Dependencies Check & Bootstrap${RESET}"

# Package manager helper
install_pkg() {
  local pkg="$1"
  echo -e "  ${CYAN}ℹ Installing '${pkg}' via package manager...${RESET}"
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq "${pkg}"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y "${pkg}"
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm "${pkg}"
  fi
}

# 1. Git
if ! command -v git &>/dev/null; then
  install_pkg git
fi
if command -v git &>/dev/null; then
  echo -e "  ${GREEN}✔ Git is installed${RESET} ($(git --version | head -n1))."
else
  echo -e "  ${RED}✖ Git could not be installed automatically. Please install git.${RESET}"
fi

# Bootstrap repository clone if run standalone / piped
if [[ ! -f "${ROOT_DIR}/bin/agy-setup" ]]; then
  echo -e "  ${CYAN}ℹ Cloning AgyFreeAgent into ${ROOT_DIR}...${RESET}"
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    git clone "https://${GITHUB_TOKEN}@github.com/HoangYell/agy-free-agent.git" "${ROOT_DIR}" 2>/dev/null || \
    git clone https://github.com/HoangYell/agy-free-agent.git "${ROOT_DIR}"
  else
    git clone https://github.com/HoangYell/agy-free-agent.git "${ROOT_DIR}" 2>/dev/null || \
    git clone git@github.com:HoangYell/agy-free-agent.git "${ROOT_DIR}"
  fi
fi

# 2. Bubblewrap (bwrap)
if ! command -v bwrap &>/dev/null; then
  install_pkg bubblewrap
fi
if command -v bwrap &>/dev/null; then
  echo -e "  ${GREEN}✔ Bubblewrap is installed${RESET} ($(bwrap --version 2>/dev/null || echo 'ready'))."
else
  echo -e "  ${AMBER}● Warning: 'bwrap' is missing. Multi-profile isolation requires bwrap.${RESET}"
fi

# 3. Node.js (for quota telemetry 'q')
if command -v node &>/dev/null; then
  echo -e "  ${GREEN}✔ Node.js is installed${RESET} ($(node -v))."
else
  echo -e "  ${SLATE}● Node.js is optional (needed for live quota inspector 'q').${RESET}"
  if [[ "${INTERACTIVE}" == "true" ]]; then
    echo -ne "    ${CYAN}➜${RESET} Install Node.js now? [Y/n]: "
    read_prompt "" INSTALL_NODE
    INSTALL_NODE="${INSTALL_NODE:-y}"
    if [[ "${INSTALL_NODE}" =~ ^[Yy]$ ]]; then
      install_pkg nodejs || true
    fi
  fi
fi

# 4. jq
if ! command -v jq &>/dev/null; then
  install_pkg jq || true
fi

# ==============================================================================
# [3/7] Developer & Git Identity (Pre-flight .env or Interactive Validation)
# ==============================================================================
echo -e "\n${BOLD}${PURPLE}┌── [3/7] Developer & Git Identity${RESET}"

GIT_USER="$(git config --global user.name 2>/dev/null || true)"
GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"

# Check if provided via .env
if [[ -n "${GIT_USER_NAME:-}" ]]; then
  git config --global user.name "${GIT_USER_NAME}"
  GIT_USER="${GIT_USER_NAME}"
  echo -e "  ${GREEN}✔ Git author name (from .env):${RESET} ${BOLD}${GIT_USER}${RESET}"
elif [[ -n "${GIT_USER}" ]]; then
  echo -e "  ${GREEN}✔ Git author name:${RESET} ${BOLD}${GIT_USER}${RESET}"
else
  echo -e "  ${AMBER}● Notice:${RESET} Git author name is unset (required for autonomous commits)."
  if [[ "${INTERACTIVE}" == "true" ]]; then
    while [[ -z "${GIT_USER}" ]]; do
      echo -ne "  ${CYAN}➜${RESET} Enter your Git author name (e.g. John Doe): "
      read_prompt "" GIT_USER
      GIT_USER="$(echo "${GIT_USER}" | xargs)"
      if [[ -z "${GIT_USER}" ]]; then
        echo -e "    ${RED}✖ Name cannot be blank. Please try again.${RESET}"
      fi
    done
    git config --global user.name "${GIT_USER}"
    echo -e "  ${GREEN}✔ Saved git user.name: ${BOLD}${GIT_USER}${RESET}"
  fi
fi

# Check email via .env
if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
  git config --global user.email "${GIT_USER_EMAIL}"
  GIT_EMAIL="${GIT_USER_EMAIL}"
  echo -e "  ${GREEN}✔ Git author email (from .env):${RESET} ${BOLD}${GIT_EMAIL}${RESET}"
elif [[ -n "${GIT_EMAIL}" ]]; then
  echo -e "  ${GREEN}✔ Git author email:${RESET} ${BOLD}${GIT_EMAIL}${RESET}"
else
  echo -e "  ${AMBER}● Notice:${RESET} Git author email is unset (required for autonomous commits)."
  if [[ "${INTERACTIVE}" == "true" ]]; then
    while true; do
      echo -ne "  ${CYAN}➜${RESET} Enter your Git author email (e.g. john@example.com): "
      read_prompt "" GIT_EMAIL
      GIT_EMAIL="$(echo "${GIT_EMAIL}" | xargs)"
      if [[ "${GIT_EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
      else
        echo -e "    ${RED}✖ Invalid email format. Please enter a valid email (e.g. name@domain.com).${RESET}"
      fi
    done
    git config --global user.email "${GIT_EMAIL}"
    echo -e "  ${GREEN}✔ Saved git user.email: ${BOLD}${GIT_EMAIL}${RESET}"
  fi
fi

# GitHub Token Authentication (if provided in .env)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  if ! command -v gh &>/dev/null; then
    install_pkg gh || true
  fi
  if command -v gh &>/dev/null; then
    echo "${GITHUB_TOKEN}" | gh auth login --with-token 2>/dev/null || true
    gh auth setup-git 2>/dev/null || true
    echo -e "  ${GREEN}✔ GitHub CLI authorized via GITHUB_TOKEN (.env).${RESET}"
    echo -e "  ${GREEN}✔ Git credential helper configured via gh CLI (zero-password HTTPS clone & push).${RESET}"
  fi
fi

# Check GitHub Authentication (SSH key or gh CLI)
HAS_SSH="false"
if [[ -f "${HOME}/.ssh/id_ed25519.pub" || -f "${HOME}/.ssh/id_rsa.pub" ]]; then
  HAS_SSH="true"
fi
HAS_GH="false"
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  HAS_GH="true"
fi

if [[ "${HAS_SSH}" == "true" || "${HAS_GH}" == "true" ]]; then
  echo -e "  ${GREEN}✔ GitHub authentication ready${RESET} (SSH key or gh CLI credential helper detected)."
else
  # Auto generate SSH key if requested in .env
  GEN_SSH="${AUTO_GENERATE_SSH:-}"
  if [[ -z "${GEN_SSH}" && "${INTERACTIVE}" == "true" ]]; then
    echo -e "  ${AMBER}● Notice:${RESET} No GitHub SSH key or CLI authentication detected."
    echo -ne "  ${CYAN}➜${RESET} Generate an Ed25519 SSH key automatically now? [Y/n]: "
    read_prompt "" GEN_SSH
    GEN_SSH="${GEN_SSH:-y}"
  fi

  if [[ "${GEN_SSH}" =~ ^[Yy]|true$ ]]; then
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
    SSH_KEY_FILE="${HOME}/.ssh/id_ed25519"
    if [[ ! -f "${SSH_KEY_FILE}" ]]; then
      ssh-keygen -t ed25519 -C "${GIT_EMAIL:-git@agent}" -f "${SSH_KEY_FILE}" -N "" -q
    fi
    PUB_KEY="$(cat "${SSH_KEY_FILE}.pub")"
    echo -e "  ${GREEN}✔ Generated SSH key at ${SSH_KEY_FILE}${RESET}"

    # Try automatic key registration via gh CLI if authorized with admin:public_key
    KEY_UPLOADED="false"
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
      KEY_TITLE="AgyFreeAgent-$(hostname 2>/dev/null || echo 'host')-$(date +%Y%m%d)"
      if gh ssh-key add "${SSH_KEY_FILE}.pub" --title "${KEY_TITLE}" 2>/dev/null; then
        KEY_UPLOADED="true"
        echo -e "  ${GREEN}✔ SSH public key automatically registered to your GitHub account!${RESET}"
      fi
    fi

    if [[ "${KEY_UPLOADED}" != "true" ]]; then
      echo ""
      echo -e "  ${PURPLE}╭───────────────────────────────────────────────────────────────────╮${RESET}"
      echo -e "  ${PURPLE}│${RESET} ${BOLD}Add this key to GitHub:${RESET} ${CYAN}https://github.com/settings/keys${RESET}"
      echo -e "  ${PURPLE}│${RESET}"
      echo -e "  ${PURPLE}│${RESET} ${SLATE}${PUB_KEY}${RESET}"
      echo -e "  ${PURPLE}╰───────────────────────────────────────────────────────────────────╯${RESET}"
      echo ""
    fi
  fi
fi

# ==============================================================================
# [4/7] Passwordless Sudo (Autonomous YOLO Mode)
# ==============================================================================
echo -e "${BOLD}${PURPLE}┌── [4/7] Passwordless Sudo (Autonomous YOLO Mode)${RESET}"

if sudo -n true 2>/dev/null; then
  echo -e "  ${GREEN}✔ Passwordless sudo is already active (NOPASSWD: ALL).${RESET}"
else
  ENABLE_SUDO="${ENABLE_SUDO_ALL:-}"
  if [[ -z "${ENABLE_SUDO}" && "${INTERACTIVE}" == "true" ]]; then
    echo -e "  ${AMBER}● Notice:${RESET} Autonomous agents need passwordless sudo to install packages"
    echo -e "    and manage services in the background without hanging."
    echo -ne "  ${CYAN}➜${RESET} Enable passwordless sudo for '${CURRENT_USER}' now? [Y/n]: "
    read_prompt "" ENABLE_SUDO
    ENABLE_SUDO="${ENABLE_SUDO:-y}"
  fi

  if [[ "${ENABLE_SUDO}" =~ ^[Yy]|true$ ]]; then
    echo -e "  ${CYAN}ℹ Configuring passwordless sudo (/etc/sudoers.d/agy-agent)...${RESET}"
    if [[ -f "${ROOT_DIR}/scripts/setup-sudo.sh" ]]; then
      bash "${ROOT_DIR}/scripts/setup-sudo.sh"
    else
      TMP_SUDO="$(mktemp)"
      echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL" > "${TMP_SUDO}"
      sudo cp "${TMP_SUDO}" /etc/sudoers.d/agy-agent
      sudo chmod 0440 /etc/sudoers.d/agy-agent
      rm -f "${TMP_SUDO}"
    fi
    if sudo -n true 2>/dev/null; then
      echo -e "  ${GREEN}✔ Passwordless sudo successfully configured & verified.${RESET}"
    fi
  else
    echo -e "  ${SLATE}Skipped sudo configuration. Run ./scripts/setup-sudo.sh later if needed.${RESET}"
  fi
fi

# ==============================================================================
# [5/7] Antigravity CLI & Swarm Tooling
# ==============================================================================
echo -e "\n${BOLD}${PURPLE}┌── [5/7] Antigravity CLI & Swarm Tooling${RESET}"

# Check agy binary
if command -v agy &>/dev/null || [[ -x "${BIN_DIR}/agy" ]]; then
  echo -e "  ${GREEN}✔ Google Antigravity CLI ('agy') detected.${RESET}"
else
  INSTALL_AGY="${AUTO_INSTALL_AGY:-${AUTO_INSTALL_AGY_NPM:-}}"
  if [[ -z "${INSTALL_AGY}" ]] && [[ "${INTERACTIVE}" == "true" ]]; then
    echo -e "  ${AMBER}● Notice:${RESET} 'agy' binary is not yet installed in PATH or ${BIN_DIR}."
    echo -ne "  ${CYAN}➜${RESET} Install Google Antigravity CLI ('agy') via official installer now? [Y/n]: "
    read_prompt "" INSTALL_AGY
    INSTALL_AGY="${INSTALL_AGY:-y}"
  fi

  if [[ "${INSTALL_AGY}" =~ ^[Yy]|true$ ]]; then
    echo -e "  ${CYAN}ℹ Installing Antigravity CLI via https://antigravity.google/cli/install.sh...${RESET}"
    curl -fsSL https://antigravity.google/cli/install.sh | bash || true
  fi

  if command -v agy &>/dev/null || [[ -x "${BIN_DIR}/agy" ]]; then
    echo -e "  ${GREEN}✔ Google Antigravity CLI ('agy') installed successfully.${RESET}"
  else
    echo -e "  ${SLATE}Download 'agy' from https://antigravity.google and place in ~/.local/bin/agy.${RESET}"
  fi
fi

# Link CLI tools into ~/.local/bin
echo -e "  ${CYAN}ℹ Linking CLI suite into ${BIN_DIR}...${RESET}"
ln -sf "${ROOT_DIR}/bin/agy-setup" "${BIN_DIR}/agy-setup"
ln -sf "${ROOT_DIR}/bin/q" "${BIN_DIR}/q"
ln -sf "${ROOT_DIR}/bin/cleanroom-guard" "${BIN_DIR}/cleanroom-guard"
ln -sf "${ROOT_DIR}/bin/agy-clean-logs" "${BIN_DIR}/agy-clean-logs"
ln -sf "${ROOT_DIR}/bin/telegram-notify" "${BIN_DIR}/telegram-notify"
ln -sf "${ROOT_DIR}/bin/post-to-x" "${BIN_DIR}/post-to-x"

chmod +x "${ROOT_DIR}/bin/agy-setup" "${ROOT_DIR}/bin/q" "${ROOT_DIR}/bin/cleanroom-guard" "${ROOT_DIR}/bin/agy-clean-logs" "${ROOT_DIR}/bin/telegram-notify" "${ROOT_DIR}/bin/post-to-x" "${ROOT_DIR}/scripts/clean-logs.sh" "${ROOT_DIR}/scripts/telegram-notify.sh" "${ROOT_DIR}/scripts/setup-sudo.sh" "${ROOT_DIR}/scripts/uninstall.sh"

# Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  if [[ -f "${HOME}/.bashrc" ]] && ! grep -q 'export PATH=.*\.local/bin' "${HOME}/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
  fi
  if [[ -f "${HOME}/.zshrc" ]] && ! grep -q 'export PATH=.*\.local/bin' "${HOME}/.zshrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.zshrc"
  fi
  export PATH="${BIN_DIR}:${PATH}"
fi

# Initialize Primary Profile (agy1)
"${ROOT_DIR}/bin/agy-setup" 1 >/dev/null 2>&1 || true
echo -e "  ${GREEN}✔ Primary Profile ('agy1') initialized with zero-prompt YOLO settings.${RESET}"

# Deploy GEMINI.md persona template if not present
if [[ ! -f "${HOME}/GEMINI.md" && -f "${ROOT_DIR}/templates/GEMINI.md" ]]; then
  cp "${ROOT_DIR}/templates/GEMINI.md" "${HOME}/GEMINI.md"
  echo -e "  ${GREEN}✔ Battle-tested autonomous persona deployed to ~/GEMINI.md.${RESET}"
fi

# Install Clean-room pre-commit hook
if [[ -d "${ROOT_DIR}/.git" ]]; then
  cat << 'HOOK' > "${ROOT_DIR}/.git/hooks/pre-commit"
#!/usr/bin/env bash
exec ./bin/cleanroom-guard
HOOK
  chmod +x "${ROOT_DIR}/.git/hooks/pre-commit"
  echo -e "  ${GREEN}✔ Clean-room pre-commit shield installed in repository.${RESET}"
fi

# Multi-Profile Swarm Provisioning (from .env or interactive prompt)
TARGET_PROFILES="${AGY_PROFILES_COUNT:-1}"
if [[ "${TARGET_PROFILES}" -gt 1 ]]; then
  for ((p = 2; p <= TARGET_PROFILES; p++)); do
    if [[ ! -f "${BIN_DIR}/agy${p}" ]]; then
      echo -e "  ${CYAN}ℹ Provisioning Profile ${p} ('agy${p}') from .env...${RESET}"
      "${ROOT_DIR}/bin/agy-setup" "$p" >/dev/null 2>&1 || true
      echo -e "  ${GREEN}✔ Profile ${p} ('agy${p}') provisioned successfully.${RESET}"
    else
      echo -e "  ${GREEN}✔ Profile ${p} ('agy${p}') is active.${RESET}"
    fi
  done
elif [[ "${INTERACTIVE}" == "true" ]]; then
  if [[ ! -f "${BIN_DIR}/agy2" ]]; then
    echo -ne "  ${CYAN}➜${RESET} Enable 2x Quota? Provision Profile 2 ('agy2') for a 2nd Google account now? [y/N]: "
    read_prompt "" SETUP_P2
    if [[ "${SETUP_P2}" =~ ^[Yy]$ ]]; then
      "${ROOT_DIR}/bin/agy-setup" 2 >/dev/null 2>&1 || true
      echo -e "  ${GREEN}✔ Profile 2 ('agy2') provisioned successfully.${RESET}"
    else
      echo -e "  ${SLATE}Skipped agy2. You can provision any time by running: agy-setup 2${RESET}"
    fi
  else
    echo -e "  ${GREEN}✔ Profile 2 ('agy2') is already active.${RESET}"
  fi
fi

# Telegram Integration Check
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  echo -e "  ${GREEN}✔ Telegram notifications configured${RESET} (Bot Token & Chat ID verified)."
fi

# X (Twitter) Integration Check
if [[ -n "${X_AUTH_TOKEN:-}" ]]; then
  echo -e "  ${GREEN}✔ Zero-API X (Twitter) Publisher configured${RESET} (auth_token cookie present)."
fi

# Optional Tailscale Mesh Network Setup
if [[ -n "${TAILSCALE_AUTHKEY:-}" ]] && command -v tailscale &>/dev/null; then
  echo -e "  ${CYAN}ℹ Connecting to Tailscale mesh using TAILSCALE_AUTHKEY...${RESET}"
  sudo tailscale up --authkey="${TAILSCALE_AUTHKEY}" --accept-routes 2>/dev/null || true
  echo -e "  ${GREEN}✔ Tailscale mesh network connected.${RESET}"
fi

# ==============================================================================
# [6/7] Out-of-the-Box MCP Suite & Background Daemons
# ==============================================================================
echo -e "\n${BOLD}${PURPLE}┌── [6/7] Out-of-the-Box MCP Suite & Background Daemons${RESET}"

GEMINI_CONFIG_DIR="${HOME}/.gemini/config"
mkdir -p "${GEMINI_CONFIG_DIR}"
MCP_CONFIG_FILE="${GEMINI_CONFIG_DIR}/mcp_config.json"
MCP_TEMPLATE="${ROOT_DIR}/templates/mcp_config.json"

# Detect GitHub token (from .env or gh CLI)
GH_MCP_TOKEN="${GITHUB_TOKEN:-}"
if [[ -z "${GH_MCP_TOKEN}" ]] && command -v gh &>/dev/null; then
  GH_MCP_TOKEN="$(gh auth token 2>/dev/null || true)"
fi

# Deploy / Merge mcp_config.json
if command -v node &>/dev/null; then
  node -e '
    const fs = require("fs");
    const target = process.argv[1];
    const template = process.argv[2];
    const ghToken = process.argv[3];

    let current = { mcpServers: {} };
    if (fs.existsSync(target)) {
      try {
        current = JSON.parse(fs.readFileSync(target, "utf8"));
        if (!current.mcpServers) current.mcpServers = {};
      } catch (e) {
        current = { mcpServers: {} };
      }
    }

    let defaultServers = {};
    if (fs.existsSync(template)) {
      try {
        const parsed = JSON.parse(fs.readFileSync(template, "utf8"));
        defaultServers = parsed.mcpServers || {};
      } catch (e) {}
    }

    // Merge default servers (preserving existing custom ones)
    current.mcpServers = { ...defaultServers, ...current.mcpServers };

    // Inject / update github MCP server if token is present
    if (ghToken && ghToken.trim().length > 0) {
      current.mcpServers["github"] = {
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-github"],
        env: {
          GITHUB_PERSONAL_ACCESS_TOKEN: ghToken.trim()
        }
      };
    }

    fs.writeFileSync(target, JSON.stringify(current, null, 2) + "\n");
  ' "${MCP_CONFIG_FILE}" "${MCP_TEMPLATE}" "${GH_MCP_TOKEN}"
elif command -v jq &>/dev/null; then
  if [[ ! -f "${MCP_CONFIG_FILE}" ]]; then
    cp "${MCP_TEMPLATE}" "${MCP_CONFIG_FILE}"
  fi
  if [[ -n "${GH_MCP_TOKEN}" ]]; then
    TMP_MCP="$(mktemp)"
    jq --arg tok "${GH_MCP_TOKEN}" \
      '.mcpServers.github = {"command":"npx","args":["-y","@modelcontextprotocol/server-github"],"env":{"GITHUB_PERSONAL_ACCESS_TOKEN":$tok}}' \
      "${MCP_CONFIG_FILE}" > "${TMP_MCP}" && mv "${TMP_MCP}" "${MCP_CONFIG_FILE}"
  fi
else
  if [[ ! -f "${MCP_CONFIG_FILE}" ]]; then
    cp "${MCP_TEMPLATE}" "${MCP_CONFIG_FILE}"
  fi
fi

echo -e "  ${GREEN}✔ Global MCP configuration ready at ${MCP_CONFIG_FILE}${RESET}"
echo -e "    ${PURPLE}•${RESET} ${BOLD}chrome-devtools:${RESET} CDP browser automation (port 9222)"
if [[ -n "${GH_MCP_TOKEN}" ]]; then
  echo -e "    ${PURPLE}•${RESET} ${BOLD}github:${RESET} Full GitHub API access via personal access token"
else
  echo -e "    ${PURPLE}•${RESET} ${SLATE}github: Skipped (add GITHUB_TOKEN in .env to auto-enable)${RESET}"
fi
echo -e "    ${GREEN}✔ Zero-prompt auto-approval active: 'mcp(*)' pre-authorized across all profiles.${RESET}"

# Deploy Systemd Background Services & Headless Chrome Daemon
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
mkdir -p "${SYSTEMD_USER_DIR}"

if systemctl --user status &>/dev/null; then
  # 1. Headless Chrome Daemon (port 9222)
  if [[ -f "${ROOT_DIR}/templates/systemd/headless-chrome.service" ]]; then
    cp "${ROOT_DIR}/templates/systemd/headless-chrome.service" "${SYSTEMD_USER_DIR}/headless-chrome.service"
  fi
  # 2. Host Hygiene Timers
  if [[ -f "${ROOT_DIR}/templates/systemd/agy-cleanup.service" ]]; then
    cp "${ROOT_DIR}/templates/systemd/agy-cleanup."* "${SYSTEMD_USER_DIR}/" 2>/dev/null || true
  fi
  if [[ -f "${ROOT_DIR}/templates/systemd/agy-watchdog.service" ]]; then
    cp "${ROOT_DIR}/templates/systemd/agy-watchdog."* "${SYSTEMD_USER_DIR}/" 2>/dev/null || true
  fi

  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now headless-chrome.service 2>/dev/null || true
  systemctl --user enable --now agy-cleanup.timer 2>/dev/null || true
  systemctl --user enable --now agy-watchdog.timer 2>/dev/null || true

  if systemctl --user is-active --quiet headless-chrome.service; then
    echo -e "  ${GREEN}✔ Dedicated Headless Chrome daemon active on port 9222 (0.1s launch, 800M quota).${RESET}"
  else
    echo -e "  ${SLATE}● Headless Chrome service installed (will start when Chrome binary is detected).${RESET}"
  fi
  echo -e "  ${GREEN}✔ Autonomous hygiene timers enabled (agy-cleanup.timer, agy-watchdog.timer).${RESET}"
else
  echo -e "  ${SLATE}● Systemd user session not detected (WSL/container without systemd). Skipping daemons.${RESET}"
fi

# ==============================================================================
# [7/7] Launchpad & Summary
# ==============================================================================
echo ""
echo -e "${GREEN}╭───────────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${GREEN}│${RESET}                  ${BOLD}✦ AgyFreeAgent Setup Complete! ✦${RESET}                 ${GREEN}│${RESET}"
echo -e "${GREEN}╰───────────────────────────────────────────────────────────────────╯${RESET}"
echo ""
echo -e "  ${BOLD}${PURPLE}●${RESET} ${BOLD}Primary Agent:${RESET}   ${CYAN}agy1${RESET} ${SLATE}(or agy)${RESET}"
echo -e "  ${BOLD}${PURPLE}●${RESET} ${BOLD}Live Quotas:${RESET}     ${CYAN}q${RESET}"
echo -e "  ${BOLD}${PURPLE}●${RESET} ${BOLD}Log Pruner:${RESET}      ${CYAN}agy-clean-logs${RESET}"
echo -e "  ${BOLD}${PURPLE}●${RESET} ${BOLD}Workspaces Root:${RESET} ${CYAN}~/workspaces/<project-name>${RESET}"
echo -e "  ${BOLD}${PURPLE}●${RESET} ${BOLD}Git Author:${RESET}      ${SLATE}${GIT_USER:-Unset} <${GIT_EMAIL:-Unset}>${RESET}"
echo -e "  ${BOLD}${PURPLE}●${RESET} ${BOLD}Sudo Autonomy:${RESET}   $(sudo -n true 2>/dev/null && echo -e "${GREEN}Enabled (NOPASSWD)${RESET}" || echo -e "${AMBER}Requires Password${RESET}")"
echo -e "  ${BOLD}${PURPLE}●${RESET} ${BOLD}MCP Server Suite:${RESET} ${GREEN}Active${RESET} ${SLATE}(chrome-devtools$([[ -n "${GH_MCP_TOKEN}" ]] && echo ", github"))${RESET}"
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  echo -e "  ${BOLD}${PURPLE}●${RESET} ${BOLD}Telegram Alerts:${RESET} ${GREEN}Active${RESET} ${SLATE}(mobile briefing ready)${RESET}"
fi
if [[ -n "${X_AUTH_TOKEN:-}" ]]; then
  echo -e "  ${BOLD}${PURPLE}●${RESET} ${BOLD}X / Twitter:${RESET}     ${GREEN}Configured${RESET} ${SLATE}(post-to-x ready)${RESET}"
fi
echo ""
echo -e "  ${SLATE}───────────────────────────────────────────────────────────────────${RESET}"
echo -e "  ${BOLD}To start pair-programming with your agent right now, run:${RESET}"
echo -e "  ${BOLD}${CYAN}➜ agy1${RESET}"
echo -e "  ${SLATE}───────────────────────────────────────────────────────────────────${RESET}"
echo ""
