# RL Live Tracker on Linux

This guide covers the parts of the Linux build that differ from Windows: how the game's Stats API reaches a Node process on the host, where the config file lives for each launcher, what the server does differently on Linux, how the overlay window is built and why, what to check when something fails, and what nobody has confirmed yet. It is written for someone who will be the first to run it on a real desktop.

## 1. Why the Stats API can work under Wine

Rocket League's Stats API is a TCP listener on 127.0.0.1:49123 inside the game. Under Wine the game's socket is a real host socket, so when the game binds 127.0.0.1:49123 inside the prefix that is the Linux loopback interface, and a plain `net.connect(49123, '127.0.0.1')` from Node on the host reaches it.

What nobody has confirmed is that the game with Easy Anti-Cheat under Proton honours `DefaultStatsAPI.ini` and opens the port. On Windows the feed works with EAC on. Until a Linux tester runs `ss -ltnp | grep 49123` during a match, the whole Linux build rests on that assumption.

## 2. Where the ini lives

The config file sits in the game's install folder, not in the Wine prefix: `<install>/TAGame/Config/DefaultStatsAPI.ini`, section `[TAGame.MatchStatsExporter_TA]`, keys `PacketSendRate` (must be above 0) and `Port` (49123). The server checks it at start and every few minutes, rewrites `PacketSendRate` when it is 0 or missing (a backup is left next to it as `.rl-tracker.bak`), and shows a restart notice if the game was running at the time.

| Launcher | Where the server reads the install path | Ini |
|---|---|---|
| Heroic (Epic) | `~/.config/heroic/legendaryConfig/legendary/installed.json`, key `install_path` | `<install_path>/TAGame/Config/DefaultStatsAPI.ini` |
| Legendary alone | `~/.config/legendary/installed.json` | same |
| Heroic (Flatpak) | `~/.var/app/com.heroicgameslauncher.hgl/config/heroic/legendaryConfig/legendary/installed.json` | same |
| Steam | `~/.steam/steam/steamapps`, `~/.local/share/Steam/steamapps`, Flatpak Steam, plus every `path` in `libraryfolders.vdf` | `<steamapps>/common/rocketleague/TAGame/Config/DefaultStatsAPI.ini` |

`STATSAPI_INI=/path/to/DefaultStatsAPI.ini` overrides the search. The `installed.json` layout was read from Legendary's code, not observed on a Linux machine.

## 3. What the server does on Linux

The server itself (http, net, fs, worker_threads, no dependencies) runs the same on both platforms. The Windows-specific parts were split or made overridable:

| Area | Windows | Linux |
|---|---|---|
| Opening the browser at start | `cmd /c start` | `xdg-open`; `RL_NO_OPEN=1` skips it (start-tracker.sh sets this) |
| Overlay button on the board (`POST /api/overlay`) | starts RLOverlay.exe | starts `linux-overlay/node_modules/.bin/electron .` once `npm install` has run; `RL_OVERLAY_CMD` replaces the command, `RL_OVERLAY_PGREP` the pattern used to see whether it runs |
| Finding the game and editing the ini | Epic manifests, Program Files, `tasklist` | the table above, `pgrep -f RocketLeague\.exe` (no pgrep means "unknown") |
| Rank emblem images | BakkesMod's folder under `%APPDATA%` | `RS_IMAGES_DIR=/path/to/RocketStats_images` if you have a BakkesMod prefix; otherwise no emblems |
| Game version detection | Epic manifests | the same `installed.json`; if nothing is found it stays silent and the rank relay covers it |
| Update check | offers the Windows zip | offers only a release asset with "linux" in its name, otherwise just the version and a link |
| Packed exe, .bat and .ps1 launchers | shipped | not ported; the two shell scripts replace them |

Data (profile.json, matches/, reports/) lands in the folder the server is started from, as on Windows. The server listens on 127.0.0.1 unless `HOST` is set. What leaves the machine is the same as on Windows: lobby account ids for rank lookups (collect.gitato.net), the daily update check (api.github.com, `UPDATE_CHECK=0` turns it off), the feedback box when you press Send, and, only if you say yes to the first-run "join the test round" question, the match digests, reports and profile in the background. Saying no keeps everything local and the question is not asked again.

## 4. How the overlay window is built

The Windows overlay is a WebView2 window with DWM glass. On Linux the same page (`?overlay&glass&slot=focus` and `&slot=bar`) is shown by an Electron host in `linux-overlay/`. `preload.js` emulates WebView2's `window.chrome.webview` channel, so the page runs unchanged. The choices, in order of consequence:

X11, also under Wayland. The host selects `--ozone-platform=x11` itself (and start-overlay.sh passes it too), which means XWayland on a Wayland session. Electron documents `alwaysOnTop` as not supported on Wayland, so under pure Wayland the window cannot be kept on top. Steam Deck game mode is impossible: gamescope has a single external overlay slot and mangoapp holds it. The fallback there is a phone or second screen with `HOST=0.0.0.0` and `http://<pc-ip>:8341/?board`.

