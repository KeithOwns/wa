import re

with open('wa.ps1', 'r', encoding='utf-8') as f:
    c = f.read()

# Replace spaces logic in Write-ColItem
c = c.replace(
    '$leftCursor = if ($IsSelected) { "${Global:FGYellow}>${Global:Reset}  " } else { "   " }',
    '$leftCursor = if ($IsSelected) { "${Global:FGYellow}>${Global:Reset}  " } else { "" }\n        $indentSize = if ($IsSelected) { 0 } else { 3 }'
)

c = re.sub(r'Write-LeftAligned "\$leftCursor(.*?)\$rightCursor" -Indent 0', r'Write-LeftAligned "$leftCursor\1$rightCursor" -Indent $indentSize', c)

# Replace padding 22 -> 21
c = c.replace('$pad = " " * (22 - $Txt.Length)', '$pad = " " * (21 - $Txt.Length)')

# Fix MaintItem
c = c.replace(
    '$pad = " " * (21 - $Txt.Length); \n    $leftCursor = if ($IsSelected) { "${Global:FGYellow}>${Global:Reset}  " } else { "   " }\n    $rightCursor = if ($IsSelected) { "  ${Global:FGYellow}<${Global:Reset}" } else { "" }\n    Write-LeftAligned "$leftCursor${FGDarkGray}[${statusColor}$prefix${FGDarkGray}]${itemColor} $Txt${Reset}$pad${FGDarkGray}| ${itemColor}$Met${Reset}$rightCursor" -Indent 0  ',
    '$padLength = 21 - $Txt.Length - ($prefix.ToString().Length - 1)\n    if ($padLength -lt 1) { $padLength = 1 }\n    $pad = " " * $padLength\n    $leftCursor = if ($IsSelected) { "${Global:FGYellow}>${Global:Reset}  " } else { "" }\n    $indentSize = if ($IsSelected) { 0 } else { 3 }\n    $rightCursor = if ($IsSelected) { "  ${Global:FGYellow}<${Global:Reset}" } else { "" }\n    Write-LeftAligned "$leftCursor${FGDarkGray}[${statusColor}$prefix${FGDarkGray}]${itemColor} $Txt${Reset}$pad${FGDarkGray}| ${itemColor}$Met${Reset}$rightCursor" -Indent $indentSize  '
)

with open('wa.ps1', 'w', encoding='utf-8') as f:
    f.write(c)
