param(
    [string]$SourceDir = "E:\Retrobat7.4\roms\mame",
    [string]$ListPath  = "",
    [string]$DestDir   = "E:\Retrobat7.4\mame_vertical"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-PathInput {
    param([string]$p)
    if ([string]::IsNullOrWhiteSpace($p)) { return "" }
    return $p.Trim().Trim('"').Trim("'")
}

function Ensure-Folder {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Find-ListFileAuto {
    # Busca *vertical*.txt en carpeta del script y Downloads; elige el más reciente
    $candidates = @()

    $scriptRoot = $PSScriptRoot
    if (-not [string]::IsNullOrWhiteSpace($scriptRoot) -and (Test-Path -LiteralPath $scriptRoot)) {
        $candidates += Get-ChildItem -LiteralPath $scriptRoot -File -Filter "*vertical*.txt" -ErrorAction SilentlyContinue
    }

    $downloads = Join-Path $env:USERPROFILE "Downloads"
    if (Test-Path -LiteralPath $downloads) {
        $candidates += Get-ChildItem -LiteralPath $downloads -File -Filter "*vertical*.txt" -ErrorAction SilentlyContinue
    }

    if ($candidates.Count -eq 0) { return $null }

    return ($candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function Read-NonEmptyLines {
    param([Parameter(Mandatory=$true)][string]$Path)

    $lines = Get-Content -LiteralPath $Path -ErrorAction Stop

    $clean = foreach ($l in $lines) {
        $t = ($l -replace "^\uFEFF","").Trim()  # strip UTF-8 BOM if present
        if ($t.Length -eq 0) { continue }
        if ($t.StartsWith("#") -or $t.StartsWith(";")) { continue }
        $t
    }

    # Unique, case-insensitive
    $set = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($c in $clean) { [void]$set.Add($c) }
    return $set
}

# ---- Normalize inputs ----
$SourceDir = Normalize-PathInput $SourceDir
$ListPath  = Normalize-PathInput $ListPath
$DestDir   = Normalize-PathInput $DestDir

Write-Host ""
Write-Host "=== Copy Vertical MAME ROMs ==="
Write-Host "Source: $SourceDir"
Write-Host "Dest  : $DestDir"
Write-Host ""

# ---- Validate source ----
if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
    Write-Host "ERROR: Source folder not found: $SourceDir" -ForegroundColor Red
    exit 1
}

# ---- Determine list path ----
if ([string]::IsNullOrWhiteSpace($ListPath)) {
    $auto = Find-ListFileAuto
    if ($null -ne $auto) {
        $ListPath = $auto
        Write-Host "List TXT auto-detected: $ListPath"
    }
}

# If user passed something without .txt, try appending .txt
if (-not [string]::IsNullOrWhiteSpace($ListPath) -and -not (Test-Path -LiteralPath $ListPath -PathType Leaf)) {
    if (-not $ListPath.ToLower().EndsWith(".txt")) {
        $tryTxt = $ListPath + ".txt"
        if (Test-Path -LiteralPath $tryTxt -PathType Leaf) {
            $ListPath = $tryTxt
            Write-Host "List TXT corrected to: $ListPath"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ListPath) -or -not (Test-Path -LiteralPath $ListPath -PathType Leaf)) {
    Write-Host "ERROR: List TXT not found." -ForegroundColor Red
    Write-Host "Fix: Put your list file in Downloads or same folder as this script, named like *vertical*.txt"
    Write-Host "Or run with explicit path, example:"
    Write-Host '  .\Copy-VerticalMAME.ps1 -ListPath "C:\Users\<you>\Downloads\vertical games.txt"'
    Write-Host ""
    Write-Host "To see what vertical TXT files you have in Downloads:"
    Write-Host '  Get-ChildItem "$env:USERPROFILE\Downloads" -Filter "*vertical*.txt" | Select Name, FullName'
    exit 2
}

# ---- Ensure destination ----
Ensure-Folder -Path $DestDir

# ---- Load wanted set names ----
$wanted = Read-NonEmptyLines -Path $ListPath
Write-Host ("Loaded {0} set names from: {1}" -f $wanted.Count, $ListPath)

# ---- Index archives (.zip/.7z) ----
Write-Host "Indexing .zip/.7z in source..."
$archives = Get-ChildItem -LiteralPath $SourceDir -File -ErrorAction Stop |
            Where-Object { $_.Extension -in ".zip", ".7z" }

$map = New-Object "System.Collections.Generic.Dictionary[string,string]" ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($f in $archives) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    if (-not $map.ContainsKey($base)) {
        $map[$base] = $f.FullName
    } else {
        # Prefer .zip over .7z
        $existing = $map[$base]
        if ($f.Extension -eq ".zip" -and ([System.IO.Path]::GetExtension($existing) -ne ".zip")) {
            $map[$base] = $f.FullName
        }
    }
}

# ---- Copy with fault tolerance ----
$copiedArchives = 0
$copiedFolders  = 0
$missing = New-Object "System.Collections.Generic.List[string]"
$copyFailed = New-Object "System.Collections.Generic.List[string]"

Write-Host "Copying..."

foreach ($name in $wanted) {
    $foundAny = $false

    # Archive copy
    if ($map.ContainsKey($name)) {
        $srcFile = $map[$name]
        $dstFile = Join-Path $DestDir ([System.IO.Path]::GetFileName($srcFile))
        try {
            Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force -ErrorAction Stop
            $copiedArchives++
        } catch {
            $copyFailed.Add("$name`tARCHIVE`t$srcFile`t$($_.Exception.Message)") | Out-Null
        }
        $foundAny = $true  # existed, even if copy failed
    }

    # CHD folder copy (same-name folder)
    $srcFolder = Join-Path $SourceDir $name
    if (Test-Path -LiteralPath $srcFolder -PathType Container) {
        $dstFolder = Join-Path $DestDir $name
        try {
            Copy-Item -LiteralPath $srcFolder -Destination $dstFolder -Recurse -Force -ErrorAction Stop
            $copiedFolders++
        } catch {
            $copyFailed.Add("$name`tFOLDER`t$srcFolder`t$($_.Exception.Message)") | Out-Null
        }
        $foundAny = $true
    }

    if (-not $foundAny) {
        $missing.Add($name) | Out-Null
    }
}

# ---- Reports ----
$missingPath = Join-Path $DestDir "missing_vertical_sets.txt"
$failedPath  = Join-Path $DestDir "copy_failed_vertical_sets.txt"

$missing | Sort-Object | Set-Content -LiteralPath $missingPath -Encoding UTF8

"SET`tTYPE`tSOURCE`tERROR" | Set-Content -LiteralPath $failedPath -Encoding UTF8
if ($copyFailed.Count -gt 0) {
    $copyFailed | Set-Content -LiteralPath $failedPath -Encoding UTF8 -Append
}

Write-Host ""
Write-Host "Done."
Write-Host ("Archives copied    : {0}" -f $copiedArchives)
Write-Host ("CHD folders copied : {0}" -f $copiedFolders)
Write-Host ("Missing sets       : {0}" -f $missing.Count)
Write-Host ("Copy failed items  : {0}" -f $copyFailed.Count)
Write-Host ("Missing report     : {0}" -f $missingPath)
Write-Host ("Failed report      : {0}" -f $failedPath)
Write-Host ""
Write-Host "Note: This copies only sets listed in TXT + same-named CHD folders. BIOS/device zips are separate."