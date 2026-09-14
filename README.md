# AgyFreeAgent

<p align="center">
  <strong>No API keys. No credit cards. Just your Google accounts.</strong><br>
  An autonomous, self-healing AI engineering agent with full control over your Linux machine.
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#60-second-quickstart">Quickstart</a> •
  <a href="#commands">Commands</a> •
  <a href="#security--auth-storage">Security</a> •
  <a href="#comparison">Comparison</a>
</p>

---

## ⚡ The Problem: The High Cost of Autonomous Agents

Most modern autonomous coding agents force developers into painful trade-offs:
1. **The Credit Card Trap**: Burning through hundreds of dollars in OpenAI/Anthropic API bills when an agent gets stuck in a loop.
2. **The $500/mo Paywall**: Expensive hosted subscriptions (Devin, Enterprise tools) that lock your code in the cloud.
3. **The Quota Wall**: Single-session CLI tools that hit rate limits after an hour of heavy coding, bringing work to a halt.

Yet almost every developer already possesses **2 to 5 standard Google accounts**.

**AgyFreeAgent** bridges this gap. Built on top of **Google Antigravity CLI (`agy`)**, it provisions an isolated, multi-profile swarm powered by Linux user-space filesystem namespaces (**Bubblewrap `bwrap`**). You get a persistent, full-control AI engineer running directly on your Linux host—with **zero API keys and zero monthly subscriptions**.

---

## 🚀 Key Features

* **🆓 Zero API Keys Needed**: Authenticates natively via standard Google accounts. No credit cards, no pay-per-token metering.
* **⚡ Multi-Profile Swarm (`agy1` .. `agy<N>`)**: Run multiple accounts in parallel across terminal tabs without credential collisions or quota interference.
* **📊 One-Key Quota Dashboard (`q`)**: Type `q` to instantly inspect live quota status, active process PIDs, CPU%, and memory usage across all profiles.
* **🛡️ Full Machine Control (`sudo all`)**: Includes passwordless sudo automation so the agent can install packages (`apt`, `dnf`), restart systemd daemons, and manage Docker containers without hanging on password prompts.
* **📂 Canonical Workspace Standard (`~/workspaces`)**: Safe, structured workspace routing automatically trusted in agent permissions.
* **⏰ Autonomous Scheduling (Cron & Systemd)**: Run automated background reviews, overnight issue triaging, and CI verification while you sleep.
* **🔒 Isolated Auth Storage**: Google session tokens are compartmentalized per profile inside `~/.gemini-profiles/acc<N>/` via `bwrap`, while host tools (`git`, `ssh`, `docker`) remain natively accessible.
* **🛡️ Clean-Room Pre-Flight Shield**: Built-in `cleanroom-guard` verifies that no private keys, passwords, or credentials can ever be committed to Git.

---

## 🏛️ Architecture

```mermaid
flowchart TD
    subgraph Host["Host Linux Environment (Kernel & Filesystem)"]
        Workspaces["~/workspaces/ (Project Repositories)"]
        Dotfiles["Host Credentials (~/.gitconfig, ~/.ssh, ~/.config)"]
        Sudoers["/etc/sudoers.d/agy-agent (Passwordless Sudo)"]
    end

    subgraph Swarm["AgyFreeAgent Multi-Profile Swarm (via bwrap)"]
        direction TB
        Agy1["agy1 (Primary Profile)<br/>~/.gemini/antigravity-cli/"]
        Agy2["agy2 (Account 2)<br/>~/.gemini-profiles/acc2/"]
        AgyN["agyn (Account N)<br/>~/.gemini-profiles/accN/"]
    end

    subgraph Tools["Swarm Telemetry & Tooling"]
        Q["q (Quota & Process Inspector)"]
        Setup["agy-setup (Profile Provisioner)"]
        Guard["cleanroom-guard (Pre-flight Secret Shield)"]
        Watchdog["systemd timer (Host Hygiene Watchdog)"]
    end

    Agy1 --> Dotfiles & Workspaces
    Agy2 --> Dotfiles & Workspaces
    AgyN --> Dotfiles & Workspaces
    Q -.-> Agy1 & Agy2 & AgyN
    Watchdog -.-> Swarm
```

