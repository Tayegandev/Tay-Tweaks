# TMAC's — Galaxy Macro Studio (v1.1.0)

A lightweight, local-only Windows keyboard and mouse macro recorder with a dark-blue galaxy interface.

## What works
- Record global keyboard presses/releases, mouse button presses/releases, scroll and optionally sampled mouse movement.
- Start test/Record gives a 3-second preparation window so you can Alt+Tab to another app.
- Edit **individual** inter-event delays to a minimum setting of 0.5 ms, including fractional delays.
- Select and rename profiles; profiles save locally to %LOCALAPPDATA%\TMACs\profiles.json.
- Loop until stopped (off by default), adjust playback speed (0.1–10×).
- Global start and stop keys (F1–F12, default F6 and F7), plus Escape emergency stop during playback.
- Run in system tray when minimized; exit from tray menu.
- No network access, advertising, updater, telemetry, or elevated privileges requested.

## Download the compiled app
Open the repository **Actions** tab → **Build TMAC's Windows EXE** → latest successful run → download the **TMACs-v1.1.0-Windows-x64** artifact. Extract the ZIP and open TMACs.exe.

## Notes
- **0.5 ms is a requested timing setting, not a guaranteed interval.** The Windows scheduler, game frame rates and hardware may limit precision. The playback worker avoids continuously busy-waiting on long delays.
- Some protected games block simulated input. TMAC's does **not** attempt anti-cheat bypass, driver injection, or elevated-input circumvention.
- Recording and playback may not work in administrator-elevated apps if TMAC's runs without similar privileges.
- The active stop hotkey is always available, even after you Alt+Tab. Test on a harmless app first.
- Recording includes a 10,000-event cap. Mouse movement is sampled to reduce load; movement replay is positional rather than motion-interpolated.
- Profiles and local settings are not uploaded anywhere.

## Developer build
Requires .NET 8 SDK on Windows. The GitHub Actions workflow builds automatically; no local build is required for use.


## v1.1.0
- More configurable keyboard hotkeys, including letters and numbers.
- Hold-to-repeat playback mode; releasing the start key cancels playback.
- Scan-code input enabled for improved compatibility with ordinary games. Protected input is not bypassed.
