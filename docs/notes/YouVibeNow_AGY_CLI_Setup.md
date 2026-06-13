# YouVibeNow Tutorial: AGY CLI & PowerShell 7 Configuration

This guide provides the essential settings and steps to configure the **AGY (Antigravity) CLI** running in **PowerShell 7** (PS7) on a Windows environment. This ensures a smooth, familiar, and highly productive command-line editing experience.

## 1. Enabling Familiar Windows Keyboard Shortcuts

By default, PowerShell 7's command-line editing module (`PSReadLine`) may not use standard Windows shortcuts for Undo, Copy, and Paste. To make the terminal feel natural and intuitive for new users, you can enable the `Windows` Edit Mode.

This instantly enables:
- `Ctrl+Z` to Undo typing mistakes
- `Ctrl+C` to Copy selected text
- `Ctrl+V` to Paste text
- Standard Shift+Arrow selection

### Temporary / Immediate Fix
Run this directly in your PowerShell 7 prompt to enable it for your current session:
```powershell
Set-PSReadLineOption -EditMode Windows
```

Alternatively, if you *only* want to bind `Ctrl+Z` to Undo without altering other behaviors, run:
```powershell
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
```

---

## 2. Making the Configuration Permanent (The PS7 Profile)

To ensure these settings load automatically every time you or a user opens PowerShell 7 to use AGY CLI, you must add them to your PowerShell Profile.

### Step-by-Step Instructions:

1. **Open PowerShell 7.**
2. **Check/Create your Profile:**
   If a profile doesn't exist yet, create one by running:
   ```powershell
   if (!(Test-Path -Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
   ```
3. **Edit the Profile:**
   Open the profile file in Notepad:
   ```powershell
   notepad $PROFILE
   ```
4. **Add the Configuration:**
   Copy and paste the following block into the Notepad window:
   ```powershell
   # ==========================================
   # YouVibeNow: AGY CLI & PS7 Environment Setup
   # ==========================================

   # Enable standard Windows text-editing shortcuts (Ctrl+Z to Undo, Ctrl+C to Copy, etc.)
   Set-PSReadLineOption -EditMode Windows
   
   # Explicitly guarantee Ctrl+Z is bound to Undo
   Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
   ```
5. **Save and Close** Notepad.

The next time you launch PowerShell 7 or load up the AGY CLI environment, you will have full `Ctrl+Z` undo capabilities!

---

## Notes for Future Implementation
- These steps are highly recommended as a prerequisite for any users following the **YouVibeNow** tutorials for AGY CLI.
- Having a standardized `PSReadLine` configuration significantly reduces friction and errors when writing multi-line prompts or correcting command mistakes in the terminal.
