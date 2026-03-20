# COLOR_THEME_SELECTOR

Write-Host ""
Write-Host "  Choose a color theme:" -ForegroundColor White
Write-Host ""
Write-Host "  [1] " -NoNewline -ForegroundColor White; Write-Host "Green classic    " -ForegroundColor Green   -NoNewline; Write-Host "(current style)"    -ForegroundColor DarkGray
Write-Host "  [2] " -NoNewline -ForegroundColor White; Write-Host "Purple           " -ForegroundColor Magenta -NoNewline; Write-Host "(purple vibes)"     -ForegroundColor DarkGray
Write-Host "  [3] " -NoNewline -ForegroundColor White; Write-Host "Cyan             " -ForegroundColor Cyan    -NoNewline; Write-Host "(ice blue)"         -ForegroundColor DarkGray
Write-Host "  [4] " -NoNewline -ForegroundColor White; Write-Host "Restore default  " -ForegroundColor Gray    -NoNewline; Write-Host "(original Windows)" -ForegroundColor DarkGray
Write-Host ""

$option = Read-Host "  Type the number and press Enter"

switch ($option) {
    "1" { $fg = "Green";   $label = "Green classic" }
    "2" { $fg = "Magenta"; $label = "Purple"        }
    "3" { $fg = "Cyan";    $label = "Cyan"          }
    "4" { $fg = $null;     $label = "Default"       }
    default { Write-Host "  Invalid option." -ForegroundColor Red; exit }
}

$GREEN_BGR  = 0x00008000
$PURPLE_BGR = 0x00AA2299
$CYAN_BGR   = 0x00CCAA00
$BLACK      = 0x00000000

$sid = (Get-ChildItem Registry::HKEY_USERS | Where-Object {
    $_.PSChildName -match '^S-1-5-21-.*$' -and $_.PSChildName -notmatch '_Classes$'
} | Select-Object -First 1).PSChildName

$paths = @(
    "Registry::HKEY_USERS\$sid\Console",
    "Registry::HKEY_USERS\$sid\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe",
    "Registry::HKEY_USERS\$sid\Console\%SystemRoot%_SysWOW64_WindowsPowerShell_v1.0_powershell.exe",
    "Registry::HKEY_USERS\$sid\Console\%SystemRoot%_system32_cmd.exe",
    "Registry::HKEY_USERS\$sid\Console\%SystemRoot%_SysWOW64_cmd.exe"
)

foreach ($p in $paths) {
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }

    switch ($option) {
        "1" {
            New-ItemProperty -Path $p -Name ScreenColors -PropertyType DWord -Value 0x02       -Force | Out-Null
            New-ItemProperty -Path $p -Name PopupColors  -PropertyType DWord -Value 0x02       -Force | Out-Null
            New-ItemProperty -Path $p -Name ColorTable2  -PropertyType DWord -Value $GREEN_BGR -Force | Out-Null
            New-ItemProperty -Path $p -Name ColorTable0  -PropertyType DWord -Value $BLACK     -Force | Out-Null
        }
        "2" {
            New-ItemProperty -Path $p -Name ScreenColors -PropertyType DWord -Value 0x05        -Force | Out-Null
            New-ItemProperty -Path $p -Name PopupColors  -PropertyType DWord -Value 0x05        -Force | Out-Null
            New-ItemProperty -Path $p -Name ColorTable5  -PropertyType DWord -Value $PURPLE_BGR -Force | Out-Null
            New-ItemProperty -Path $p -Name ColorTable0  -PropertyType DWord -Value $BLACK      -Force | Out-Null
        }
        "3" {
            New-ItemProperty -Path $p -Name ScreenColors -PropertyType DWord -Value 0x03       -Force | Out-Null
            New-ItemProperty -Path $p -Name PopupColors  -PropertyType DWord -Value 0x03       -Force | Out-Null
            New-ItemProperty -Path $p -Name ColorTable3  -PropertyType DWord -Value $CYAN_BGR  -Force | Out-Null
            New-ItemProperty -Path $p -Name ColorTable0  -PropertyType DWord -Value $BLACK     -Force | Out-Null
        }
        "4" {
            # Restore original blue PowerShell
            New-ItemProperty -Path $p -Name ScreenColors -PropertyType DWord -Value 0x1F       -Force | Out-Null
            New-ItemProperty -Path $p -Name PopupColors  -PropertyType DWord -Value 0xF5       -Force | Out-Null
            New-ItemProperty -Path $p -Name ColorTable01 -PropertyType DWord -Value 0x00562401 -Force | Out-Null
            # Remove all custom color entries
            foreach ($i in 0..15) {
                foreach ($name in "ColorTable$i", "ColorTable0$i") {
                    if (Get-ItemProperty -Path $p -Name $name -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -Path $p -Name $name -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            New-ItemProperty -Path $p -Name ColorTable01 -PropertyType DWord -Value 0x00562401 -Force | Out-Null
        }
    }
}

# Clean profile - remove any previous color block
if (!(Test-Path $PROFILE)) { New-Item -Path $PROFILE -ItemType File -Force | Out-Null }
$current = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
$cleaned = $current -replace '(?s)# ===== COLORS =====.*?# ===== END COLORS =====\s*', ''
$cleaned = $cleaned -replace '(?s)# ===== COLORES PERSONALIZADOS =====.*?# ===== FIN COLORES PERSONALIZADOS =====\s*', ''
Set-Content -Path $PROFILE -Value $cleaned.Trim()

if ($fg) {
    # Apply immediately to current session
    $host.UI.RawUI.BackgroundColor = "Black"
    $host.UI.RawUI.ForegroundColor = $fg
    Clear-Host

    $block = @"

# ===== COLORS =====
`$host.UI.RawUI.BackgroundColor            = "Black"
`$host.UI.RawUI.ForegroundColor            = "$fg"
`$host.PrivateData.ErrorForegroundColor    = "Red"
`$host.PrivateData.WarningForegroundColor  = "Yellow"
`$host.PrivateData.VerboseForegroundColor  = "Cyan"
Clear-Host
# ===== END COLORS =====
"@
    Add-Content -Path $PROFILE -Value $block
    Write-Host "  Theme '$label' applied and saved permanently." -ForegroundColor $fg
} else {
    Clear-Host
    Write-Host "  Restored to original Windows blue. Close and reopen PowerShell." -ForegroundColor Cyan
}

Write-Host ""
