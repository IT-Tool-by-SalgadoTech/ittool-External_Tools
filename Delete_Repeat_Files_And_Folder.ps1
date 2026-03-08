Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-Sha256String([string]$text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        $hashBytes = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hashBytes) -replace "-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Is-PathUnder([string]$child, [string]$parent) {
    $childFull  = ([System.IO.Path]::GetFullPath($child)).TrimEnd('\') + '\'
    $parentFull = ([System.IO.Path]::GetFullPath($parent)).TrimEnd('\') + '\'
    return $childFull.StartsWith($parentFull, [System.StringComparison]::OrdinalIgnoreCase)
}

Write-Host "Enter the source folder path (example: C:\Data):"
$Source = Read-Host

if ([string]::IsNullOrWhiteSpace($Source)) { throw "No folder provided." }
if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Folder not found: $Source" }

$Source = (Resolve-Path -LiteralPath $Source).Path

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$TrashRoot = Join-Path $Source "__DUPLICATES_TRASH___$timestamp"
New-Item -ItemType Directory -Path $TrashRoot | Out-Null

$LogPath = Join-Path $TrashRoot "duplicate_cleaner_log.txt"
"Duplicate Cleaner Log - $(Get-Date)" | Out-File -FilePath $LogPath -Encoding UTF8

Write-Host ""
Write-Host "Source: $Source"
Write-Host "Trash : $TrashRoot"
Write-Host "Log   : $LogPath"
Write-Host ""

# Cache hashes to avoid re-hashing
$fileHashCache = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)

function Get-CachedFileHash([string]$filePath) {
    if ($fileHashCache.ContainsKey($filePath)) { return $fileHashCache[$filePath] }
    $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $filePath).Hash.ToLowerInvariant()
    $fileHashCache[$filePath] = $h
    return $h
}

Write-Host "Scanning folders..."
$allDirs = @(
    Get-ChildItem -LiteralPath $Source -Recurse -Directory -Force |
    Where-Object { $_.FullName -ne $TrashRoot -and -not (Is-PathUnder $_.FullName $TrashRoot) }
)

Write-Host "Scanning files..."
$allFiles = @(
    Get-ChildItem -LiteralPath $Source -Recurse -File -Force |
    Where-Object { -not (Is-PathUnder $_.FullName $TrashRoot) }
)

# =======================
# 1) Duplicate FOLDERS by content signature
# =======================
$folderGroups = @{}  # signature => List[string]

