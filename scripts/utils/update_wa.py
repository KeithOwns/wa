import re

def update_wa(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add global toggles
    toggle_str = '    $Global:Toggle_MicrosoftUpd = 1\n'
    replacement = '    $Global:Toggle_MicrosoftUpd = 1\n    $Global:Toggle_GetMeUpToDate = 1\n    $Global:Toggle_MeteredUpd = 0\n'
    content = content.replace(toggle_str, replacement, 1)
    
    # 2. Add reset sync logic
    sync_str = '    $Global:Toggle_MicrosoftUpd = 1\n'
    # The second occurrence of Toggle_MicrosoftUpd = 1 is in Sync-ToggleStates
    # We replaced the first one. We will do a generic replacement since we know the context
    content = content.replace('    $Global:Toggle_MicrosoftUpd = 1\n', '    $Global:Toggle_MicrosoftUpd = 1\n    $Global:Toggle_GetMeUpToDate = 1\n    $Global:Toggle_MeteredUpd = 0\n')

    # 3. Add to discovery section
    disco_str = '''    try {
        $muVal = Get-RegistryValue "HKLM:\\SOFTWARE\\Microsoft\\WindowsUpdate\\UX\\Settings" "AllowMUUpdateService"
        if ($muVal -eq 1) { $s_MU = $true } else { $s_MU = $false }
    } catch {
        Write-Log "$_" "ERROR"
        $s_MU = $false
    }
'''
    disco_repl = disco_str + '''
    try {
        $gmVal = Get-RegistryValue "HKLM:\\SOFTWARE\\Microsoft\\WindowsUpdate\\UX\\Settings" "IsExpedited"
        if ($gmVal -eq 1) { $s_GetMe = $true } else { $s_GetMe = $false }
    } catch { Write-Log "$_" "ERROR"; $s_GetMe = $false }
    try {
        $metVal = Get-RegistryValue "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate" "AllowAutoWindowsUpdateDownloadOverMeteredNetwork"
        if ($metVal -eq 1) { $s_Metered = $true } else { $s_Metered = $false }
    } catch { Write-Log "$_" "ERROR"; $s_Metered = $false }
'''
    content = content.replace(disco_str, disco_repl)

    # 4. Add to dashboard UI
    ui_str = '''    Write-ColItem "Microsoft Update" "SET_MicrosoftUpd" $s_MU -IsToggle -ToggleValue $Global:Toggle_MicrosoftUpd -IsSelected ($Global:MenuSelection -eq 3)
'''
    ui_repl = ui_str + '''    Write-ColItem "Get Me Up To Date" "SET_GetMeUpToDate" $s_GetMe -IsToggle -ToggleValue $Global:Toggle_GetMeUpToDate -IsSelected ($Global:MenuSelection -eq 4)
    Write-ColItem "Metered Updates" "SET_MeteredUpd" $s_Metered -IsToggle -ToggleValue $Global:Toggle_MeteredUpd -IsSelected ($Global:MenuSelection -eq 5)
'''
    content = content.replace(ui_str, ui_repl)

    # Shift subsequent MenuSelections in Write-ColItem
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if 'Write-ColItem' in line and '-IsSelected ($Global:MenuSelection -eq ' in line:
            m = re.search(r'-IsSelected \(\$Global:MenuSelection -eq (\d+)\)', line)
            if m:
                val = int(m.group(1))
                if val >= 4 and val <= 23:
                    lines[i] = re.sub(r'-IsSelected \(\$Global:MenuSelection -eq \d+\)', f'-IsSelected ($Global:MenuSelection -eq {val+2})', line)
    content = '\n'.join(lines)
    
    # 5. Fix Navigation keys
    nav_str = '''        elseif ($current -eq 0) {
            $Global:MenuSelection = 28
        }'''
    nav_repl = '''        elseif ($current -eq 0) {
            $Global:MenuSelection = 30
        }'''
    content = content.replace(nav_str, nav_repl, 1)
    
    content = content.replace(
        'elseif ($current -ge 4 -and $current -le 23) {\n            $Global:MenuSelection = $current - 1\n        }\n        elseif ($current -eq 24) {\n            $Global:MenuSelection = 2\n        }\n        elseif ($current -eq 25) {\n            $Global:MenuSelection = 24\n        }\n        elseif ($current -ge 26 -and $current -le 28) {\n            $Global:MenuSelection = $current - 1\n        }',
        'elseif ($current -ge 4 -and $current -le 25) {\n            $Global:MenuSelection = $current - 1\n        }\n        elseif ($current -eq 26) {\n            $Global:MenuSelection = 2\n        }\n        elseif ($current -eq 27) {\n            $Global:MenuSelection = 26\n        }\n        elseif ($current -ge 28 -and $current -le 30) {\n            $Global:MenuSelection = $current - 1\n        }'
    )
    
    content = content.replace(
        'elseif ($current -eq 2) {\n            $Global:MenuSelection = 24\n        }\n        elseif ($current -ge 3 -and $current -le 22) {\n            $Global:MenuSelection = $current + 1\n        }\n        elseif ($current -eq 23) {\n            $Global:MenuSelection = 24\n        }\n        elseif ($current -eq 24) {\n            $Global:MenuSelection = 0\n        }\n        elseif ($current -ge 25 -and $current -le 27) {\n            $Global:MenuSelection = $current + 1\n        }\n        elseif ($current -eq 28) {\n            $Global:MenuSelection = 0\n        }',
        'elseif ($current -eq 2) {\n            $Global:MenuSelection = 26\n        }\n        elseif ($current -ge 3 -and $current -le 24) {\n            $Global:MenuSelection = $current + 1\n        }\n        elseif ($current -eq 25) {\n            $Global:MenuSelection = 26\n        }\n        elseif ($current -eq 26) {\n            $Global:MenuSelection = 0\n        }\n        elseif ($current -ge 27 -and $current -le 29) {\n            $Global:MenuSelection = $current + 1\n        }\n        elseif ($current -eq 30) {\n            $Global:MenuSelection = 0\n        }'
    )

    # 6. Fix Spacebar logic
    content = content.replace(
        'elseif ($current -eq 3) { $Global:Toggle_MicrosoftUpd = if ($Global:Toggle_MicrosoftUpd -eq 1) {0} else {1} }',
        'elseif ($current -eq 3) { $Global:Toggle_MicrosoftUpd = if ($Global:Toggle_MicrosoftUpd -eq 1) {0} else {1} }\n            elseif ($current -eq 4) { $Global:Toggle_GetMeUpToDate = if ($Global:Toggle_GetMeUpToDate -eq 1) {0} else {1} }\n            elseif ($current -eq 5) { $Global:Toggle_MeteredUpd = if ($Global:Toggle_MeteredUpd -eq 1) {0} else {1} }'
    )
    content = content.replace('elseif ($current -eq 4)', 'elseif ($current -eq 6)')
    content = content.replace('elseif ($current -eq 5)', 'elseif ($current -eq 7)')
    content = content.replace('elseif ($current -eq 6)', 'elseif ($current -eq 8)')
    content = content.replace('elseif ($current -eq 7)', 'elseif ($current -eq 9)')
    content = content.replace('elseif ($current -eq 8)', 'elseif ($current -eq 10)')
    content = content.replace('elseif ($current -eq 9)', 'elseif ($current -eq 11)')
    content = content.replace('elseif ($current -eq 10)', 'elseif ($current -eq 12)')
    content = content.replace('elseif ($current -eq 11)', 'elseif ($current -eq 13)')
    content = content.replace('elseif ($current -eq 12)', 'elseif ($current -eq 14)')
    content = content.replace('elseif ($current -eq 13)', 'elseif ($current -eq 15)')
    content = content.replace('elseif ($current -eq 14)', 'elseif ($current -eq 16)')
    content = content.replace('elseif ($current -eq 15)', 'elseif ($current -eq 17)')
    content = content.replace('elseif ($current -eq 16)', 'elseif ($current -eq 18)')
    content = content.replace('elseif ($current -eq 17)', 'elseif ($current -eq 19)')
    content = content.replace('elseif ($current -eq 18)', 'elseif ($current -eq 20)')
    content = content.replace('elseif ($current -eq 19)', 'elseif ($current -eq 21)')
    content = content.replace('elseif ($current -eq 20)', 'elseif ($current -eq 22)')
    content = content.replace('elseif ($current -eq 21)', 'elseif ($current -eq 23)')
    content = content.replace('elseif ($current -eq 22)', 'elseif ($current -eq 24)')
    content = content.replace('elseif ($current -eq 23)', 'elseif ($current -eq 25)')
    
    # 7. Fix Enter logic execution
    content = content.replace(
        'elseif ($current -eq 3) { Invoke-Smart "Microsoft Update" { Invoke-WA_SetMicrosoftUpd } -TargetToggle $Global:Toggle_MicrosoftUpd }',
        'elseif ($current -eq 3) { Invoke-Smart "Microsoft Update" { Invoke-WA_SetMicrosoftUpd } -TargetToggle $Global:Toggle_MicrosoftUpd }\n            elseif ($current -eq 4) { Invoke-Smart "Get Me Up To Date" { Invoke-WA_SetGetMeUpToDate } -TargetToggle $Global:Toggle_GetMeUpToDate }\n            elseif ($current -eq 5) { Invoke-Smart "Metered Updates" { Invoke-WA_SetMeteredUpd } -TargetToggle $Global:Toggle_MeteredUpd }'
    )
    content = content.replace('elseif ($current -eq 4) { Invoke-Smart "Restart Notification" { Invoke-WA_SetRestartIsReq } -TargetToggle $Global:Toggle_RestartIsReq }', 'elseif ($current -eq 6) { Invoke-Smart "Restart Notification" { Invoke-WA_SetRestartIsReq } -TargetToggle $Global:Toggle_RestartIsReq }')
    content = content.replace('elseif ($current -eq 5) { Invoke-Smart "App Restart Persist" { Invoke-WA_SetRestartApps } -TargetToggle $Global:Toggle_RestartApps }', 'elseif ($current -eq 7) { Invoke-Smart "App Restart Persist" { Invoke-WA_SetRestartApps } -TargetToggle $Global:Toggle_RestartApps }')
    content = content.replace('elseif ($current -eq 6)', 'elseif ($current -eq 8)')
    content = content.replace('elseif ($current -eq 7)', 'elseif ($current -eq 9)')
    content = content.replace('elseif ($current -eq 8)', 'elseif ($current -eq 10)')
    content = content.replace('elseif ($current -eq 9)', 'elseif ($current -eq 11)')
    content = content.replace('elseif ($current -eq 10)', 'elseif ($current -eq 12)')
    content = content.replace('elseif ($current -eq 11)', 'elseif ($current -eq 13)')
    content = content.replace('elseif ($current -eq 12)', 'elseif ($current -eq 14)')
    content = content.replace('elseif ($current -eq 13)', 'elseif ($current -eq 15)')
    content = content.replace('elseif ($current -eq 14)', 'elseif ($current -eq 16)')
    content = content.replace('elseif ($current -eq 15)', 'elseif ($current -eq 17)')
    content = content.replace('elseif ($current -eq 16)', 'elseif ($current -eq 18)')
    content = content.replace('elseif ($current -eq 17)', 'elseif ($current -eq 19)')
    content = content.replace('elseif ($current -eq 18)', 'elseif ($current -eq 20)')
    content = content.replace('elseif ($current -eq 19)', 'elseif ($current -eq 21)')
    content = content.replace('elseif ($current -eq 20)', 'elseif ($current -eq 22)')
    content = content.replace('elseif ($current -eq 21)', 'elseif ($current -eq 23)')
    content = content.replace('elseif ($current -eq 22)', 'elseif ($current -eq 24)')
    content = content.replace('elseif ($current -eq 23)', 'elseif ($current -eq 25)')
    
    # Execution for maintenance section keys
    content = content.replace('elseif ($current -eq 25) { Invoke-WA_RunUpdateSuite }', 'elseif ($current -eq 27) { Invoke-WA_RunUpdateSuite }')
    content = content.replace('elseif ($current -eq 26) { Invoke-WA_RunOptimizeDisks }', 'elseif ($current -eq 28) { Invoke-WA_RunOptimizeDisks }')
    content = content.replace('elseif ($current -eq 27) { Invoke-WA_RunSystemCleanup }', 'elseif ($current -eq 29) { Invoke-WA_RunSystemCleanup }')
    content = content.replace('elseif ($current -eq 28) { Invoke-WA_RunWindowsRepair }', 'elseif ($current -eq 30) { Invoke-WA_RunWindowsRepair }')

    # Invoke-WinAutoConfiguration block updates
    winauto_str = '    Invoke-Smart "Microsoft Update" { Invoke-WA_SetMicrosoftUpd } -TargetToggle $Global:Toggle_MicrosoftUpd\n'
    winauto_repl = winauto_str + '''    Invoke-Smart "Get Me Up To Date" { Invoke-WA_SetGetMeUpToDate } -TargetToggle $Global:Toggle_GetMeUpToDate
    Invoke-Smart "Metered Updates" { Invoke-WA_SetMeteredUpd } -TargetToggle $Global:Toggle_MeteredUpd
'''
    content = content.replace(winauto_str, winauto_repl)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

update_wa(r'C:\Users\admin\src\github.com\KeithOwns\wa\wa.ps1')
