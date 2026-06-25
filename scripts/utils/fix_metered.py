import re

with open("wa.ps1", "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    # Remove global toggle init
    if "$Global:Toggle_MeteredUpd = 0" in line:
        continue
    # Remove reg check
    if "$s_Metered = Test-Reg" in line and "AllowAutoWindowsUpdateDownloadOverMeteredNetwork" in line:
        continue
    # Remove Invoke-Smart call
    if "Invoke-Smart { Invoke-WA_SetMeteredUpd } $s_Metered" in line:
        continue
    # Remove Write-ColItem
    if 'Write-ColItem "Metered Updates"' in line:
        continue
    # Remove Toggle block
    if 'elseif ($Target -eq 3) {' in line:
        skip = True
        continue
    if skip and '}' in line:
        skip = False
        continue
    if skip:
        continue
    
    # Remove the actual function
    if 'function Invoke-WA_SetMeteredUpd {' in line:
        skip = True
        continue
        
    # Update Enter key
    if 'elseif ($Target -eq 2) {' in lines[i-1] if i>0 else False:
        if '$Global:MenuSelection = 3' in line:
            line = line.replace('= 3', '= 4')
            
    # Update UP arrow
    if 'elseif ($current -eq 3) {' in line:
        skip = True
        continue
        
    if 'elseif ($current -ge 4 -and $current -le 25) {' in line:
        # replace with eq 4 and ge 5
        line = line.replace('elseif ($current -ge 4 -and $current -le 25) {', 
                            'elseif ($current -eq 4) {\n            $Global:MenuSelection = 2\n        }\n        elseif ($current -ge 5 -and $current -le 25) {')
                            
    new_lines.append(line)

with open("wa.ps1", "w", encoding="utf-8") as f:
    f.writelines(new_lines)