### Why Bubblewrap (`bwrap`)?
Changing `$HOME` breaks developer dotfiles: Git loses `.gitconfig`, SSH loses keys, Docker loses credentials.
Instead, AgyFreeAgent leaves host `$HOME` completely untouched, mounting only `~/.gemini/antigravity-cli` inside a private namespace for each account. Your dev environment remains 100% intact.

---

## ⏱️ 60-Second Quickstart

### 1. Clone the repository
```bash
git clone https://github.com/HoangYell/agy-free-agent.git
cd agy-free-agent
```

### 2. Run the installer
```bash
./scripts/install.sh
```
The installer will:
* Verify or install `bubblewrap` (`bwrap`).
* Symlink `agy-setup`, `q`, and `cleanroom-guard` into `~/.local/bin/`.
* Initialize `agy1` (Primary Profile).
* Create the canonical workspace folder `~/workspaces`.
* Install the clean-room pre-commit hook.

### 3. (Recommended) Enable Passwordless Sudo for Full Autonomy
Allow your agent to install packages and manage services without hanging on password prompts:
```bash
./scripts/setup-sudo.sh
```

### 4. Provision Additional Google Accounts
To add Account 2, Account 3, etc.:
```bash
agy-setup 2
agy-setup 3
```
Each command generates an isolated launcher (`agy2`, `agy3`) and pre-configures unrestricted permissions.

---

## ⌨️ Commands Cheat Sheet

| Command | Description |
| :--- | :--- |
| **`agy`** or **`agy1`** | Launch the primary Google account agent session. |
| **`agy2`**, **`agy3`**, **`agy<N>`** | Launch an isolated session for Google Account `<N>`. |
| **`agy-setup <N>`** | Provision and configure a new isolated profile for account `<N>`. |
| **`q`** | Check live quota status, OAuth session validity, and running PIDs across all accounts. |
| **`cleanroom-guard`** | Audit staged git files for potential secret, token, or private key leaks. |

---

## 🔒 Security & Auth Storage

* **Token Isolation**: Google OAuth tokens are stored in `~/.gemini/antigravity-cli/` (acc1) and `~/.gemini-profiles/acc<N>/antigravity-cli/` (acc<N>). Accounts can never access or overwrite each other's tokens.
* **Preserved Host Identity**: Commits made by any profile will still use your personal `git config user.name` and sign with your host SSH/GPG keys.
* **Pre-Flight Defense**: `cleanroom-guard` executes automatically before every `git commit` to block credential leaks.

---

## ⏰ Autonomous Scheduling (Cron & Systemd)

Want your agent to perform routine maintenance, triage issues, or run automated reviews while you're offline?

### Example Cronjob (`crontab -e`)
```bash
# Every morning at 08:00, run agy1 to review pending PRs in workspaces
0 8 * * 1-5 ~/.local/bin/agy1 --prompt "Check all repositories in ~/workspaces, list pending PRs, and summarize today's tasks" >> ~/.ops/logs/briefing.log 2>&1
```

### Systemd User Timer
Ready-to-use systemd service and timer templates are located in `templates/systemd/`:
```bash
mkdir -p ~/.config/systemd/user/
cp templates/systemd/agy-watchdog.* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now agy-watchdog.timer
```

---

## 📊 Comparison Matrix

| Feature | AgyFreeAgent | Devin ($500/mo) | Claude Code | Hermes Agent |
| :--- | :---: | :---: | :---: | :---: |
| **API Keys Required** | **Zero (0)** | N/A (Cloud) | Anthropic API | OpenAI / Any API |
| **Cost** | **$0 / Free** | $500/month | Pay per token | API bill |
| **Execution Host** | **Local Linux / Host** | Cloud VM sandbox | Local CLI | Local TUI / Terminal |
| **Multi-Account Swarm** | **Native (`bwrap`)** | No | No | No |
| **System Admin (`sudo`)** | **Full (`sudo all`)** | Container only | Limited | Limited |
| **Quota Telemetry** | **One-key (`q`)** | Dashboard | CLI prompt | None |
| **Visual Verification** | **Native Chrome CDP** | Browser tool | Headless MCP | No |

---

## 🤝 Contributing & Community

Contributions are welcome! Please ensure all code changes adhere to clean-room standards and pass `./bin/cleanroom-guard`.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📜 License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.
