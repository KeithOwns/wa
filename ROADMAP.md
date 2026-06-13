# AtomicScripts (WA) - Development Roadmap

This document outlines the planned improvements, bug fixes, UI tweaks, and architecture goals for `wa.ps1`. It combines structural recommendations with user-requested changes.

## Phase 1: Architecture & Reliability (Recommendations)

- [ ] **Implement Proper Error Logging:** Replace "Silent Failure" `catch {}` blocks across remediation and discovery functions. Add a centralized `Write-Log` function that appends caught errors to `logs/wa.log` to provide a diagnostic trail.
- [ ] **Standardize `$Global:` Variable Scopes:** Standardize the invocation of color and icon variables across all functions to consistently use the `$Global:` prefix, preventing fragility under `Set-StrictMode`.
- [ ] **Repair or Archive Auxiliary Scripts:** Patch `wa_temp.ps1` (missing `$Global:MenuSelection` init) and `wa_fix_final.ps1` (discovery block ordering issues), or move them to the `Archive/` folder if they are obsolete.
- [ ] **Update `HISTORY.md`:** Append a new section to `Archive/HISTORY.md` summarizing the recent NetBIOS, color mapping, and UI cleanup fixes.

## Phase 2: User Interface & Branding (From Changes for wa.ps1.txt)

- [ ] **Header Restyling:** Change `ATOMIC SCRIPTS` to `FGBlack` on `BGDarkYellow`. Change `-Configure | Maintain-` to `FGDarkYellow` on default background.
- [ ] **Footer `EXIT` Restyling:** Change `<EXIT>` to `FGDarkRed`.
- [ ] **Footer `^ v` Padding:** Update the ` ^ v ` footer section to be `FGBlack` on `BGDarkYellow`, ensuring exactly two spaces of padding on the left of `^` and two spaces on the right of `v`.
- [ ] **Dynamic Footer Context:** Update the footer to dynamically read "Press Enter to Smart Run" when selecting Smart Run, and "Press Enter for Manual" when selecting Manual Mode.
- [ ] **Dual Cursor Indicator:** Change the cursor to wrap the selected line with a `>` in the left margin and a `<` in the right margin.
- [ ] **Smart Run Indentation:** Ensure `| Smart Run |` has consistent indentation regardless of whether it is selected or not.
- [ ] **Column Alignment:** Fix the vertical alignment of the `|` characters (shift the "Atomic Script" column left by 2 spaces).
- [ ] **Global Color Matching:** Globally update FG/BG colors for all secondary pages (post-dashboard) to match the dashboard's palette.
- [ ] **Audit Scanner Indentation:** Indent the "Running Automated System Audit Scanner..." text by 4 spaces.
- [ ] **Exit Cleanliness:** Prevent the footer from printing a second time upon exit; print the copyright message instead.
- [ ] **Dashboard De-clutter:** Completely remove the `[*] Next Steps: ...` and `================ Windows 11 Posture Audit Complete ================` blocks from the UI.
- [ ] **Text Tweaks:** Change "Restart Notifications" to "Restart Notification".
- [ ] **Audit File Naming:** Change the posture audit output filename to `secrutity_score.json` (Currently using `AtomicScripts_Audit.json`).

## Phase 3: Troubleshooting & Verification (From Changes for wa.ps1.txt)

- [ ] **NetBIOS Toggle State:** Troubleshoot why the NetBIOS step still shows "Disabled" after running with the step toggled on.
- [ ] **Runtime Errors Export:** Verify and answer: "Does the script logging functions currently export any runtime errors?" (Relates to Phase 1 Error Logging).
- [ ] **Script Parity Review:** Review scripts in `C:\Users\admin\src\github.com\KeithOwns\as\Atomic Scripts` and compare them to the `wa.ps1` dashboard implementations to find unassigned scripts or logic drift.
- [ ] **Hotkey Documentation:** Document which hotkeys are currently active in the script.
- [ ] **Modifier Documentation:** Document which modifiers (like `-reverse`) are active in the `wa.ps1` script.
