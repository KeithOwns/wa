# AtomicScripts (WA) Conversation History

## 2026-06-12 c081eefd-195b-47b6-8368-641c88efb045
- **Goal**: Implement "Registry Fallbacks" for the three brittle UI Automation (UIA) steps: `Invoke-WA_SetSmartScreen`, `Invoke-WA_SetVirusThreatProtect`, and `Invoke-WA_SetKernelMode`.
- **Planned Changes**:
  - Add registry-based counterpart functions: `Invoke-WA_SetSmartScreenReg`, `Invoke-WA_SetVirusThreatProtectReg`, and `Invoke-WA_SetKernelModeReg`.
  - Add these functions as new toggleable options in the Security section of the configuration menu.
  - Make the new registry-based steps enabled by default (`[v]`).
  - Make the original UIA-based steps disabled by default (`[ ]`).
  - Update keyboard navigation and toggle logic to support the six new selectable settings.
  - Ensure post-execution audit generates `AtomicScripts_Audit.json` with Cyan confirmation messages indented by 4 spaces.
- **Completed Changes**:
  - Successfully added the three registry fallback functions `Invoke-WA_SetSmartScreenReg`, `Invoke-WA_SetVirusThreatProtectReg`, and `Invoke-WA_SetKernelModeReg`.
  - Defined the global toggles for the six target steps: `Toggle_SmartScreenReg` (enabled by default), `Toggle_SmartScreenUIA` (disabled by default), `Toggle_VirusThreatReg` (enabled by default), `Toggle_VirusThreatUIA` (disabled by default), `Toggle_KernelModeReg` (enabled by default), and `Toggle_KernelModeUIA` (disabled by default).
  - Modified the dashboard rendering to display both registry and UIA steps in the "Security" section, checking and applying toggle choices.
  - Updated keyboard navigation indexes (`MenuSelection`) for Up, Down, and Space actions to gracefully handle the six new selectable options, shifting the Maintain section items down appropriately.
  - Added a post-execution audit step that saves results to `AtomicScripts_Audit.json` and prints a confirmation message indented by 4 spaces in Cyan.
  - Verified the script parses correctly with a PowerShell compiler/syntax check.

## 2026-06-12 (Phase 2 continuation)
- **Goal**: Align the dashboard layout, section structure, step names, and toggle behaviors in `wa.ps1` with the exact specifications of `LandingPage4exemplar.txt`.
- **Planned Changes**:
  - Reorganize the configuration sections in the order of `Automation`, `Security`, and `User Interface`.
  - Add all 21 configuration steps from the exemplar as selectable/toggleable items in the menu, mapped to their correct global toggle variables.
  - Integrate registry fallbacks and UIA clicker fallbacks directly into the execution block of `Invoke-WinAutoConfiguration` so that they execute in sequence (registry first, checking success, then UIA if needed) without cluttering the user interface.
  - Extend selection indexes in keyboard navigation (`MenuSelection` 0 to 28) and update toggle mappings in key event loops.
  - Update `Sync-ToggleStates` and the post-run audit to properly report on all 21 configuration steps.
- **Completed Changes**:
  - Initialized all missing global toggles (`Toggle_MicrosoftUpd`, `Toggle_RestartIsReq`, etc.) to match the default checked states from the exemplar.
  - Refactored `Sync-ToggleStates` to reset the new set of 21 configuration options and the background fallbacks.
  - Refactored `Invoke-WinAutoConfiguration` to run all 21 steps from the exemplar using the `Invoke-Smart` wrapper.
  - Updated the execution sequence for `Real-Time Protection` and `Kernel Stack` to automatically attempt registry edits first and fall back to UIA clickers on failure or drift.
  - Rewrote the main dashboard rendering loop to show subsections in the exact order (Automation, Security, User Interface) and with names and keys matching the exemplar.
  - Rebuilt the Up/Down arrow keyboard navigation, Enter execution logic, and Spacebar toggles for all 29 indices (0-28).
  - Expanded the final `AtomicScripts_Audit.json` generator to audit and include all 21 configuration steps.
  - Verified syntax of the final script using PowerShell compilation check.
