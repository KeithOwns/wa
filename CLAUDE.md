# CLAUDE.md

Guidance for AI assistants (Claude Code, Gemini, etc.) working in this repository.

## 1. Overview & Goal

AtomicScripts (WA) is a high-performance, single-file PowerShell automation suite for Windows 11. Its primary goal is to provide enterprise-grade configuration, hardening, and maintenance through a modern, interactive CLI.

## 2. Repository Structure

```
wa.ps1                  # standalone, self-contained core script — the only file most users need
AtomicScripts/          # one independent standalone script per Invoke-WA_Set* function in wa.ps1
docs/
  HISTORY.md            # running changelog — append a dated entry per work session
  design/                # historical landing-page mockups (reference only)
scripts/
  Audit-System.ps1       # remote-hosted, SHA-256-pinned posture audit (see wa.ps1 ~line 258)
  tests/
  utils/                 # one-off dev/fix utilities
```

`wa.ps1` does not programmatically depend on `AtomicScripts/`, `scripts/`, or `docs/` at runtime — those are independent re-implementations and reference material, not invoked by the dashboard.

## 3. Architectural Mandates

- **Standalone Core:** `wa.ps1` must remain a single, self-contained file. Avoid external dependencies or multi-file requirements for the core execution.
- **Remediation Strategy:**
  - **Registry Fallbacks (UIA):** Always attempt background registry edits first. Fall back to UI Automation (UIA) only when settings are not manageable via the registry (e.g., SmartScreen, Virus Protection).
  - **No UI Lockout:** New scripts must never leave a setting's corresponding Settings/Control Panel control in a "grayed-out / managed by your organization" state. Writing any value under a `...\Policies\...` registry key triggers this lock regardless of the value written. If a non-policy registry location achieves the same effect, prefer it; if the setting is only controllable via a Policies key, prefer UI Automation (driving the control directly) over writing that key. Two corollaries learned the hard way: (1) stopping the write isn't enough — a stale value from a prior run keeps the control locked, so always `Remove-ItemProperty` the specific Policies value at the top of the function too; (2) when matching a UI element by name, verify it actually supports the pattern you need (e.g. wrap `GetCurrentPattern` in try/catch and keep searching past non-matches) — a heading/label Text control can match the same name search as the real toggle.
  - **UIA Foreground Rendering:** Any UIA step that drives a Settings/Windows Security toggle MUST force the launched window to the foreground before searching its element tree. A UWP window launched via `Start-Process` opens INACTIVE (the calling console keeps focus), and an inactive window never renders its XAML content into the UI Automation tree — `FindAll` sees only window chrome, the toggle is never found, and the step silently no-ops. Use the shared `Set-WinAutoForeground -Window $win` helper (Win32 `ShowWindow`+`SetWindowPos`+`SetForegroundWindow` on the window's `NativeWindowHandle`) right after the window is found; standalone `SET_*.ps1` scripts inline the same Win32 block. Note: the state read-back after `.Toggle()` lags by ~1-2s, so do not verify by reading the toggle state immediately after flipping it.
  - **Audit-First:** Every action must be preceded by a system state audit to ensure changes are only applied when drift is detected.
- **Reporting:** Post-execution audits generate `winauto_audit.json` in the script's working directory (`$PWD`) — this is intentional so the report lands wherever the end user ran the script (including via `iex (irm ...)`), not in a fixed repo-relative folder. Confirmation messages should be indented (4 spaces) and Cyan-colored.

## 4. UI/UX Standards

### Color Palette & Functional Usage

| Color | ANSI Variable | Purpose / Usage |
| :--- | :--- | :--- |
| **Cyan** | `$Global:FGCyan` | **Action & Pending Execution.** Cursors (`>`, `<`), the active `v` icon, and the Atomic Script Method ID for items that **will run**. Also the dashboard's top/bottom frame. |
| **Inverted Cyan** | `$FGBlack$BGCyan` | **Execution Indicator.** Black text on a Cyan background indicates a line that will execute a major phase (Smart Run, Manual Mode, Configure, or Maintain) when **Enter** is pressed. Also used for the **Esc** and **Enter** keys in the footer. |
| **White** | `$Global:FGWhite` | **Enabled / Compliant.** Step titles and brackets for items that are either already enabled (compliant) OR pending an enable action. The `v` icon itself is Gray when already-enabled, Cyan when pending an enable action. |
| **Gray** | `$Global:FGGray` | **Structural Framework.** Boundary lines (`_`), dashed separators (`-`), info brackets `[ ]`. Also step titles with an empty `[ ]` box (Disabled). |
| **Dark Gray** | `$Global:FGDarkGray` | **Inactive / Non-Execution.** Titles, brackets, and method IDs of steps that will not run with the current logic. Also entire sections not currently being navigated. |

### Structural Elements & Information Brackets

- **Information Brackets (`[ ]`):** discovered system state + intended action.
  - **Discovery (prior to toggle):** `[ ]` empty = discovered Disabled; `[v]` checked = discovered Enabled. Neither runs unless toggled.
  - **Toggle `[ ]` → `[v]`:** user wants to Enable — step will run.
  - **Toggle `[v]` → `[ ]`:** user wants to Disable/Revert — step will run and set the opposite/default value.
- **Action Indicator:** for any step included in the run, the `v` icon and the Method ID turn Cyan. Otherwise they dim to Dark Gray.
- **Navigation:** Arrow keys for movement, Space for toggle, Enter for execution, Esc for back/exit.

### Atomic Script Naming Convention

Every step's `Met` ID (and the matching `AtomicScripts/*.ps1` filename) follows
`<Surface>_<Verb><SettingName>` — e.g. `WS_SetRealTimeProt`, `ST_SetTelemetry`,
`NX_SetLLMNR`. The 2-letter `<Surface>` prefix tells the user which Windows UI surface to go
look in, without reading the function body:

| Code | Surface |
| :--- | :--- |
| `WS` | Windows Security app |
| `ST` | Settings app (`ms-settings:`) |
| `FE` | File Explorer / Folder Options |
| `EG` | Microsoft Edge settings |
| `CP` | Legacy Control Panel-style dialog/applet |
| `NX` | No UI exists anywhere — registry/GPO/console-tool only |

`<Verb>` is `Set` (a configurable toggle) or `Run` (a maintenance action with no persistent
on/off state); `<SettingName>` is the existing PascalCase suffix. New steps must pick a
surface code based on where the control *actually* lives in Windows, independent of how the
script implements it — e.g. Real-Time Protection is `WS` even when toggled via
`Set-MpPreference` rather than UI Automation, because the Windows Security toggle is where a
user would go to verify it.

Every `Invoke-WA_Set*`/`Invoke-WA_Run*` function's comment-based help (and the matching
`AtomicScripts/*.ps1` header) must include the exact breadcrumb in a `.LOCATION` section (or
a `# UI Location: ...` line for functions without a comment-help block), e.g.
`Settings > Accounts > Sign-in options`, or `none (registry/GPO-only)` for `NX` steps.

## 5. Development Workflow

- **Pre-Flight:** every run must verify Administrator privileges, Execution Policy (`RemoteSigned`), and console UTF-8 encoding.
- **Logging:** all errors and major events must be logged to `logs/wa.log`.
- **Consistency:** maintain the "Always Run Steps" (Discovery → Health Check → Audit) so the dashboard stays reactive and accurate.

## 6. Version Control Policy

This repo is tracked in git — **git history is the version history.** Do not manually copy a file into an `Archive/` folder or rename it `wa_v2.ps1`, `waSTABLE.ps1`, etc. before editing. That pattern previously produced 80+ redundant snapshot files in `Archive/` with no information not already recoverable via `git log`. If you need to compare against an old revision, use `git diff`/`git show`; if you genuinely need to preserve a one-off experiment outside the normal commit flow, use a branch, not a duplicated file.

When a work session completes a meaningful chunk of work, append a dated entry to `docs/HISTORY.md` and update `ROADMAP.md` checkboxes — do not create a new doc file per session.