Electron pinned to 42.11.2. Electron 43 and later has an open X11 regression where `setIgnoreMouseEvents(true)` no longer gives click-through (electron/electron#52456). `package.json` requires Node 22.12 or newer for the same reason.

`focusable: false`. Electron's documentation says that on Linux this makes the window stop interacting with the window manager, so it stays on top in all workspaces. It is the nearest thing to the Windows host's `WS_EX_NOACTIVATE`, and the best bet against a focused borderless game that would otherwise sit above a "keep above" window. It is unmeasured on Linux. If the cards ignore clicks, run with `RL_OVERLAY_FOCUSABLE=1`.

Click-through by hotkey or signal only. `setIgnoreMouseEvents(true, { forward: true })` forwards hover events on Windows and macOS; on Linux `forward` is ignored, so the page cannot switch click-through on and off from hover. The only ways back are Ctrl+Alt+O (or `RL_OVERLAY_HOTKEY`) and `SIGUSR1`. Under Wayland the hotkey goes through the GlobalShortcuts portal (GNOME shows a dialog once, KDE binds silently); the signal works everywhere.

Window flags: transparent, frameless, no shadow, no taskbar entry, one instance (a second copy quits), whole display bounds rather than the work area because the game covers the panel anyway. The game watch runs `pgrep -f RocketLeague\.exe` every 3 seconds and hides the cards when it finds nothing; `RL_OVERLAY_GAMEWATCH=0` shows them regardless. Positions are saved per slot in `linux-overlay/overlay-glass-<slot>.json`.

Borderless window mode is required in the game. Exclusive fullscreen covers overlays, on Linux as on Windows.

The overlay host's console output is partly Danish. The lines you will see: `hotkey ... registreret` (registered), `KUNNE IKKE registreres` (could not be registered; use the signal), `klik gaar IGENNEM` (clicks pass through), `klik gaar til kortene` (clicks go to the cards).

## 5. Troubleshooting

| Symptom | Check | Fix |
|---|---|---|
| start-tracker.sh says node is required | `node --version` | Install Node 22.12 or newer |
| Server says it cannot find the game | `ls` the ini path from the table in section 2 | `STATSAPI_INI=/path/to/DefaultStatsAPI.ini ./start-tracker.sh`, then restart the game |
| Board shows no live data in a match | `ss -ltnp \| grep 49123` during the match; `grep -A3 MatchStatsExporter <ini>` | If PacketSendRate is 0 or Port differs, fix the ini and restart the game. If the ini is right and nothing listens, the game does not honour it under Proton on your setup. Report that; it is the main question |
| Electron stops with a SUID sandbox error | the message names `chrome-sandbox` | `./start-overlay.sh --no-sandbox` |
| Electron fails to start with missing libraries | `ldd linux-overlay/node_modules/electron/dist/electron \| grep "not found"` | Install the named libraries (on Debian/Ubuntu typically libnss3, libasound2t64, libxss1) |
| No overlay windows appear at all | `pgrep -af RocketLeague` | If it prints nothing while the game runs, the watch cannot see the process; start with `RL_OVERLAY_GAMEWATCH=0` and report the process line |
| Windows appear, game covers them | `echo $XDG_SESSION_TYPE`; game display mode | Set the game to Borderless. On Wayland try an X11 session. Report desktop and session type either way |
| Opaque black box instead of transparent cards | Is a compositor running? | Enable compositing, or try `RL_OVERLAY_NOGPU=1 ./start-overlay.sh` |
| Ctrl+Alt+O does nothing | start log line for the hotkey | `pkill -USR1 -f 'electron \.( |$)'`; on Wayland accept the portal dialog if one appears |
| Cards ignore clicks | try with click-through off first (Ctrl+Alt+O) | `RL_OVERLAY_FOCUSABLE=1 ./start-overlay.sh` |
| Cards lost off-screen | | Ctrl+Alt+Shift+O, or delete `linux-overlay/overlay-glass-*.json` |
| Second overlay copy does nothing | | Expected; one instance at a time |
| Phone cannot reach the board | `HOST=0.0.0.0` set? firewall on 8341? | Start with `HOST=0.0.0.0 ./start-tracker.sh` and open TCP 8341 on the LAN |
| No rank emblems in player rows | | `RS_IMAGES_DIR` pointing at a BakkesMod RocketStats image folder, if you have one; otherwise cosmetic |

For a fuller overlay log, `RL_OVERLAY_DEBUG=1 ./start-overlay.sh` prints the page's messages (`size:`, `empty`, `drag`, `max:`) and its console.

## 6. Known unknowns

None of these has been measured on Linux. Each is a yes-or-no answer a tester can give.

- Does the game with EAC under Proton listen on host loopback 49123 (Heroic and Steam/pressure-vessel)?
- Does a `focusable: false` window stay above a focused borderless game on KWin (X11 and Wayland/XWayland) and on Mutter with XWayland?
- Does click-through (X11 input shape) work through KDE, GNOME and XWayland with Electron 42.11.2?
- Does `pgrep -f RocketLeague\.exe` match the game's command line under Proton?
- Does `globalShortcut` work under Wayland, or is `SIGUSR1` the only way?
- Is the `installed.json` layout and location right for Heroic, in particular the Flatpak build?
- Does X11 impose the same 39 px minimum height on frameless windows that Windows did in the smoke test?
- How long Electron 42.x gets security updates, and when electron#52456 is closed.

What was verified, on Windows against the running tracker (five runs, Electron 42.11.2 win32-x64): startup, single-instance lock, hotkey registration, both slots loading the page, the page seeing the WebView2 shim and taking the glass branch, `empty` hiding and `size:` resizing the window, `max:` being sent, the drag chain writing the position files, transparency and default placement. The ozone switches, pgrep, signals and the window-manager behaviour were all skipped or unmeasurable there.

## 7. What to send back

Five lines from a match: `ss -ltnp | grep 49123`; `pgrep -af RocketLeague`; `echo $XDG_SESSION_TYPE; echo $XDG_CURRENT_DESKTOP` with a note on whether the overlay stayed above the game in Borderless; Proton version and launcher; any errors from the two scripts. The overlay log with `RL_OVERLAY_DEBUG=1` helps if the windows misbehave.
