#!/bin/bash
# Unattended run: night.sh [max_tasks]. Loads .env, checks CC login, runs the queue with planning, reports to Telegram.
set -u
cd "$(dirname "$0")/../.." || exit 1
set -a; [ -f .env ] && . ./.env; set +a
export BB_NOTIFY_CMD="/bin/bash scripts/agents/notify.sh"
MAX="${1:-20}"
LOG="logs/night-$(date +%Y%m%d-%H%M%S).log"
if ! claude auth status 2>/dev/null | grep -q loggedIn.*true; then
  echo "claude not logged in" | $BB_NOTIFY_CMD; exit 1
fi
echo "night run started, max $MAX tasks" | $BB_NOTIFY_CMD
caffeinate -dims python3 scripts/agents/run_queue.py --plan --continue-on-block --max-tasks "$MAX" 2>&1 | tee "$LOG"
{ echo "night run finished"; grep -E 'merged|ATTENTION|ERROR|queue empty' "$LOG" | tail -20; } | $BB_NOTIFY_CMD
