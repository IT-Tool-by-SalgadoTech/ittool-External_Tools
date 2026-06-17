#Requires -Version 5.1
Set-ExecutionPolicy Bypass -Scope Process -Force
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$ScriptID = "Uninstall_WSL_Reset"

# Force wsl.exe to emit UTF-8 so output parsing is reliable.
$env:WSL_UTF8 = "1"

# Distros that must never be touched by the "ALL" / full reset path.
$ProtectedDistros = @("docker-desktop", "docker-desktop-data")

# ----------------------------------------------------------------------------
# Output helpers (green = ok, red = fail, yellow = warning, cyan = info)
# ----------------------------------------------------------------------------
function Write-Ok    { param([string]$m) Write-Host "[ OK ] $m" -ForegroundColor Green }
function Write-Err   { param([string]$m) Write-Host "[FAIL] $m" -ForegroundColor Red }
function Write-Warn2 { param([string]$m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Info  { param([string]$m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Step  { param([string]$m) Write-Host ""; Write-Host "==== $m ====" -ForegroundColor White }

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WslCore {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    try {
        wsl.exe --status *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

# Returns an array of installed distro names (empty if none / no WSL).
function Get-DistroList {
    if (-not (Test-WslCore)) { return @() }
    try {
        $raw = wsl.exe -l -q 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $raw) { return @() }
        return @($raw | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
    } catch {
        return @()
    }
}

# Case-sensitive "type YES to continue" guard for destructive actions.
function Confirm-Destructive {
    param([string]$Message)
    Write-Warn2 $Message
    $ans = Read-Host "Type  YES  (uppercase) to continue, anything else to cancel"
    if ($ans -ceq "YES") { return $true }
    Write-Info "Cancelled. Nothing was changed."
    return $false
}

# ----------------------------------------------------------------------------
# Actions
# ----------------------------------------------------------------------------
function Show-Distros {
    Write-Step "Installed distributions"
    if (-not (Test-WslCore)) {
        Write-Warn2 "WSL core is not installed (nothing to list)."
        return
    }
    wsl.exe -l -v
    $list = Get-DistroList
    if ($list.Count -eq 0) {
        Write-Info "No distributions are registered."
    }
}

function Remove-OneDistro {
    Write-Step "Unregister ONE distribution"
    $list = Get-DistroList
    if ($list.Count -eq 0) { Write-Warn2 "No distributions to remove."; return }

    Write-Info "Registered distributions:"
    for ($i = 0; $i -lt $list.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $list[$i])
    }
    $sel = Read-Host "Enter the NUMBER of the distribution to delete (0 to cancel)"
    if ($sel -notmatch '^[0-9]+$') { Write-Warn2 "Invalid input."; return }
    $idx = [int]$sel
    if ($idx -lt 1 -or $idx -gt $list.Count) { Write-Info "Cancelled."; return }

    $name = $list[$idx - 1]
    if (-not (Confirm-Destructive "This will PERMANENTLY DELETE '$name' and all its files.")) { return }

    wsl.exe --shutdown
    wsl.exe --unregister $name
    if ($LASTEXITCODE -eq 0) { Write-Ok "'$name' unregistered." }
    else { Write-Err "Failed to unregister '$name' (exit $LASTEXITCODE)." }
}

function Remove-AllDistros {
    Write-Step "Unregister ALL distributions"
    $list = Get-DistroList
    if ($list.Count -eq 0) { Write-Warn2 "No distributions to remove."; return }

    $targets = $list | Where-Object { $ProtectedDistros -notcontains $_ }
    $skipped = $list | Where-Object { $ProtectedDistros -contains $_ }

    if ($skipped.Count -gt 0) {
        Write-Warn2 ("Skipping protected Docker distros: " + ($skipped -join ", "))
    }
    if ($targets.Count -eq 0) { Write-Info "Only protected distros found. Nothing to do."; return }

    Write-Info "Will delete: $($targets -join ', ')"
    if (-not (Confirm-Destructive "This PERMANENTLY DELETES every distro listed above.")) { return }

    wsl.exe --shutdown
    foreach ($name in $targets) {
        Write-Info "Unregistering '$name' ..."
        wsl.exe --unregister $name
        if ($LASTEXITCODE -eq 0) { Write-Ok "'$name' removed." }
        else { Write-Err "Failed on '$name' (exit $LASTEXITCODE)." }
    }
}

function Uninstall-WslApp {
    Write-Step "Uninstall the WSL app"
    if (-not (Confirm-Destructive "This removes the WSL application (the 'wsl' command).")) { return }

    wsl.exe --shutdown
    wsl.exe --uninstall
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "WSL app uninstalled via 'wsl --uninstall'."
        return
    }

    Write-Warn2 "'wsl --uninstall' not available on this build. Trying the Appx package fallback ..."
    try {
        $pkg = Get-AppxPackage -Name "MicrosoftCorporationII.WindowsSubsystemForLinux" -ErrorAction SilentlyContinue
        if ($pkg) {
            $pkg | Remove-AppxPackage -ErrorAction Stop
            Write-Ok "WSL Appx package removed."
        } else {
            Write-Info "No WSL Appx package found. It may be an inbox feature; use option 5 to disable it."
        }
    } catch {
        Write-Err "Appx removal failed: $($_.Exception.Message)"
    }
}

function Disable-WslFeatures {
    Write-Step "Disable WSL Windows features (needs reboot)"
    Write-Warn2 "This disables 'Microsoft-Windows-Subsystem-Linux' and 'VirtualMachinePlatform'."
    Write-Warn2 "'VirtualMachinePlatform' is shared with Hyper-V / Sandbox / other VM features."
    if (-not (Confirm-Destructive "Continue disabling these Windows features?")) { return }

    $restart = $false
    foreach ($feat in @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")) {
        try {
            Write-Info "Disabling feature: $feat ..."
            $r = Disable-WindowsOptionalFeature -Online -FeatureName $feat -NoRestart -ErrorAction Stop
            if ($r.RestartNeeded) { $restart = $true }
            Write-Ok "Feature '$feat' disabled."
        } catch {
            Write-Err "Could not disable '$feat': $($_.Exception.Message)"
        }
    }
    if ($restart) { Write-Warn2 "A REBOOT is required to finish disabling the features." }
}

function Clear-WslData {
    Write-Step "Clean leftover Kali / WSL data folders"
    Write-Warn2 "This deletes leftover package folders and the local 'wsl' storage folder."
    if (-not (Confirm-Destructive "Continue deleting leftover WSL/Kali data?")) { return }

    # 1) Per-app package folders under LOCALAPPDATA\Packages
    $pkgRoot = Join-Path $env:LOCALAPPDATA "Packages"
    if (Test-Path $pkgRoot) {
        $dirs = Get-ChildItem -Path $pkgRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*Kali*" -or $_.Name -like "*WindowsSubsystemForLinux*" }
        foreach ($d in $dirs) {
            try {
                Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction Stop
                Write-Ok "Removed: $($d.FullName)"
            } catch {
                Write-Err "Could not remove $($d.FullName): $($_.Exception.Message)"
            }
        }
    }

    # 2) New-style distro storage: LOCALAPPDATA\wsl
    $wslDir = Join-Path $env:LOCALAPPDATA "wsl"
    if (Test-Path $wslDir) {
        try {
            Remove-Item -LiteralPath $wslDir -Recurse -Force -ErrorAction Stop
            Write-Ok "Removed: $wslDir"
        } catch {
            Write-Err "Could not remove ${wslDir}: $($_.Exception.Message)"
        }
    }

    # 3) Global WSL config in the user profile
    $wslCfg = Join-Path $env:USERPROFILE ".wslconfig"
    if (Test-Path $wslCfg) {
        try {
            Remove-Item -LiteralPath $wslCfg -Force -ErrorAction Stop
            Write-Ok "Removed: $wslCfg"
        } catch {
            Write-Err "Could not remove ${wslCfg}: $($_.Exception.Message)"
        }
    }

    Write-Ok "Leftover data cleanup finished."
}

function Invoke-FullReset {
    Write-Step "FULL RESET FROM ZERO"
    Write-Warn2 "Steps: unregister ALL distros (Docker skipped) -> uninstall WSL app ->"
    Write-Warn2 "       disable WSL features -> clean leftover data. A REBOOT will be needed."
    if (-not (Confirm-Destructive "This is the full destructive reset. Proceed?")) { return }

    Remove-AllDistros
    Uninstall-WslApp
    Disable-WslFeatures
    Clear-WslData

    Write-Host ""
    Write-Ok    "Full reset finished."
    Write-Warn2 "REBOOT the PC now, then run the installer script for a clean install."
}

# ----------------------------------------------------------------------------
# Menu
# ----------------------------------------------------------------------------
function Show-Menu {
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor White
    Write-Host "  WSL / Kali Uninstaller - Reset from zero"      -ForegroundColor White
    Write-Host "  ScriptID: $ScriptID"                           -ForegroundColor DarkGray
    Write-Host "===============================================" -ForegroundColor White
    Write-Host "  [1] Show installed distributions"
    Write-Host "  [2] Unregister ONE distribution        (delete)"
    Write-Host "  [3] Unregister ALL distributions        (delete)"
    Write-Host "  [4] Uninstall the WSL app"
    Write-Host "  [5] Disable WSL Windows features  (needs reboot)"
    Write-Host "  [6] Clean leftover Kali / WSL data     (delete)"
    Write-Host "  [7] FULL RESET from zero (3+4+5+6)     (delete)"
    Write-Host "  [0] Exit"
    Write-Host "==============================================="
}

# ----------------------------------------------------------------------------
# Header
# ----------------------------------------------------------------------------
Write-Host ""
Write-Host " _____ _____  _______ ____   ____  _     " -ForegroundColor Cyan
Write-Host "|_   _|_   _||__   __/ __ \ / __ \| |    " -ForegroundColor Cyan
Write-Host "  | |   | |     | | | |  | | |  | | |    " -ForegroundColor Cyan
Write-Host "  | |   | |     | | | |  | | |  | | |    " -ForegroundColor Cyan
Write-Host " _| |_  | |     | | | |__| | |__| | |___ " -ForegroundColor Cyan
Write-Host "|_____| |_|     |_|  \____/ \____/|_____|" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ==================================================================" -ForegroundColor White
Write-Host "  IT-Tool by SalgadoTech" -ForegroundColor Cyan
Write-Host "  Script: Delete_WSL.ps1" -ForegroundColor DarkCyan
Write-Host "  ScriptID: (pending)" -ForegroundColor Cyan
Write-Host "  Version: 1.0" -ForegroundColor DarkCyan
Write-Host "  Date: 2026-06-16" -ForegroundColor DarkCyan
Write-Host "  Category: Windows > WSL" -ForegroundColor DarkCyan
Write-Host "  Description: Remove WSL and all Linux distributions from Windows" -ForegroundColor DarkCyan
Write-Host "  (c) 2025 SalgadoTech - All Rights Reserved" -ForegroundColor DarkCyan
Write-Host "  Unauthorized distribution prohibited" -ForegroundColor DarkCyan
Write-Host "  ==================================================================" -ForegroundColor White
Write-Host ""

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
if (-not (Test-Admin)) {
    Write-Err  "This script must run in an ELEVATED PowerShell (Run as administrator)."
    Write-Info "Right-click PowerShell, choose 'Run as administrator', then run it again."
    return
}

Write-Ok    "Running with administrator rights."
Write-Warn2 "Reminder: unregistering a distribution permanently deletes all its files."

do {
    Show-Menu
    $choice = Read-Host "Select an option"
    switch ($choice) {
        "1" { Show-Distros }
        "2" { Remove-OneDistro }
        "3" { Remove-AllDistros }
        "4" { Uninstall-WslApp }
        "5" { Disable-WslFeatures }
        "6" { Clear-WslData }
        "7" { Invoke-FullReset }
        "0" { Write-Info "Exiting." }
        default { Write-Warn2 "Invalid option." }
    }
    if ($choice -ne "0") {
        Write-Host ""
        Read-Host "Press ENTER to return to the menu"
    }
} while ($choice -ne "0")