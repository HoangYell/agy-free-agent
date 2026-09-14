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

# ==============================================================================
# [1/6] System & Environment Check
# ==============================================================================
echo -e "${BOLD}${PURPLE}┌── [1/6] System & Environment Check${RESET}"
OS_NAME="$(uname -s)"
if [[ "${OS_NAME}" != "Linux" ]]; then
  echo -e "  ${AMBER}● Notice:${RESET} Detected OS: ${OS_NAME}."
  echo -e "    AgyFreeAgent multi-profile isolation utilizes Linux bubblewrap (bwrap)."
  echo -e "    On Windows, please use WSL2 (Ubuntu). On macOS, use a Linux VM."
else
  echo -e "  ${GREEN}✔ Linux kernel detected${RESET} ($(uname -r))."
fi

mkdir -p "${BIN_DIR}"
mkdir -p "${PROFILES_BASE}"
mkdir -p "${WORKSPACES_DIR}"

# ==============================================================================
# [2/6] Core Dependencies (Git, Bubblewrap, Node.js, jq)
# ==============================================================================
echo -e "\n${BOLD}${PURPLE}┌── [2/6] Core Dependencies Check & Bootstrap${RESET}"

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
  git clone https://github.com/HoangYell/agy-free-agent.git "${ROOT_DIR}"
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
# [3/6] Developer & Git Identity (Interactive Validation)
# ==============================================================================
echo -e "\n${BOLD}${PURPLE}┌── [3/6] Developer & Git Identity${RESET}"

GIT_USER="$(git config --global user.name 2>/dev/null || true)"
GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"

# Validate / prompt Git Name
if [[ -z "${GIT_USER}" ]]; then
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
else
  echo -e "  ${GREEN}✔ Git author name:${RESET} ${BOLD}${GIT_USER}${RESET}"
fi

# Validate / prompt Git Email
if [[ -z "${GIT_EMAIL}" ]]; then
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
else
  echo -e "  ${GREEN}✔ Git author email:${RESET} ${BOLD}${GIT_EMAIL}${RESET}"
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
  echo -e "  ${GREEN}✔ GitHub authentication ready${RESET} (SSH key or gh CLI detected)."
else
  echo -e "  ${AMBER}● Notice:${RESET} No GitHub SSH key or CLI authentication detected."
  if [[ "${INTERACTIVE}" == "true" ]]; then
    echo -ne "  ${CYAN}➜${RESET} Generate an Ed25519 SSH key automatically now? [Y/n]: "
    read_prompt "" GEN_SSH
    GEN_SSH="${GEN_SSH:-y}"
    if [[ "${GEN_SSH}" =~ ^[Yy]$ ]]; then
      mkdir -p "${HOME}/.ssh"
      chmod 700 "${HOME}/.ssh"
      SSH_KEY_FILE="${HOME}/.ssh/id_ed25519"
      if [[ ! -f "${SSH_KEY_FILE}" ]]; then
        ssh-keygen -t ed25519 -C "${GIT_EMAIL:-git@agent}" -f "${SSH_KEY_FILE}" -N "" -q
      fi
      PUB_KEY="$(cat "${SSH_KEY_FILE}.pub")"
      echo -e "  ${GREEN}✔ Generated SSH key at ${SSH_KEY_FILE}${RESET}"
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
# [4/6] Passwordless Sudo (Autonomous YOLO Autonomy)
# ==============================================================================
echo -e "${BOLD}${PURPLE}┌── [4/6] Passwordless Sudo (Autonomous YOLO Mode)${RESET}"

if sudo -n true 2>/dev/null; then
  echo -e "  ${GREEN}✔ Passwordless sudo is already active (NOPASSWD: ALL).${RESET}"
else
  echo -e "  ${AMBER}● Notice:${RESET} Autonomous agents need passwordless sudo to install packages"
  echo -e "    and manage services in the background without hanging."
  if [[ "${INTERACTIVE}" == "true" ]]; then
    echo -ne "  ${CYAN}➜${RESET} Enable passwordless sudo for '${CURRENT_USER}' now? [Y/n]: "
    read_prompt "" ENABLE_SUDO
    ENABLE_SUDO="${ENABLE_SUDO:-y}"
    if [[ "${ENABLE_SUDO}" =~ ^[Yy]$ ]]; then
      echo -e "  ${CYAN}ℹ Enter your password if prompted (one-time setup):${RESET}"
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
fi

# ==============================================================================
# [5/6] Antigravity CLI & Swarm Tooling
# ==============================================================================
echo -e "\n${BOLD}${PURPLE}┌── [5/6] Antigravity CLI & Swarm Tooling${RESET}"

# Check agy binary
if command -v agy &>/dev/null || [[ -x "${BIN_DIR}/agy" ]]; then
  echo -e "  ${GREEN}✔ Google Antigravity CLI ('agy') detected.${RESET}"
else
  echo -e "  ${AMBER}● Notice:${RESET} 'agy' binary is not yet installed in PATH or ${BIN_DIR}."
  if command -v npm &>/dev/null && [[ "${INTERACTIVE}" == "true" ]]; then
    echo -ne "  ${CYAN}➜${RESET} Install '@google/antigravity-cli' globally via npm now? [Y/n]: "
    read_prompt "" INSTALL_AGY
    INSTALL_AGY="${INSTALL_AGY:-y}"
    if [[ "${INSTALL_AGY}" =~ ^[Yy]$ ]]; then
      echo -e "  ${CYAN}ℹ Installing @google/antigravity-cli...${RESET}"
      sudo npm install -g @google/antigravity-cli || npm install -g @google/antigravity-cli || true
    fi
  fi
  if ! command -v agy &>/dev/null && [[ ! -x "${BIN_DIR}/agy" ]]; then
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

chmod +x "${ROOT_DIR}/bin/agy-setup" "${ROOT_DIR}/bin/q" "${ROOT_DIR}/bin/cleanroom-guard" "${ROOT_DIR}/bin/agy-clean-logs" "${ROOT_DIR}/bin/telegram-notify" "${ROOT_DIR}/scripts/clean-logs.sh" "${ROOT_DIR}/scripts/telegram-notify.sh" "${ROOT_DIR}/scripts/setup-sudo.sh"

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

# Optional: Provision Profile 2 (agy2) for multi-account quota
if [[ "${INTERACTIVE}" == "true" ]]; then
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

# ==============================================================================
# [6/6] Launchpad & Summary
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
echo ""
echo -e "  ${SLATE}───────────────────────────────────────────────────────────────────${RESET}"
echo -e "  ${BOLD}To start pair-programming with your agent right now, run:${RESET}"
echo -e "  ${BOLD}${CYAN}➜ agy1${RESET}"
echo -e "  ${SLATE}───────────────────────────────────────────────────────────────────${RESET}"
echo ""
