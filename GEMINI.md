# AtomicScripts (WA) - Project Instructions

## 1. Overview & Goal
AtomicScripts (WA) is a high-performance, single-file PowerShell automation suite for Windows 11. Its primary goal is to provide enterprise-grade configuration, hardening, and maintenance through a modern, interactive CLI.

## 2. Architectural Mandates
- **Standalone Core:** The project is delivered as a single, self-contained file (`wa.ps1`). Avoid external dependencies or multi-file requirements for the core execution.
- **Remediation Strategy:** 
    - **Registry Fallbacks (UIA):** Always attempt background registry edits first. Fall back to UI Automation (UIA) only when settings are not manageable via the registry (e.g., SmartScreen, Virus Protection).
    - **No UI Lockout:** New scripts must never leave a setting's corresponding Settings/Control Panel control in a "grayed-out / managed by your organization" state. Writing any value under a `...\Policies\...` registry key triggers this lock regardless of the value written. If a non-policy registry location achieves the same effect, prefer it; if the setting is only controllable via a Policies key, prefer UI Automation (driving the control directly) over writing that key. Two corollaries learned the hard way: (1) stopping the write isn't enough — a stale value from a prior run keeps the control locked, so always `Remove-ItemProperty` the specific Policies value at the top of the function too; (2) when matching a UI element by name, verify it actually supports the pattern you need (e.g. wrap `GetCurrentPattern` in try/catch and keep searching past non-matches) — a heading/label Text control can match the same name search as the real toggle.
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
    - `[x]` (Red in Gray brackets) = Pending DISABLE (steps whose compliant state is "feature off" — e.g. NetBIOS, Telemetry, LLMNR, Task View, Hide Admin, Advertising ID, Metered Updates, ARSO Opt-Out).
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