- **Variable Scope Fix**:
  - Defined the missing `$Global:BGCyan = "$Esc[106m"` in the background color definitions to resolve a strict mode unhandled error when rendering the menu.

## 2026-06-12 (Footer and Header Alignment)
- **Goal**: Align the dashboard footer layout and section titles in `wa.ps1` with the latest changes in the exemplar `LandingPage4exemplar.txt` and style guidelines in `BRANDING.md`.
- **Planned Changes**:
  - Replace the generic copyright footer in `Write-Footer` with the exact 4-line `NAVIGATION KEYS` footer layout from the exemplar.
  - Apply the inverted cyan (`$FGBlack$BGCyan`) styling to the keys `Enter` and `Esc` in the footer as required by `BRANDING.md`.
  - Disable the dynamic overwrite logic in `$Global:TickAction` for the `"DASHBOARD"` context to prevent footer visual glitching.
  - Capitalize the `MAINTAIN OPERATING SYSTEM` subsection header to match the exemplar's casing.
  - Modify the maintenance sub-header to display `DAYS SINCE LAST RAN | Atomic Script` instead of `OF DAYS SINCE LAST RUN | ATOMIC_SCRIPT`.
- **Completed Changes**:
  - Redefined `Write-Footer` to render the brand-compliant `NAVIGATION KEYS` section with correct key highlights and alignments.
  - Modified `$Global:TickAction` to return early when action is `"DASHBOARD"`.
  - Updated line 3026 in `wa.ps1` to print `DAYS SINCE LAST RAN | Atomic Script` and capitalized `MAINTAIN OPERATING SYSTEM`.
  - Updated the buffer printing statement at the bottom of the loop to output the buffer with `-NoNewline` to allow the cursor to rest exactly after `=>`.

## 2026-06-12 (Updated Exemplar Refinement)
- **Goal**: Align dashboard footer text and mixed-case header labels with the newly updated `LandingPage4exemplar.txt` specifications.
- **Planned Changes**:
  - Update the navigation keys footer text to use the new singular/spacing style: `Use arrow  ^ v  to select | Press  Esc to EXIT =>` (matching line 50 of the exemplar exactly).
  - Update the maintenance sub-header label to use mixed-case: `Days Since Last Ran  | Atomic Script` (matching line 40 of the exemplar exactly).
- **Completed Changes**:
  - Modified `Write-Footer` in `wa.ps1` to print `Use arrow  ^ v  to select | Press  Esc to EXIT =>` with brand-compliant inverted cyan keys.
  - Modified the sub-header at line 3012 in `wa.ps1` to print `Days Since Last Ran  | Atomic Script` with exact spaces and mixed-casing.

## 2026-06-12 (Codebase Review & Variable Error Resolution)
- **Goal**: Perform a static analysis review of `wa.ps1` to find any syntax, runtime, or variable errors under strict mode.
- **Planned Changes**:
  - Resolve the reference to the uninitialized variable `$FGDarkMagenta` used at line 2728 when reporting unknown SFC status by defining it globally in the color initialization block.
- **Completed Changes**:
  - Saved a backup copy as `Archive/wa_v7.ps1`.
  - Added `$Global:FGDarkMagenta = "$Esc[35m"` definition to the color properties section of the script.
  - Verified syntax of the final script using PowerShell compilation check.
  - Verified runtime correctness using silent module execution.

## 2026-06-12 (Compliant State Icon Color Alignment)
- **Goal**: Align dashboard compliance checkmarks with the new visual indicator rules where steps already matching their desired system state are marked in Dark Gray.
- **Planned Changes**:
  - Modify `Write-ColItem` to use Dark Gray checkmarks (`$Global:FGDarkGray`) inside the `[v]` brackets when a step is already in its desired state on the local machine.
