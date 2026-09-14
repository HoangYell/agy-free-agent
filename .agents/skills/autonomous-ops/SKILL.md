---
name: autonomous-ops
description: Operational guide for host-level engineering, process supervision, memory hygiene, and system administration for autonomous agents.
---

# Autonomous Host Operations & System Engineering

This skill provides protocols for managing host resources, background daemons, and system maintenance safely.

## 1. Process Supervision & Zombie Remediation
Long-running autonomous agent sessions often spawn subprocesses (compilers, dev servers, headless browsers).
- Always ensure headless processes are cleanly terminated when a task completes.
- Inspect active processes with:
  ```bash
  ps aux | grep -E "agy|chrome|node"
  ```
- To clean up orphaned Chrome renderers:
  ```bash
  pkill -f "chrome.*--type=renderer.*defunct" || true
  ```

## 2. Resource Quotas & Memory Protection
Prevent agent tasks from exhausting system RAM during heavy compilations (e.g. Rust, large Node packages):
- Check memory consumption:
  ```bash
  free -h
  ```
- If swapping occurs, prioritize clearing inactive build artifacts (`target/`, `node_modules/.cache`, `.astro/`).

## 3. Background Terminal Daemons
When executing tasks that must survive beyond the immediate interactive session:
- Use Linux `systemd --user` units for persistent background services.
- Never run unbounded infinite sleep loops in shell commands. Rely on systemd timers or cronjobs instead.
