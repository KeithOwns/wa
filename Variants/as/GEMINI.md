# Gemini Context and Instructions for the Atomic Scripts (`as`) Project

This repository contains "Atomic Scripts" - independent, hyper-fast, modular PowerShell scripts for configuring, securing, and maintaining Windows 11 systems. It is a modular extraction of the core `wa.ps1` (WinAuto) configuration engine.

## Project Context & Architecture
- **True Modularity**: Every configuration, security tweak, and maintenance task is isolated in its own `.ps1` file.
- **Zero Bloat**: Scripts contain only the absolute minimum native PowerShell and Registry commands required to execute the task.
- **Naming Conventions**:
  - `SET_*.ps1`: Applies a configuration. **Must** natively support an `-Undo` switch to instantly revert the setting back to the Windows 11 default.
  - `RUN_*.ps1`: Maintenance or one-time actions (cannot be undone).
  - `GET_*.ps1`: Informational scripts to query statuses without modifying.
  - `UNLOCK_*.ps1`: Standalone unlock scripts designed to wipe strict Group Policies and restore control to the native Windows Settings GUI.

## AI Coding Guidelines
- Maintain the atomic nature of the scripts: one specific task per script.
- The user prefers the `WinAuto_Standalone.ps1` script and closely monitors file timestamps and update statuses.
- When making modifications, ensure changes are precise and respect the existing minimalistic style.
- When editing code, follow this procedure:
  1. Request permission to modify the code.
  2. Wait for human approval.
  3. Make all required changes.
  4. Fully test the updated code (locally where possible).

## Version Control Policy

This repo is tracked in git — git history is the version history. Do not manually copy
a file into an `Archive/` folder before editing. If you need to compare against an old
revision, use `git diff`/`git show`.

When a work session completes a meaningful chunk of work, append a dated entry to
`HISTORY.md` logging what was discussed and changed — do not create a new doc file per
session.
