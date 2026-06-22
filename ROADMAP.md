# AtomicScripts (WA) - Development Roadmap

This document outlines the planned improvements, bug fixes, UI tweaks, and architecture goals for `wa.ps1`. It combines structural recommendations with user-requested changes.

## Phase 1: Architecture & Reliability (Recommendations)

- [x] **Implement Proper Error Logging:** Replace "Silent Failure" `catch {}` blocks across remediation and discovery functions. Add a centralized `Write-Log` function that appends caught errors to `logs/wa.log` to provide a diagnostic trail.
- [x] **Standardize `$Global:` Variable Scopes:** Standardize the invocation of color and icon variables across all functions to consistently use the `$Global:` prefix, preventing fragility under `Set-StrictMode`.
- [x] **Repair or Archive Auxiliary Scripts:** Patch `wa_temp.ps1` (missing `$Global:MenuSelection` init) and `wa_fix_final.ps1` (discovery block ordering issues), or move them to the `Archive/` folder if they are obsolete.
- [x] **Update `HISTORY.md`:** Append a new section to `Archive/HISTORY.md` summarizing the recent NetBIOS, color mapping, and UI cleanup fixes.

## Phase 2: User Interface & Branding (From Changes for wa.ps1.txt)

- [x] **Header Restyling:** Change `ATOMIC SCRIPTS` to `FGBlack` on `BGWhite`. Change `-Configure | Maintain-` to `- WinAuto -` in `FGWhite`.
- [x] **Footer `EXIT` Restyling:** Change `<EXIT>` to `FGDarkRed`.
- [x] **Footer `^ v` Padding:** Update the ` ^ v ` footer section to be `FGBlack` on `BGDarkYellow`, ensuring exactly two spaces of padding on the left of `^` and two spaces on the right of `v`.
- [x] **Dynamic Footer Context:** Update the footer to dynamically read "Press Enter to Smart Run" when selecting Smart Run, and "Press Enter for Manual" when selecting Manual Mode.
- [x] **Dual Cursor Indicator:** Change the cursor to wrap the selected line with a `>` in the left margin and a `<` in the right margin, and highlight the selection with `FGBlack` on `BGYellow`.
- [x] **Smart Run Indentation:** Ensure `| Smart Run |` has consistent indentation regardless of whether it is selected or not.
- [x] **Column Alignment:** Fix the vertical alignment of the `|` characters (shift the "Atomic Script" column left by 2 spaces).
- [ ] **Global Color Matching (PRIORITY):** Globally update FG/BG colors for all secondary pages (post-dashboard) to match the dashboard's palette.
- [x] **Audit Scanner Indentation:** Indent the "Running Automated System Audit Scanner..." text by 4 spaces.
- [x] **Exit Cleanliness:** Prevent the footer from printing a second time upon exit; print the copyright message instead.
- [x] **Dashboard De-clutter:** Completely remove the `[*] Next Steps: ...` and `================ Windows 11 Posture Audit Complete ================` blocks from the UI.
- [x] **Text Tweaks:** Change "Restart Notifications" to "Restart Notification".
- [x] **Audit File Naming:** Change the posture audit output filename to `secrutity_score.json` (Currently using `AtomicScripts_Audit.json`).
- [ ] **Left / Right Arrow Logic:** Wire up functionality to switch focus or menus using the left/right arrow keys (currently stubbed out).

## Phase 3: Troubleshooting & Verification (From Changes for wa.ps1.txt)

- [x] **NetBIOS Toggle State (PRIORITY):** Reviewed 2026-06-22 — the discovery check (`$s_NetBIOS`) already does an OR-based dual check against both the per-adapter registry value and the live WMI `TcpipNetbiosOptions` property, which is the fix this symptom would need. No code change made since none was needed; flagging here as looks-resolved rather than a re-confirmed fix, since it can't be exercised without real network adapters.
- [ ] **Runtime Errors Export:** Verify and answer: "Does the script logging functions currently export any runtime errors?" (Relates to Phase 1 Error Logging).
- [x] **Script Parity Review (PRIORITY):** Done 2026-06-22 — reconciled `AtomicScripts/` against every `Invoke-WA_Set*` function in `wa.ps1` (34 functions): created 8 missing standalone scripts, fixed 2 with UI-lockout bugs, and audited the full file for any other Policies-key lockout risk (none found beyond the 5 already fixed). The original path referenced here no longer applies — `AtomicScripts/` in this repo is now the canonical, fully-synced set.
- [x] **Hotkey Documentation:** Document which hotkeys are currently active in the script.
- [ ] **Modifier Documentation:** Document which modifiers (like `-reverse`) are active in the `wa.ps1` script.

## Phase 4: Future Vision (LifeOS Webapp)

- [ ] **Launch "mylife" Web Application:** Develop a web application based on the "mylife" project structure to serve as scaffolding for a user-customizable LifeOS. This webapp will be designed to help users systematically organize, automate, and manage their personal life or business operations.