- **Completed Changes**:
  - Saved a backup copy as `Archive/wa_v8.ps1`.
  - Updated `$iconColor` in the `$IsToggle` block of `Write-ColItem` to use `$Global:FGDarkGray` for compliant/unchanged discovery states (previously used `$Global:FGDarkGreen`).
  - Updated `$icon` checkmark color in the non-toggle block of `Write-ColItem` to use `$FGDarkGray` for compliant states.
  - Confirmed compilation and run health under powershell execution.

## 2026-06-12 (Compliant Maintenance State Color Alignment)
- **Goal**: Align the maintenance section day counter colors with the configuration steps by coloring compliant/threshold-met states in Dark Gray instead of Dark Green.
- **Planned Changes**:
  - Modify `Write-MaintItem` to color the day counter value inside the brackets `[#]` in Dark Gray (`$Global:FGDarkGray`) when the task has been run within the safe threshold.
- **Completed Changes**:
  - Saved a backup copy as `Archive/wa_v9.ps1`.
  - Updated the `$statusColor` choice for compliant states in the `elseif ($prefix -le $Threshold)` block of `Write-MaintItem` to `$Global:FGDarkGray` (previously used `$Global:FGDarkGreen`).
  - Successfully verified execution output and syntax correctness.

## 2026-06-12 (Global Yellow to Cyan Color Alignment)
- **Goal**: Align dashboard highlights, selection indicators, and headers globally to use Cyan instead of Yellow to enforce the branding colors.
- **Planned Changes**:
  - Re-assign the global variables `$Global:FGYellow` and `$Global:BGYellow` to match `$Global:FGCyan` and `$Global:BGCyan` respectively.
- **Completed Changes**:
  - Saved a backup copy as `Archive/wa_v10.ps1`.
  - Changed `$Global:FGYellow` ANSI value from yellow (`$Esc[93m`) to cyan (`$Esc[96m`).
  - Changed `$Global:BGYellow` ANSI value from yellow background (`$Esc[103m`) to cyan background (`$Esc[106m`).
  - Confirmed dashboard rendering, compilation checks, and execution runs.

## 2026-06-12 (Header Checkmark Color Alignment)
- **Goal**: Align the checkbox in the `[v] Enabled` header line with the dark gray color of other compliant states.
- **Planned Changes**:
  - Update line 2961 of the dashboard rendering in `wa.ps1` to use `$FGDarkGray` for the `v` checkmark symbol inside `[v] Enabled`.
- **Completed Changes**:
  - Saved a backup copy as `Archive/wa_v11.ps1`.
  - Replaced `${FGDarkGreen}v` with `${FGDarkGray}v` in the configuration legend header line in `wa.ps1`.
  - Successfully verified execution output and syntax correctness.

## 2026-06-12 (Default Steps Checkmark Color Alignment)
- **Goal**: Align the default-enabled steps (e.g. Microsoft Update, Firewall, defender settings) to be consistently highlighted with a White checkmark `v` on the dashboard by default, while correcting the toggle states to represent the desired system state.
- **Planned Changes**:
  - Update `Write-ColItem` to recognize the 10 default-enabled configuration methods and display them with a White checkmark `v` (`$Global:FGWhite`) by default, regardless of current system state.
- **Completed Changes**:
  - Saved a backup copy as `Archive/wa_v12.ps1`.
  - Added default methods check array `$DefaultMethods` inside `Write-ColItem`.
  - Refactored toggle rendering logic so that default steps display a White checkmark when enabled (`ToggleValue = 1`), and empty brackets when disabled by user toggle (`ToggleValue = 0`).
  - Retained Dark Gray checkmarks for non-default steps that are already compliant on the local computer.
  - Successfully verified execution output and syntax correctness.