if ($allDirs.Count -gt 0) {
    Write-Host "Building folder signatures to find duplicate folders..."

    $dirCount = $allDirs.Count
    $dirIndex = 0

    foreach ($dir in $allDirs) {
        $dirIndex++
        if ($dirCount -gt 0 -and ($dirIndex % 50 -eq 0)) {
            Write-Progress -Activity "Folder signature scan" -Status "$dirIndex / $dirCount" -PercentComplete ([int](($dirIndex/$dirCount)*100))
        }

        $dirPath = $dir.FullName

        try {
            $filesUnder = @(
                Get-ChildItem -LiteralPath $dirPath -Recurse -File -Force |
                Where-Object { -not (Is-PathUnder $_.FullName $TrashRoot) }
            )

            if ($filesUnder.Count -eq 0) {
                $sig = New-Sha256String("EMPTY")
            } else {
                $lines = foreach ($f in $filesUnder) {
                    $rel = $f.FullName.Substring($dirPath.Length).TrimStart('\','/')
                    $fh  = Get-CachedFileHash $f.FullName
                    "$rel|$fh"
                }
                $sig = New-Sha256String( ($lines | Sort-Object) -join "`n" )
            }

            if (-not $folderGroups.ContainsKey($sig)) {
                $folderGroups[$sig] = New-Object System.Collections.Generic.List[string]
            }
            $folderGroups[$sig].Add($dirPath)
        }
        catch {
            "WARN FolderSignatureFailed: $dirPath :: $($_.Exception.Message)" | Tee-Object -FilePath $LogPath -Append | Out-Null
        }
    }

    Write-Progress -Activity "Folder signature scan" -Completed
} else {
    Write-Host "No subfolders found (skipping duplicate folder scan)."
}

# Build list of duplicate folders to move (keep one, move the rest)
$candidateFoldersToMove = New-Object System.Collections.Generic.List[string]
foreach ($kv in $folderGroups.GetEnumerator()) {
    if ($kv.Value.Count -gt 1) {
        $paths = $kv.Value | Sort-Object
        $paths | Select-Object -Skip 1 | ForEach-Object { $candidateFoldersToMove.Add($_) }
    }
}

# Move deeper first and skip nested under already moved parents
$candidateFoldersToMove = @($candidateFoldersToMove) | Sort-Object { $_.Length } -Descending

# =======================
# 2) Duplicate FILES by hash
# =======================
Write-Host ""
Write-Host "Finding duplicate files (SHA-256)..."

$hashGroups = @{}  # hash => List[string]

# Group by size first (faster)
$sizeGroups = $allFiles | Group-Object Length | Where-Object { $_.Count -gt 1 }

$sgCount = $sizeGroups.Count
$sgIndex = 0

foreach ($sg in $sizeGroups) {
    $sgIndex++
    if ($sgCount -gt 0) {
        Write-Progress -Activity "File duplicate scan (hashing candidates)" -Status "$sgIndex / $sgCount" -PercentComplete ([int](($sgIndex/$sgCount)*100))
    }

    foreach ($f in $sg.Group) {
        try {
            $h = Get-CachedFileHash $f.FullName
            if (-not $hashGroups.ContainsKey($h)) {
                $hashGroups[$h] = New-Object System.Collections.Generic.List[string]
            }
            $hashGroups[$h].Add($f.FullName)
        }
        catch {
            "WARN FileHashFailed: $($f.FullName) :: $($_.Exception.Message)" | Tee-Object -FilePath $LogPath -Append | Out-Null
        }
    }
}

Write-Progress -Activity "File duplicate scan (hashing candidates)" -Completed

$dupFilesToMove = New-Object System.Collections.Generic.List[string]
foreach ($kv in $hashGroups.GetEnumerator()) {
    if ($kv.Value.Count -gt 1) {
        $paths = $kv.Value | Sort-Object
        $paths | Select-Object -Skip 1 | ForEach-Object { $dupFilesToMove.Add($_) }
    }
}

Write-Host ""
Write-Host "Duplicate folders found (to move): $($candidateFoldersToMove.Count)"
Write-Host "Duplicate files found   (to move): $($dupFilesToMove.Count)"
Write-Host ""

Write-Host "This script will MOVE duplicates into the Trash folder shown above (safer than permanent delete)."
Write-Host "Proceed? (Y/N)"
$ans = Read-Host
if ($ans -notmatch '^(Y|y)$') {
    Write-Host "Cancelled. Nothing changed."
    exit 0
}

# =======================
# MOVE DUPLICATE FOLDERS
# =======================
if ($candidateFoldersToMove.Count -gt 0) {
    Write-Host "Moving duplicate folders..."
    $movedParents = New-Object System.Collections.Generic.List[string]

    foreach ($folderPath in $candidateFoldersToMove) {
        if (-not (Test-Path -LiteralPath $folderPath -PathType Container)) { continue }

        $skip = $false
        foreach ($p in $movedParents) {
            if (Is-PathUnder $folderPath $p) { $skip = $true; break }
        }
        if ($skip) { continue }

        $safeName = ($folderPath.TrimEnd('\') -replace '[:\\\/]', '_')
        $dest = Join-Path $TrashRoot ("FOLDER_" + $safeName)

        $i = 0
        while (Test-Path -LiteralPath $dest) { $i++; $dest = Join-Path $TrashRoot ("FOLDER_" + $safeName + "_$i") }

        try {
            Move-Item -LiteralPath $folderPath -Destination $dest
            $movedParents.Add($dest) | Out-Null
            "MOVED FOLDER: $folderPath -> $dest" | Tee-Object -FilePath $LogPath -Append | Out-Null
        }
        catch {
            "ERROR MoveFolderFailed: $folderPath :: $($_.Exception.Message)" | Tee-Object -FilePath $LogPath -Append | Out-Null
        }
    }
}

# =======================
# MOVE DUPLICATE FILES
# =======================
if ($dupFilesToMove.Count -gt 0) {
    Write-Host "Moving duplicate files..."
    foreach ($filePath in $dupFilesToMove) {
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { continue }

        $rel = $filePath.Substring($Source.Length).TrimStart('\','/')
        $destDir = Join-Path $TrashRoot "FILES"
        $destPath = Join-Path $destDir $rel

        try {
            $destFolder = Split-Path -Path $destPath -Parent
            New-Item -ItemType Directory -Path $destFolder -Force | Out-Null

            if (Test-Path -LiteralPath $destPath) {
                $base = [System.IO.Path]::GetFileNameWithoutExtension($destPath)
                $ext  = [System.IO.Path]::GetExtension($destPath)
                $par  = Split-Path -Path $destPath -Parent
                $i = 1
                do {
                    $destPath2 = Join-Path $par ("$base`_dup$i$ext")
                    $i++
                } while (Test-Path -LiteralPath $destPath2)
                $destPath = $destPath2
            }

            Move-Item -LiteralPath $filePath -Destination $destPath
            "MOVED FILE: $filePath -> $destPath" | Tee-Object -FilePath $LogPath -Append | Out-Null
        }
        catch {
            "ERROR MoveFileFailed: $filePath :: $($_.Exception.Message)" | Tee-Object -FilePath $LogPath -Append | Out-Null
        }
    }
}

Write-Host ""
Write-Host "Done."
Write-Host "Trash folder: $TrashRoot"
Write-Host "Log file    : $LogPath"
Write-Host "Review the Trash folder; if all good, delete it to permanently remove duplicates."