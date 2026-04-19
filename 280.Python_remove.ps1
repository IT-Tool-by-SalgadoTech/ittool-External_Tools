# Requires: Run as Administrator
# Remove-Python-Completely.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

Write-Host "`n=== PYTHON COMPLETE REMOVAL START ===`n"

# 1️⃣ Desinstalar todas las versiones detectadas por winget
Write-Host "Checking installed Python versions..."
$pyPackages = winget list --source winget | Select-String -Pattern "Python"

foreach ($pkg in $pyPackages) {
    if ($pkg -match "Python\.Python") {
        $id = ($pkg -split "\s+")[1]
        Write-Host "Uninstalling $id ..."
        winget uninstall --id $id --silent --accept-source-agreements --accept-package-agreements
    }
}

# 2️⃣ Desactivar App Execution Aliases
Write-Host "Disabling Python App Execution Aliases..."
$aliasesPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths"
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Execution Aliases" -Name "python.exe" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Execution Aliases" -Name "python3.exe" -ErrorAction SilentlyContinue

# 3️⃣ Limpiar PATH (Usuario y Sistema)
Write-Host "Cleaning PATH variables..."

function Remove-PythonFromPath {
    param ($Scope)

    $envKey = if ($Scope -eq "User") {
        "HKCU:\Environment"
    } else {
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
    }

    $currentPath = (Get-ItemProperty -Path $envKey -Name Path).Path
    $newPath = ($currentPath -split ";" | Where-Object {$_ -notmatch "Python"}) -join ";"

    Set-ItemProperty -Path $envKey -Name Path -Value $newPath
}

Remove-PythonFromPath -Scope "User"
Remove-PythonFromPath -Scope "System"

# 4️⃣ Eliminar carpetas residuales comunes
Write-Host "Removing residual folders..."

$pathsToRemove = @(
    "$env:LOCALAPPDATA\Programs\Python",
    "$env:APPDATA\Python",
    "C:\Python*"
)

foreach ($path in $pathsToRemove) {
    Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
}

# 5️⃣ Verificación final
Write-Host "`nVerifying removal..."
$check = Get-Command python -ErrorAction SilentlyContinue

if ($check) {
    Write-Host "Python still detected in system PATH."
} else {
    Write-Host "Python completely removed from system."
}

Write-Host "`n=== DONE ==="