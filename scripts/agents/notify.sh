#!/bin/bash
# Telegram notifier for the pipeline: reads message text from stdin. Needs BB_TG_TOKEN, BB_TG_CHAT (from .env).
set -u
msg="$(cat)"
[ -z "${BB_TG_TOKEN:-}" ] && exit 0
curl -s -o /dev/null -d chat_id="$BB_TG_CHAT" --data-urlencode text="BB: ${msg:0:3500}" \
  "https://api.telegram.org/bot$BB_TG_TOKEN/sendMessage"
