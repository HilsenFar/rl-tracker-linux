#!/usr/bin/env bash
# The transparent overlay window (Electron, X11/XWayland). Needs the tracker running first.
#   ./start-overlay.sh --no-sandbox            # if Electron stops with a SUID sandbox error (Ubuntu 24.04)
#   RL_OVERLAY_GAMEWATCH=0 ./start-overlay.sh  # show the cards without Rocket League running
set -e
cd "$(dirname "$0")/linux-overlay"
if [ ! -d node_modules/electron ]; then echo "first run: downloading Electron 42.11.2 (~110 MB)"; npm install; fi
export RL_OVERLAY_URL="${RL_OVERLAY_URL:-http://localhost:8341/?overlay&glass}"
exec ./node_modules/.bin/electron . --ozone-platform=x11 "$@"