## 2026-06-12 (Global FGDarkCyan to FGCyan Color Alignment)
- **Goal**: Convert all references to the darker `$FGDarkCyan` to the brighter `$FGCyan` to highlight dashboard boundaries and active mode lines.
- **Planned Changes**:
  - Update `Write-Boundary` default color parameter from `$FGDarkCyan` to `$FGCyan`.
  - Update `$manualHeaderColor` selection check in `wa.ps1` to use `$FGCyan` instead of `$FGDarkCyan`.
  - Redefine `$Global:FGDarkCyan` to map to the bright Cyan ANSI escape code.
- **Completed Changes**:
  - Saved a backup copy as `Archive/wa_v13.ps1`.
  - Updated line 182 to assign bright Cyan (`$Esc[96m`) to `$Global:FGDarkCyan`.
  - Updated line 730 default parameter in `Write-Boundary` to use `$FGCyan`.
  - Updated line 2918 `$manualHeaderColor` target to use `$FGCyan`.
  - Confirmed compilation checks and successful dry-run validation execution.

## 2026-06-12 (Navigation Footer Color Alignment)
- **Goal**: Color all text in the dashboard footer block (`Write-Footer`) in FGDarkYellow (`$Global:FGDarkYellow`) except for specific key highlights (`Enter`, `Space`, `^`, `v`, `Esc`, `EXIT`).
- **Planned Changes**:
  - Update `Write-Footer` in `wa.ps1` to color the boundary line, centered title, and description text in `FGDarkYellow`.
  - Retain Inverted Cyan highlights for `Enter` and `Esc` keys, and White highlights for `Space`, `^`, `v`, and `EXIT` labels.
  - Correct the color of the space between `^` and `v` to `FGDarkYellow`.
- **Completed Changes**:
  - Saved a backup copy as `Archive/wa_v14.ps1`.
  - Redefined `Write-Footer` to use `$Global:FGDarkYellow` for the horizontal rule (`Write-Boundary`) and section header (`Write-Centered`).
  - Styled `Press`, `to Run`, `| Press`, `to Toggle`, `Use arrow`, the space between `^` and `v`, `to select | Press`, `to`, and `=>` in `FGDarkYellow`.
  - Kept `Enter` and `Esc` in inverted Cyan, and `Space`, `^`, `v`, and `EXIT` in White.
  - Verified syntax of the modified script using PowerShell compilation check.

## 2026-06-12 (Exit Message Polish)
- **Goal**: Change the exit message from `'Exiting - WinAuto -...'` to `"Exiting.."` and ensure it prints on a new line.
- **Planned Changes**:
  - Insert `Write-Host ""` before the exit message output in the key 27 handler in `wa.ps1`.
  - Update `Write-LeftAligned` message to print `Exiting..`.
- **Completed Changes**:
  - Saved a backup copy as `Archive/wa_v15.ps1`.
  - Modified line 3121 in `wa.ps1` to print a empty newline first, followed by `Write-LeftAligned "$FGGray Exiting..$Reset"`.
  - Verified syntax of the final script.










## 2026-06-13 (Phase 1 & Phase 2 UI Restyling & Bug Fixes)
- **Goal**: Complete Phase 1 and Phase 2 items from the roadmap including global error logging, fixing NetBIOS discovery logic, and matching global dashboard FG/BG color palettes.
- **Completed Changes**:
  - Moved legacy scripts (wa_temp.ps1, wa_fix_final.ps1, etc.) to the Archive directory.
  - Implemented global error logging by modifying Write-WrappedError to pipe exceptions to wa.log via Write-Log, dynamically reading the caller scope via Get-PSCallStack.
  - Injected error logging into previously silent catch {} blocks across the discovery section.
  - Fixed NetBIOS discovery logic by polling TcpipNetbiosOptions instead of the non-existent NetbiosSetting.
  - Restyled UI toggles to show [x] (Red) instead of [>] (Yellow/White) for pending NetBIOS remediations.
  - Removed Next Steps: and Windows 11 Posture Audit Complete blocks from remote audit invocation by silencing them in-memory.
  - Renamed the output audit file from posture_audit.json to secrutity_score.json as requested.
  - Globally matched $FGDarkYellow by stripping out $Bold combinations across main headers, footers, and secondary pages.

