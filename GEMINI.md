# AtomicScripts (WA) - Project Instructions

## 1. Overview & Goal
AtomicScripts (WA) is a high-performance, single-file PowerShell automation suite for Windows 11. Its primary goal is to provide enterprise-grade configuration, hardening, and maintenance through a modern, interactive CLI.

## 2. Architectural Mandates
- **Standalone Core:** The project is delivered as a single, self-contained file (`wa.ps1`). Avoid external dependencies or multi-file requirements for the core execution.
- **Remediation Strategy:** 
    - **Registry Fallbacks (UIA):** Always attempt background registry edits first. Fall back to UI Automation (UIA) only when settings are not manageable via the registry (e.g., SmartScreen, Virus Protection).
    - **No UI Lockout:** New scripts must never leave a setting's corresponding Settings/Control Panel control in a "grayed-out / managed by your organization" state. Writing any value under a `...\Policies\...` registry key triggers this lock regardless of the value written. If a non-policy registry location achieves the same effect, prefer it; if the setting is only controllable via a Policies key, prefer UI Automation (driving the control directly) over writing that key. Two corollaries learned the hard way: (1) stopping the write isn't enough — a stale value from a prior run keeps the control locked, so always `Remove-ItemProperty` the specific Policies value at the top of the function too; (2) when matching a UI element by name, verify it actually supports the pattern you need (e.g. wrap `GetCurrentPattern` in try/catch and keep searching past non-matches) — a heading/label Text control can match the same name search as the real toggle.
    - **UIA Foreground Rendering:** Any UIA step that drives a Settings/Windows Security toggle MUST force the launched window to the foreground before searching its element tree. A UWP window launched via `Start-Process` opens INACTIVE (the calling console keeps focus), and an inactive window never renders its XAML content into the UI Automation tree — `FindAll` sees only window chrome, the toggle is never found, and the step silently no-ops. Use the shared `Set-WinAutoForeground -Window $win` helper (Win32 `ShowWindow`+`SetWindowPos`+`SetForegroundWindow` on the window's `NativeWindowHandle`) right after the window is found; standalone `SET_*.ps1` scripts inline the same Win32 block. Note: the state read-back after `.Toggle()` lags by ~1–2s, so do not verify by reading the toggle state immediately after flipping it.
    - **Audit-First:** Every action must be preceded by a system state audit to ensure changes are only applied when drift is detected.
- **Reporting:** Post-execution audits must generate `winauto_audit.json`. Confirmation messages should be indented (4 spaces) and Cyan-colored.

## 3. UI/UX Standards
Adhere strictly to the **AtomicScripts Visual Identity** defined in `BRANDING.md`:
- **Palette:** 
    - **Cyan (`$Global:FGCyan`):** Actions, pending execution, cursors (`>`, `<`), and successful remediation.
    - **Gray (`$Global:FGGray`):** Structural elements, brackets `[ ]`, and disabled/unchanged items.
    - **White (`$Global:FGWhite`):** Compliant/Enabled states.
- **Indicators:**
    - `[v]` (Gray) = Already Enabled/Compliant.
    - `[ ]` (Gray) = Disabled.
    - `[v]` (Cyan in White brackets) = Pending ENABLE.
    - `[x]` (Red in Gray brackets) = Pending DISABLE (steps whose compliant state is "feature off" — e.g. NetBIOS, Telemetry, LLMNR, Task View, Hide Admin, Advertising ID, ARSO Opt-Out). (Metered Updates was formerly here but its polarity was flipped to an enable-style action, so it now uses the standard Pending ENABLE indicator.)
- **Navigation:** Arrow keys for movement, Space for toggle, Enter for execution, Esc for back/exit.

## 4. Development Workflow
- **Pre-Flight:** Every run must verify:
    - Administrator privileges.
    - Execution Policy (`RemoteSigned`).
    - Console UTF-8 encoding.
- **Logging:** All errors and major events must be logged to `logs/wa.log`.
- **Consistency:** Maintain the "Always Run Steps" (Discovery -> Health Check -> Audit) to ensure the dashboard remains reactive and accurate.

## 5. File Management (Vibe Coding Laws)
Artificial Intelligence (AI) must always include the following 'Vibe Coding Laws' in their on-going instruction sets while coding:
- **Law I:** Before editing a file, copy and paste the file to the archive folder and keep up to 10 versions of the file history in the archive folder.
