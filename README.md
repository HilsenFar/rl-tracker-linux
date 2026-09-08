# RL Live Tracker for Linux

Download: https://github.com/HilsenFar/rl-tracker-linux/releases/latest (rl-tracker-linux-2026.09.08.zip, 2 MB). The zip has the tracker and the overlay host; this repo has the host, the scripts and the docs.

RL Live Tracker is a free coach for Rocket League on PC. It reads the game's own local Stats API while you play, measures your habits against your own earlier matches, and coaches one focus at a time. A transparent overlay shows the current focus card and a bar over the game. The Windows version ships as a packed exe from https://gitato.net/rl-tracker/. This package is the same server run with plain Node, plus an overlay host written for Linux.

## Status

This is the first Linux build. Nobody has run it on a real Linux desktop yet. If you try it, you are the first, and the five lines at the end of this page are what we need back.

Verified, on Windows only: the server starts under plain Node, the Electron overlay host loads the overlay page in two transparent windows, sizes them from the page's own messages, saves their positions and registers its hotkeys. Not verified anywhere: that the game under Proton with Easy Anti-Cheat listens on port 49123 on the host, that the overlay stays above a borderless game window, that click-through works through your window manager, and that the game process is detected. Details in docs/LINUX.md.

## You need

- Rocket League through Heroic or Legendary (Epic), or Steam, running under Proton. Psyonix said in February and April 2026 that Easy Anti-Cheat keeps Steam Deck and Linux supported, and ProtonDB rates the game platinum.
- Node.js 22.12 or newer. Electron 42 needs it.
- An X11 session, or a Wayland session with XWayland. The overlay runs through XWayland (`--ozone-platform=x11`); under pure Wayland a window cannot be kept always on top.
- Rocket League in Borderless window mode. Exclusive fullscreen covers overlays.

## Run it

```
unzip rl-tracker-linux-2026.09.08.zip && cd rl-tracker-linux
./start-tracker.sh
./start-overlay.sh
```

Run the two scripts in separate terminals. The first prints `Local: http://localhost:8341/` when it is up; open that address in a browser for the board. The second downloads Electron 42.11.2 (about 110 MB) on its first run, then opens the overlay page (`http://localhost:8341/?overlay&glass`) in two transparent windows.

The server edits the game's Stats API config when it finds the feed switched off (see below); that happens on the first run and again if a game update resets the file. Restart Rocket League after it does.

## If the game is not found

The server switches the Stats API on by editing `<install>/TAGame/Config/DefaultStatsAPI.ini` (PacketSendRate above 0, Port 49123). It looks for the install in Legendary's `installed.json` (Heroic, plain Legendary, Flatpak Heroic) and in Steam's library folders. If it says it cannot find the game, point it at the file:

```
STATSAPI_INI=/path/to/rocketleague/TAGame/Config/DefaultStatsAPI.ini ./start-tracker.sh
```

Restart the game after the ini changes.

## Overlay tips

Two windows: a focus card at the top left and a bar at the bottom centre. Drag them where you want them; positions are saved in `linux-overlay/overlay-glass-<slot>.json`.

Hotkeys: Ctrl+Alt+O toggles click-through (mouse clicks pass to the game), Ctrl+Alt+R reloads both windows, Ctrl+Alt+Shift+O puts them back at their default positions. If the hotkey cannot be registered (Wayland without a shortcuts portal), use signals: `pkill -USR1 -f 'electron \.( |$)'` toggles click-through and `pkill -USR2 -f 'electron \.( |$)'` reloads. That pattern hits only the main Electron process (`electron .` followed by the script's flags), not its `--type=...` children.

If Electron stops with a SUID sandbox error (Ubuntu 24.04 restricts unprivileged user namespaces), run `./start-overlay.sh --no-sandbox`.

Under Wayland the window runs through XWayland. Whether it stays above a borderless game there is one of the things we cannot know without a report.

Keep the game in Borderless. To see the cards without the game running, use `RL_OVERLAY_GAMEWATCH=0 ./start-overlay.sh`; normally they hide when `pgrep -f 'RocketLeague\.exe'` finds nothing.

## No overlay window? Use a phone

Where no overlay window is possible (Steam Deck game mode, where gamescope's single external overlay slot is held by mangoapp), open the server to your LAN and use a phone, tablet or second screen:

```
HOST=0.0.0.0 ./start-tracker.sh
```

Then open `http://<pc-ip>:8341/?board` on the other device. Without HOST the server listens on 127.0.0.1 only.

## What it sends

Three things leave your machine. Rank lookups: the account ids of the players in your current lobby go to https://collect.gitato.net, a relay that holds one read-only game session so every tracker does not need its own, and come back as ranks. An update check against api.github.com once a day (repo HilsenFar/rl-tracker-releases; `UPDATE_CHECK=0` turns it off). Feedback: the text you type in the feedback box, sent to collect.gitato.net when you press Send.

One more thing, only if you say yes: the first time you open the board it asks whether to join the test round. Joining means the tracker uploads the match digests, coaching reports and coach profile it writes in its own folder (matches/, reports/, profile.json, plus daily open-counts) to collect.gitato.net in the background. Say no and nothing is uploaded, and it does not ask again. Everything else stays in the folder: profile.json, matches/, reports/ and the weekly reports. The server listens on 127.0.0.1 only unless HOST is set.

## Please report back

Five lines, taken during a match with the tracker running:

```
1. ss -ltnp | grep 49123          # whether the game listens on the host
2. pgrep -af RocketLeague         # the process line under Proton
3. echo $XDG_SESSION_TYPE; echo $XDG_CURRENT_DESKTOP   # plus: did the overlay stay above the game in Borderless
4. Proton version and launcher (Heroic, Legendary or Steam)
5. Any errors printed by start-tracker.sh or start-overlay.sh
```

Line 1 decides whether the Linux build works at all. Send the lines back the same way you got this link.

## Licences

The tracker (server.js, director/, RLLiveTracker.html and the assets) is under PolyForm Noncommercial 1.0.0, see LICENSE.md. The source is readable at https://github.com/HilsenFar/rl-tracker-source, the mirror of the shipped Windows zip; it will be refreshed to this version at the next Windows release. The overlay host in linux-overlay/ is MIT.

## Windows version

https://gitato.net/rl-tracker/