## 2026-06-13 (Navigation Logic, Metered Updates Removal, and UI/Footer Polish)
- **Goal**: Reorder UI elements, eliminate dead code (Metered Updates), add missing hooks, and polish the interactive footer logic.
- **Completed Changes**:
  - Removed 'Metered Updates' globally and properly shifted the underlying menu array navigation logic to avoid index collision.
  - Re-ordered 'Get Me Up To Date' to the top of the Automation UI.
  - Wired 'Invoke-WA_SetGetMeUpToDate' into the SmartRun execution queue since it was previously dormant/omitted.
  - Refactored the exit/footer string from 'Use arrow   ^ v   to select' to 'Use Up/Dn  ^ | v  to select'.
  - Added contextual exit logic so pressing 'Esc' when navigated deep into a section safely prints 'Press Esc to go Back<-' instead of '<EXIT>'.
  - Injected precise BGDarkYellow padding around the '^' and 'v' arrow indicator keys in the footer while preserving string width.
  - Fully tested syntax passing PSParser validation with zero errors.

## 2026-06-14 (Code Review Remediation)
- **Goal**: Address critical issues identified during static analysis and code review of `wa.ps1`.
- **Completed Changes**:
  - Remediated a critical Remote Code Execution (RCE) vulnerability in the post-run audit block by implementing strict SHA-256 hash pinning validation before executing downloaded remote code.
  - Added logic to quarantine unauthorized or mismatched audit script payloads to `$env:TEMP` without executing them.
  - Fixed a script-breaking `CommandNotFoundException` bug by relocating the `Invoke-WA_SetGetMeUpToDate` function definition above the main execution loop where it is called.

## 2026-06-24 (Repository Structure Cleanup)
- **Goal**: Eliminate the manual file-versioning clutter that had accumulated in `Archive/` and consolidate scattered AI-instruction docs.
- **Root cause identified**: `GEMINI.md` carried a "Vibe Coding Law" instructing assistants to copy a file into `Archive/` before every edit and keep up to 10 numbered versions. This duplicated what git already does and produced ~110 redundant snapshot files (`wa_v1.ps1`-`wa_v84.ps1`, `wa_2.ps1`-`wa_11.ps1`, `wa.ps1.2`-`.4`, `waBAD.ps1`, `waSTABLE.ps1`, `wa_temp.ps1`, `wa_fix_final.ps1`, `wa_new.ps1`, `wa_recovered.ps1`, frozen `README`/`ROADMAP` copies) with no information not already recoverable via `git log`.
- **Completed Changes**:
  - Deleted the entire `Archive/` folder (snapshot files + frozen doc copies); relocated the still-active changelog to `docs/HISTORY.md`.
  - Deleted `docs/notes/` (raw session-transcript scratch already superseded by this changelog and `ROADMAP.md`) and `docs/notes/YouVibeNow_AGY_CLI_Setup.md` (unrelated terminal-config tutorial that had landed in this repo by accident).
  - Merged `BRANDING.md` + `GEMINI.md` into a single `CLAUDE.md`, dropping the manual-archiving law and adding an explicit Version Control Policy section pointing future sessions at git history instead.
  - Removed `scripts/core.ps1` (an older, unrelated hardening approach with no connection to the `wa.ps1`/`AtomicScripts` architecture) and `scripts/GET_DeviceInfo.ps1` (byte-identical duplicate of `AtomicScripts/GET_DeviceInfo.ps1`, differing only in line endings).
  - Removed `reports/` and the stale-named generated-output files `secrutity_score.json`, `security_audit.json`, `reports/AtomicScripts_Audit.json`, `reports/secrutity_score.json` — all superseded by the current `winauto_audit.json`, whose generation path in `wa.ps1` was left untouched (it intentionally writes to `$PWD` so the report lands wherever the end user ran the script).
  - Relocated `Unlock_PhishingProtection.ps1` into `AtomicScripts/` and `fix_metered.py` into `scripts/utils/`, alongside the other one-off dev utilities.
  - Deleted root-level scratch (`mockup0-7.txt`, a stray `1.1.0` file containing leaked MCP-toolbox JSON output, and the empty placeholder docs `Agents.md`/`Context.md`/`Memory.md`/`Skills.md`).
  - Rewrote `.gitignore` to drop now-obsolete `Archive/`-specific patterns and add a general rule against future manually-versioned filenames.

