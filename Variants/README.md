# Variants

Archived sibling variants of the WinAuto suite, merged into this repo on 2026-07-06 so `wa` is the single canonical home. Nothing here is wired into `wa.ps1` — these are preserved as-is for reference and salvage.

| Variant | What it was | Unique content worth knowing about |
|---|---|---|
| `JA/` | Atomic-component variant with a hub launcher | `AtomicScripts/Installers/` (AdobeCC, AirMedia, Box suite installers), `HUB_AtomicLauncher.ps1`, `Install_Apps.json`, `masterPLAN.txt` |
| `PatchW11/` | Single-file variant with the largest standalone-script library | `StandaloneScripts/` organized by category — Diagnostics, Legacy_Support, Maintenance, Security (SecureDNS, HardenNetworkProtocols, DynamicLock), UI_Tweaks, Utilities (RestorePoint, Remote_EXECUTE, User_MANAGER) |
| `as/` | Early "Atomic Scripts" generation | `ScriptUtilities/GenerateAtomicScripts.ps1` (+ Undo) — the generator that produced the atomic script pattern |

## Drift warning

These variants' scripts overlap heavily with each other and with `wa/AtomicScripts/`, but diffs confirmed **real content drift** (not just whitespace/encoding) between same-named scripts across variants. Do not assume any two same-named files are interchangeable — `wa/AtomicScripts/` (prefixed naming: `WS_`, `ST_`, `NX_`, `CP_`, `FE_`, `EG_`) is the evolved, canonical set.

Excluded from the merge: `.git` histories (left in the original repos), log files, and `nppBackup/` editor artifacts.
