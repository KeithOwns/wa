# Change History (HISTORY.md)

Running changelog — append a dated entry per work session. Format: [Keep a Changelog](https://keepachangelog.com), newest first.

## [2026-06-25] - Full Retest & Bugfixes

### Fixed
- `AlwaysRun` crash: the prior session's `$maintModel` rewrite gave "Get Updates" an `AlwaysRun = $true` key but left it off the other three entries; under `Set-StrictMode`, `[bool]$m.AlwaysRun` threw `CRITICAL UNHANDLED ERROR` for any entry missing the key. Added `AlwaysRun = $false` explicitly to the other three.
- `Clear-Host` crash (`The handle is invalid`) when stdout is redirected/piped, as happens under test automation and potentially `iex (irm ...)` remote execution. Wrapped all three `Clear-Host` call sites in `try {} catch {}` so a missing console handle degrades to "screen doesn't clear" instead of killing the run.
- Grammar: "Restart Notification are ENABLED" → "Restart Notification is ENABLED."
- `WS_SetPhishingProtection` Met ID (24 chars) was wrapping to a second line in the 52-char-wide dashboard box; shortened to `WS_SetPhishing` and renamed the matching `AtomicScripts/*.ps1` file to match.
- Firewall-check flakiness: `winauto_audit.json` reported `WindowsFirewall: false` despite all three profiles being enabled — a transient `Get-NetFirewallProfile` hiccup silently swallowed into a wrong-but-safe `false`. Added a shared `Test-FirewallCompliant` helper (retries up to 3x, 300ms apart) and replaced all three duplicate inline copies of this check (audit generation, CLI-path discovery, interactive dashboard discovery) with calls to it.

### Removed
- Dead `Invoke-WA_SetRealTimeProt` — discovered while live-testing with Tamper Protection manually disabled that this function (which had Tamper-Protection and 3rd-party-AV pre-checks) was never actually called by any dashboard or CLI path; the live "Real-Time Protection" toggle is backed by `Invoke-WA_SetVirusThreatProtectReg`, which had no such pre-checks at all. Ported both pre-checks plus a post-write verification read-back into `Invoke-WA_SetVirusThreatProtectReg` (mirrored into the standalone `AtomicScripts/WS_SetRealTimeProt.ps1`), then deleted the orphaned function.

### Verified
- Two real `-Module SmartRun -Silent` executions (30-day gate closed, then forced open by backdating the timestamp 35 days) — both completed cleanly, exercising every default-enabled Configuration step plus the unconditional "Get Updates" Maintenance step. Resulting Defender/Firewall/registry state and the generated `winauto_audit.json` checked against expectations. Built an isolated, non-mutating dashboard-render harness to visually verify the Landing pages, flat Configure preview, and Security/Maintain accordions.

## [2026-06-25] - Color Consolidation, SmartRun Policy Rewrite, Naming Convention

### Changed
- Consolidated `wa.ps1`'s 11 FG / 9 BG ANSI colors down to the 5 semantic colors documented in `CLAUDE.md` §4 (Cyan, Inverted Cyan, White, Gray, Dark Gray), plus Red (failure/error text) and Dark Yellow/Dark Red (footer NAVIGATION keys and the "= ATOMIC SCRIPTS =" banner background only).
- Rewrote the SmartRun default-run policy: "Get Updates" now always runs every time the script runs. Every other step (Configuration toggles, Drive Optimization, Temp File Cleanup, SFC/DISM Repair) now runs only if it's default-enabled *and* more than 30 days have passed since the script's last full run — replacing the old per-setting discovery-compliance check and the old 1/7/7/30-day per-module thresholds. Added a single global timestamp (`Get/Set-WinAutoLastRun -Module "WinAuto"`) for the 30-day gate.
- Renamed every dashboard step's `Met` ID and matching `AtomicScripts/*.ps1` filename to a `<Surface>_<Verb><Setting>` scheme (e.g. `SET_ARSOOptOut` → `ST_SetARSOOptOut`), where the 2-letter surface code (`WS`/`ST`/`FE`/`EG`/`CP`/`NX`) tells the user which Windows UI surface the control lives in. Added a paired `.LOCATION` doc-comment (or `# UI Location: ...` line) to all 38 functions in `wa.ps1` and all 36 renamed `AtomicScripts/*.ps1` files. Internal `Invoke-WA_Set*`/`Invoke-WA_Run*` function names left unchanged (invisible to the end user, lower risk). Surface-code dictionary now documented in `CLAUDE.md` §4.

### Removed
- Console window resize/snap code: `Set-ConsoleSnapRight` (resized the console to 60 columns and snapped it to the screen's right edge via `MoveWindow`/`SystemParametersInfo` P/Invoke) and its call site. `Set-WinAutoForeground` (brings target Settings/Windows Security windows forward for UIA) was left untouched — unrelated.
- The now-contradictory `Test-WA_MaintenanceRecentlyComplete` shortcut, which could previously skip Maintenance — and thus "Get Updates" — entirely.

### Known issues
- `AtomicScripts/GET_DeviceInfo.ps1` and `AtomicScripts/Unlock_PhishingProtection.ps1` don't correspond to any current `Met` ID and look orphaned; flagged for a future cleanup decision, not fixed this session.

## [2026-06-24] - Repository Structure Cleanup

### Root cause
`GEMINI.md` carried a "Vibe Coding Law" instructing assistants to copy a file into `Archive/` before every edit and keep up to 10 numbered versions — duplicating what git already does, and producing ~110 redundant snapshot files (`wa_v1.ps1`–`wa_v84.ps1`, `wa_2.ps1`–`wa_11.ps1`, `wa.ps1.2`–`.4`, `waBAD.ps1`, `waSTABLE.ps1`, `wa_temp.ps1`, `wa_fix_final.ps1`, `wa_new.ps1`, `wa_recovered.ps1`, frozen `README`/`ROADMAP` copies) with no information not already recoverable via `git log`.

### Removed
- The entire `Archive/` folder (snapshot files + frozen doc copies); the still-active changelog relocated to `docs/HISTORY.md`.
- `docs/notes/` (raw session-transcript scratch, superseded by this changelog and `ROADMAP.md`) and `docs/notes/YouVibeNow_AGY_CLI_Setup.md` (an unrelated terminal-config tutorial that had landed in this repo by accident).
- `scripts/core.ps1` (an older, unrelated hardening approach unconnected to the `wa.ps1`/`AtomicScripts` architecture) and `scripts/GET_DeviceInfo.ps1` (byte-identical duplicate of `AtomicScripts/GET_DeviceInfo.ps1`, differing only in line endings).
- `reports/` and the stale-named generated-output files `secrutity_score.json`, `security_audit.json`, `reports/AtomicScripts_Audit.json`, `reports/secrutity_score.json` — all superseded by the current `winauto_audit.json` (whose generation path was left untouched; it intentionally writes to `$PWD` so the report lands wherever the end user ran the script).
- Root-level scratch: `mockup0-7.txt`, a stray `1.1.0` file containing leaked MCP-toolbox JSON output, and the empty placeholder docs `Agents.md`/`Context.md`/`Memory.md`/`Skills.md`.

### Changed
- Merged `BRANDING.md` + `GEMINI.md` into a single `CLAUDE.md`, dropping the manual-archiving law and adding an explicit Version Control Policy section pointing future sessions at git history instead.
- Relocated `Unlock_PhishingProtection.ps1` into `AtomicScripts/` and `fix_metered.py` into `scripts/utils/`, alongside the other one-off dev utilities.
- Rewrote `.gitignore` to drop now-obsolete `Archive/`-specific patterns and add a general rule against future manually-versioned filenames.

## [2026-06-14] - Code Review Remediation

### Fixed
- Critical Remote Code Execution (RCE) vulnerability in the post-run audit block: added strict SHA-256 hash-pinning validation before executing downloaded remote code, quarantining unauthorized or mismatched payloads to `$env:TEMP` instead of executing them.
- Script-breaking `CommandNotFoundException` caused by `Invoke-WA_SetGetMeUpToDate` being defined below the main execution loop that calls it; relocated the function definition above the loop.

## [2026-06-13] - Navigation Logic, Metered Updates Removal, and UI/Footer Polish

### Added
- Contextual exit logic: pressing `Esc` while navigated deep into a section now prints "Press Esc to go Back<-" instead of `<EXIT>`.

### Changed
- 'Get Me Up To Date' reordered to the top of the Automation UI and wired into the SmartRun execution queue (was previously dormant/omitted).
- Footer string reworded from "Use arrow   ^ v   to select" to "Use Up/Dn  ^ | v  to select," with BGDarkYellow padding added around the `^`/`v` arrow-key indicators while preserving string width.

### Removed
- 'Metered Updates' entirely, with the underlying menu-array navigation indexes shifted to avoid index collision.

## [2026-06-13] - Phase 1 & Phase 2 UI Restyling & Bug Fixes

### Added
- Global error logging: `Write-WrappedError` now pipes exceptions to `wa.log` via `Write-Log`, dynamically reading the caller scope via `Get-PSCallStack`. Injected into previously-silent `catch {}` blocks across the discovery section.

### Changed
- Legacy scripts (`wa_temp.ps1`, `wa_fix_final.ps1`, etc.) moved to the Archive directory.
- UI toggles for pending NetBIOS remediations now show `[x]` (Red) instead of `[>]` (Yellow/White).
- Output audit file renamed `posture_audit.json` → `security_score.json`.
- `$Bold` stripped from `$FGDarkYellow` combinations globally, across main headers, footers, and secondary pages.

### Fixed
- NetBIOS discovery logic: now polls `TcpipNetbiosOptions` instead of the non-existent `NetbiosSetting`.

### Removed
- "Next Steps:" and "Windows 11 Posture Audit Complete" blocks from remote audit invocation output (silenced in-memory).

## [2026-06-12] - Exit Message Polish

### Changed
- Exit message changed from `'Exiting - WinAuto -...'` to `"Exiting.."`, printed on its own new line.

## [2026-06-12] - Navigation Footer Color Alignment

### Changed
- Footer block (`Write-Footer`) recolored to `FGDarkYellow` throughout, except specific key highlights: `Enter`/`Esc` stay inverted Cyan, `Space`/`^`/`v`/`EXIT` stay White. The space between `^` and `v` also corrected to `FGDarkYellow`.

## [2026-06-12] - Global FGDarkCyan to FGCyan Color Alignment

### Changed
- All references to the darker `$FGDarkCyan` converted to the brighter `$FGCyan` for dashboard boundaries and active mode lines (`Write-Boundary`'s default color parameter, the `$manualHeaderColor` selection check). `$Global:FGDarkCyan` itself redefined to map to the bright Cyan ANSI code.

## [2026-06-12] - Default Steps Checkmark Color Alignment

### Changed
- The 10 default-enabled configuration methods (Microsoft Update, Firewall, Defender settings, etc.) now show a White checkmark by default regardless of current system state; non-default steps that are already compliant keep their Dark Gray checkmark.

## [2026-06-12] - Header Checkmark Color Alignment

### Changed
- The `v` checkmark inside the `[v] Enabled` legend header now renders Dark Gray instead of Dark Green, matching other compliant-state indicators.

## [2026-06-12] - Global Yellow to Cyan Color Alignment

### Changed
- `$Global:FGYellow` and `$Global:BGYellow` reassigned to Cyan ANSI values, replacing Yellow dashboard highlights/selection indicators/headers globally to enforce the branding palette.

## [2026-06-12] - Compliant Maintenance State Color Alignment

### Changed
- `Write-MaintItem`'s day-counter value now renders Dark Gray (was Dark Green) when a maintenance task is within its safe threshold, matching the same Dark Gray convention used for compliant Configuration steps.

## [2026-06-12] - Compliant State Icon Color Alignment

### Changed
- `Write-ColItem` checkmarks for steps already in their desired system state now render Dark Gray instead of Dark Green.

## [2026-06-12] - Codebase Review & Variable Error Resolution

### Fixed
- Uninitialized `$FGDarkMagenta` variable, referenced when reporting unknown SFC status, causing a strict-mode error — defined globally in the color initialization block.

## [2026-06-12] - Updated Exemplar Refinement

### Changed
- Footer navigation text and the maintenance sub-header updated to match `LandingPage4exemplar.txt`'s exact spacing/casing ("Use arrow  ^ v  to select | Press  Esc to EXIT =>"; "Days Since Last Ran  | Atomic Script").

## [2026-06-12] - Footer and Header Alignment

### Changed
- `Write-Footer` rewritten to the brand-compliant 4-line NAVIGATION KEYS layout from the exemplar, with inverted-cyan (`$FGBlack$BGCyan`) styling on the `Enter`/`Esc` keys per `BRANDING.md`.
- `$Global:TickAction` now returns early for the `"DASHBOARD"` context, preventing footer visual glitching from the dynamic overwrite logic.
- "MAINTAIN OPERATING SYSTEM" subsection header capitalized; maintenance sub-header text changed to "DAYS SINCE LAST RAN | Atomic Script."
- Buffer printing at the bottom of the render loop now uses `-NoNewline` so the cursor rests exactly after `=>`.

## [2026-06-12] - Phase 2 continuation (Exemplar Alignment)

### Changed
- Configuration sections reorganized into the order Automation / Security / User Interface, with all 21 steps from `LandingPage4exemplar.txt` mapped to their toggle variables.
- Registry fallbacks and UIA clicker fallbacks integrated directly into `Invoke-WinAutoConfiguration`'s execution block (registry first, checking success, then UIA if needed).
- Keyboard navigation extended to indexes 0–28 (29 total); `Sync-ToggleStates` and the post-run audit updated to cover all 21 configuration steps.
- Main dashboard rendering loop rewritten to show subsections in the exact exemplar order, names, and keys.

### Fixed
- Missing `$Global:BGCyan = "$Esc[106m"` definition, causing a strict-mode error when rendering the menu.

## [2026-06-12] - Registry Fallbacks for UIA Steps

### Added
- Registry-based counterpart functions for three brittle UI Automation steps: `Invoke-WA_SetSmartScreenReg`, `Invoke-WA_SetVirusThreatProtectReg`, `Invoke-WA_SetKernelModeReg` — enabled by default, with the original UIA-based steps (`Invoke-WA_SetSmartScreen`, `Invoke-WA_SetVirusThreatProtect`, `Invoke-WA_SetKernelMode`) now disabled by default.
- Post-execution audit step writing results to `AtomicScripts_Audit.json`, with a 4-space-indented Cyan confirmation message.

### Changed
- Dashboard rendering updated to display both registry and UIA steps in the Security section; keyboard navigation (`MenuSelection`) extended to handle the six new selectable options.