## 2026-06-25 (Color Consolidation, SmartRun Policy Rewrite, Naming Convention)
- **Color palette consolidation**: collapsed `wa.ps1`'s 11 FG / 9 BG ANSI colors down to the 5
  semantic colors documented in `CLAUDE.md` §4 (Cyan, Inverted Cyan, White, Gray, Dark Gray)
  plus Red (kept as a 6th color, reserved for failure/error text) and Dark Yellow/Dark Red
  (kept only for the footer's NAVIGATION keys and the "= ATOMIC SCRIPTS =" banner background).
  Removed the now-dead `FGGreen`/`FGDarkMagenta`/`FGDarkGreen`/`FGDarkCyan`/`FGMagenta`/
  `FGBlue`/`FGDarkBlue`/`BGBlack`/`BGRed`/`BGDarkRed`/`BGDarkCyan`/`BGWhite`/`FGYellow`/
  `BGYellow` palette entries.
- **Removed all console window resize/snap code**: deleted `Set-ConsoleSnapRight` (resized the
  console to 60 columns and snapped it to the right edge of the screen via `MoveWindow`/
  `SystemParametersInfo` P/Invoke) and its call site. `Set-WinAutoForeground` (brings *target*
  Settings/Windows Security windows forward for UIA) was left untouched — unrelated.
- **Rewrote the SmartRun default-run policy**: "Get Updates" now always runs every time the
  script runs, full stop. Every other step (Configuration toggles, Drive Optimization, Temp
  File Cleanup, SFC/DISM Repair) now runs only if it's default-enabled *and* more than 30 days
  have passed since the script's last full run — replacing the old per-setting discovery-
  compliance check and the old 1/7/7/30-day per-module thresholds. Added a single global
  timestamp (`Get/Set-WinAutoLastRun -Module "WinAuto"`) for the 30-day gate, stamped once
  after a full SmartRun or ManualMode pass. Removed the now-contradictory
  `Test-WA_MaintenanceRecentlyComplete` shortcut, which could previously skip Maintenance
  (and thus Get Updates) entirely.
- **Naming convention for steps & atomic scripts**: every dashboard step's `Met` ID and the
  matching `AtomicScripts/*.ps1` filename were renamed to a `<Surface>_<Verb><Setting>` scheme
  (e.g. `SET_ARSOOptOut` -> `ST_SetARSOOptOut`), where the 2-letter surface code tells the user
  which Windows UI surface the control lives in: `WS` (Windows Security), `ST` (Settings app),
  `FE` (File Explorer), `EG` (Microsoft Edge), `CP` (legacy Control Panel-style dialog), or `NX`
  (no UI exists anywhere — registry/GPO/console-tool only). Added a paired `.LOCATION`
  doc-comment section (or a `# UI Location: ...` line for functions without a comment-help
  block) to all 38 functions in `wa.ps1` and a `# UI Location: ...` line to all 36 renamed
  `AtomicScripts/*.ps1` files, giving the exact breadcrumb. `AtomicScripts/GET_DeviceInfo.ps1`
  and `AtomicScripts/Unlock_PhishingProtection.ps1` were left alone — they don't correspond to
  any current `Met` ID and look orphaned; flagged for a future cleanup decision, not fixed here.
  Internal `Invoke-WA_Set*`/`Invoke-WA_Run*` function names were deliberately left unchanged
  (lower risk; invisible to the end user). See the surface-code dictionary now documented in
  `CLAUDE.md` §4.

## 2026-06-25 (Full Retest & Bugfixes)
- **`AlwaysRun` crash fix**: the naming-convention session's `$maintModel` rewrite gave the
  "Get Updates" entry an `AlwaysRun = $true` key but left it off the other three entries
  entirely; under `Set-StrictMode`, `[bool]$m.AlwaysRun` threw `CRITICAL UNHANDLED ERROR: The
  property 'AlwaysRun' cannot be found` for any entry missing the key. Fixed by adding
  `AlwaysRun = $false` explicitly to the three other `$maintModel` entries.
- **`Clear-Host` crash fix**: a live full-`SmartRun` retest crashed with `The handle is
  invalid` — `Clear-Host` requires a real console screen-buffer handle, which isn't available
  when stdout is redirected/piped (as happens both under test automation and potentially under
  `iex (irm ...)` remote execution per `CLAUDE.md`). Wrapped all three `Clear-Host` call sites
  in `try {} catch {}` so a missing console handle degrades to "screen doesn't clear" instead
  of killing the run.
- **Full retest performed**: two real `-Module SmartRun -Silent` executions on this machine
  (one with the 30-day gate closed, one forced open by backdating the `WinAuto` timestamp 35
  days) — both completed cleanly post-fix, exercising every default-enabled Configuration step
  for real plus the unconditional "Get Updates" Maintenance step. Verified resulting
  Defender/Firewall/registry state and the generated `winauto_audit.json` against expectations.
  Also built an isolated, non-mutating dashboard-render harness (dot-sourced just the function
  definitions, drove the discovery+render block directly with synthetic nav state, no key-input
  simulation or remediation calls) to visually verify both Landing pages, the flat Configure
  preview, and the Security/Maintain accordions with item selection.
- **Grammar fix**: "Restart Notification are ENABLED" -> "Restart Notification is ENABLED"
  (singular noun was kept per the existing `ROADMAP.md` naming decision; the verb was wrong).
- **`WS_SetPhishingProtection` -> `WS_SetPhishing`**: the retest's dashboard-render harness
  caught this Met ID (24 chars) wrapping to a second line in the 52-char-wide box. Shortened
  and renamed the matching `AtomicScripts/*.ps1` file to match; confirmed the line no longer
  wraps.
- **Firewall-check flakiness hardened**: the retest's `winauto_audit.json` reported
  `WindowsFirewall: false` despite all three profiles actually being enabled — a transient
  `Get-NetFirewallProfile` hiccup (CIM-backed, occasionally throws under load) that the
  existing `try/catch` silently swallowed into a wrong-but-safe `false`. Added a shared
  `Test-FirewallCompliant` helper (retries up to 3x, 300ms apart) and replaced all three
  duplicate inline copies of this check (audit generation, CLI-path discovery, and the
  interactive dashboard's discovery block) with calls to it.
- **Removed dead `Invoke-WA_SetRealTimeProt`**: discovered while live-testing the
  Tamper-Protection-off path (at the user's request, Tamper Protection was manually disabled
  in Windows Security for this session) that this function — which had a proactive
  Tamper-Protection pre-check and a 3rd-party-AV pre-check — was never actually called by any
  dashboard or CLI path. The live "Real-Time Protection" toggle is backed by a different
  function, `Invoke-WA_SetVirusThreatProtectReg`, which only had a reactive catch-block hint
  and no 3rd-party-AV awareness at all. Ported both pre-checks (skip with a clear message if
  Tamper Protection is on or a 3rd-party AV owns real-time scanning, instead of attempting and
  possibly throwing) plus a post-write verification read-back into
  `Invoke-WA_SetVirusThreatProtectReg`, mirrored the same change into the standalone
  `AtomicScripts/WS_SetRealTimeProt.ps1`, and deleted the orphaned function. Verified with a
  real `-Module SmartRun -Silent` execution (30-day gate forced open) — "Real-Time Protection
  is ENABLED." now prints via the merged, verified path with no errors.
