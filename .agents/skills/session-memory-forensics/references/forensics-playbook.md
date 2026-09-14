# Session Memory & Forensic Inspection Playbook

## 1. Overview of Antigravity Log Topology

| Artifact Path | Scope & Purpose | Size / Overhead | Inspection Method |
| :--- | :--- | :--- | :--- |
| `~/.gemini/antigravity-cli/history.jsonl` | Main profile user prompts & conversation mappings | ~80 KB (ultra-light) | `session-recall <query>` or `rg` |
| `~/.gemini-profiles/acc<N>/antigravity-cli/history.jsonl` | Multi-profile isolated user prompts (`ya1`..`ya5`) | ~50 KB each | `session-recall -p acc<N>` |
| `~/.gemini/antigravity-cli/brain/<uuid>/.system_generated/logs/transcript.jsonl` | Full conversation transcript (tool calls, outputs, assistant reasoning) | 1-10 MB / session | `session-recall --deep <query>` |
| `~/.gemini/antigravity-cli/brain/<uuid>/scratch/` | Scratch scripts, temporary scripts, and artifacts | Varies | `ls ~/.gemini/antigravity-cli/brain/<uuid>/scratch` |
| `~/.bash_history` | Interactive shell history | ~50-100 KB | `cat ~/.bash_history \| tail -n 100` |

---

## 2. Forensic Investigation Protocol (Step-by-Step)

### Step 1: Prompt History Scan (`session-recall`)
When user asks about a past instruction, password, or configuration:
```bash
session-recall "<keyword>"
```
- Returns timestamp, profile (`[main]`, `[acc2]`, etc.), and conversation ID.
- Execution time: < 5ms.

### Step 2: Deep Context Recovery (`transcript.jsonl`)
If the exact prompt needs surrounding context (tool arguments, terminal outputs, error messages):
```bash
session-recall --deep "<keyword>"
# Or directly view transcript around matching step
rg -C 5 "<keyword>" ~/.gemini/antigravity-cli/brain/<uuid>/.system_generated/logs/transcript.jsonl
```

### Step 3: Ground-Truth Verification (Never Blind Trust)
Before returning recovered secrets or system state to user:
1. **Password Verification**:
   - Extract shadow line: `sudo -n cat /etc/shadow | grep $(whoami):`
   - Hash test: `openssl passwd -6 -salt '<salt>' '<candidate_pass>'`
   - Or automated check: `session-recall verify-pass <candidate>`
2. **Network / Port Verification**:
   - Verify listening ports: `ss -tulpn | grep :<port>`
   - Verify process status: `systemctl --user status <service>`
3. **Environment & Secrets**:
   - Verify environment variables: `env | grep <KEY>`
   - Verify config files in `~/.config/` with proper permissions (`chmod 600`).
