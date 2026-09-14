#!/usr/bin/env bash
# ==============================================================================
# AgyFreeAgent - Telegram Notification Dispatcher
# Sends autonomous task summaries, CI alerts, or morning briefings to Telegram.
#
# Configuration (set in ~/.bashrc, .env, or systemd environment):
#   export TELEGRAM_BOT_TOKEN="your_bot_token"
#   export TELEGRAM_CHAT_ID="your_chat_id"
#
# Usage:
#   telegram-notify "Task complete: Built and deployed my-app to production"
# ==============================================================================

set -euo pipefail

MESSAGE="${1:-}"

if [[ -z "$MESSAGE" ]]; then
  echo "Usage: $0 \"<message_to_send>\""
  exit 1
fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Fallback: check if .env exists in repo root
if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
  ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
    CHAT_ID="${TELEGRAM_CHAT_ID:-}"
  fi
fi

if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
  echo "[!] Error: TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be set."
  echo "    Get your bot token from @BotFather and chat ID from @userinfobot."
  exit 1
fi

PAYLOAD="$(jq -nc --arg chat_id "$CHAT_ID" --arg text "$MESSAGE" '{chat_id: $chat_id, text: $text, parse_mode: "Markdown"}')"

RESPONSE="$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")"

if echo "$RESPONSE" | grep -q '"ok":true'; then
  echo "[✓] Telegram alert dispatched successfully."
else
  echo "[!] Failed to send Telegram message: $RESPONSE"
  exit 1
fi
