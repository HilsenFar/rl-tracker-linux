#!/usr/bin/env bash
# RL Live Tracker on Linux: plain Node, loopback only, no browser auto-open.
# Open http://localhost:8341/ yourself once it says "Local: http://localhost:8341/".
#   STATSAPI_INI=/path/to/TAGame/Config/DefaultStatsAPI.ini ./start-tracker.sh   # if the game is not found
#   HOST=0.0.0.0 ./start-tracker.sh                                               # board/overlay on a phone or second screen
set -e
cd "$(dirname "$0")"
if ! command -v node >/dev/null 2>&1; then echo "node >= 22.12 is required: https://nodejs.org"; exit 1; fi
export RL_NO_OPEN=1
exec node server.js "$@"
