# AtomicScripts (WA) - Project Instructions

## 1. Overview & Goal
AtomicScripts (WA) is a high-performance, single-file PowerShell automation suite for Windows 11. Its primary goal is to provide enterprise-grade configuration, hardening, and maintenance through a modern, interactive CLI.

## 2. Architectural Mandates
- **Standalone Core:** The project is delivered as a single, self-contained file (`wa.ps1`). Avoid external dependencies or multi-file requirements for the core execution.
- **Remediation Strategy:** 
    - **Registry Fallbacks (UIA):** Always attempt background registry edits first. Fall back to UI Automation (UIA) only when settings are not manageable via the registry (e.g., SmartScreen, Virus Protection).
    - **Audit-First:** Every action must be preceded by a system state audit to ensure changes are only applied when drift is detected.
- **Reporting:** Post-execution audits must generate `AtomicScripts_Audit.json`. Confirmation messages should be indented (4 spaces) and Cyan-colored.

## 3. UI/UX Standards
Adhere strictly to the **AtomicScripts Visual Identity** defined in `BRANDING.md`:
- **Palette:** 
    - **Cyan (`$Global:FGCyan`):** Actions, pending execution, cursors (`>`, `<`), and successful remediation.
    - **Gray (`$Global:FGGray`):** Structural elements, brackets `[ ]`, and disabled/unchanged items.
    - **White (`$Global:FGWhite`):** Compliant/Enabled states.
- **Indicators:**
    - `[v]` (Gray) = Already Enabled/Compliant.
    - `[ ]` (Gray) = Disabled.
    - `[v]` (White in White brackets) = Pending ENABLE.
    - `[x]` (Red in Gray brackets) = Pending DISABLE (NetBIOS only).
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
