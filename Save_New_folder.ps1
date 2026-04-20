[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "======================================" -ForegroundColor Magenta
Write-Host "   IT-Tool - ReadyUSB New Folder" -ForegroundColor Magenta
Write-Host "======================================" -ForegroundColor Magenta
Write-Host ""

# ============================================================
#  STEP 0 — CONNECT IT-TOOL
# ============================================================
Write-Host "Before continuing:" -ForegroundColor Yellow
Write-Host "  1. Unplug the IT-Tool USB cable" -ForegroundColor White
Write-Host "  2. Plug it back in" -ForegroundColor White
Write-Host ""
Read-Host "Come back here and press 'ENTER'"

# ============================================================
#  STEP 1 — DETECT COM PORT
# ============================================================
$comPort = ""
$availablePorts = @()

$availablePorts = @(Get-PnpDevice -Class Ports -ErrorAction SilentlyContinue |
    Where-Object { $_.Status -eq "OK" -and $_.FriendlyName -match "COM\d+" } |
    ForEach-Object { [regex]::Match($_.FriendlyName, "COM\d+").Value } |
    Where-Object { $_ -ne "" } |
    Sort-Object)

if ($availablePorts.Count -eq 0) {
    Write-Host "No COM ports detected. Check IT-Tool USB connection." -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit
}
Write-Host ""
Write-Host "Available COM ports:" -ForegroundColor Cyan
for ($i = 0; $i -lt $availablePorts.Count; $i++) {
    Write-Host "  $($i + 1). $($availablePorts[$i])"
}
Write-Host ""
while ([string]::IsNullOrWhiteSpace($comPort)) {
    $choice = (Read-Host "Select port number").Trim()
    $idx = 0
    if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 1 -and $idx -le $availablePorts.Count) {
        $comPort = $availablePorts[$idx - 1]
    } else {
        Write-Host "  Invalid option." -ForegroundColor Yellow
    }
}
Write-Host "Using $comPort" -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 2 — CONTROLLED RESET
# ============================================================
Write-Host "IT-Tool reset, Please come to:" -ForegroundColor Yellow
try {
    $portReset = New-Object System.IO.Ports.SerialPort $comPort, 115200, None, 8, One
    $portReset.DtrEnable = $false
    $portReset.RtsEnable = $false
    $portReset.Open()
    Start-Sleep -Milliseconds 400
    $portReset.Close()
} catch {
    Write-Host "Reset warning: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host "ReadyUSB > Script_Saver." -ForegroundColor Green
Write-Host ""
Read-Host "Press ENTER when IT-Tool shows 'Waiting...'"
Write-Host ""

# ============================================================
#  STEP 3 — FOLDER NAME
# ============================================================
$folderName = ""
while ([string]::IsNullOrWhiteSpace($folderName)) {
    $folderName = (Read-Host "New folder name").Trim()
    $folderName = $folderName -replace ' ','_'
}

# ============================================================
#  STEP 4 — GROUP (Windows / Linux)
# ============================================================
Write-Host ""
Write-Host "Choose group:" -ForegroundColor Cyan
Write-Host "  1. Windows"
Write-Host "  2. Linux"
Write-Host ""

$groupPath = ""
while ([string]::IsNullOrWhiteSpace($groupPath)) {
    $mg = (Read-Host "Group").Trim()
    switch ($mg) {
        "1" { $groupPath = "B.OS_System/A.Windows" }
        "2" { $groupPath = "B.OS_System/B.Linux"   }
        default { Write-Host "  Invalid option." -ForegroundColor Yellow }
    }
}

$targetFolder = "$groupPath/$folderName"
Write-Host "Destination: $targetFolder" -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 5 — BUILD THE DUCKY SCRIPT
# ============================================================
$nl   = "`n"
$duck = 'DELAY 1000' + $nl +
        'STRINGLN' + $nl +
        'REM folder placeholder' + $nl +
        'END_STRINGLN'

# ============================================================
#  STEP 6 — ASSEMBLE THE PACKET
# ============================================================
$fileName = ".keep"
$packet = "FOLDER:$targetFolder`nNAME:$fileName`nDATA:`n$duck`nEND_SCRIPT_SAVER`n"
$bytes  = [System.Text.Encoding]::UTF8.GetBytes($packet)

Write-Host ""
Write-Host "Packet size: $($bytes.Length) bytes" -ForegroundColor Cyan

# ============================================================
#  STEP 7 — SEND
# ============================================================
Write-Host ""
Write-Host "Sending to IT-Tool..." -ForegroundColor Yellow

$port = New-Object System.IO.Ports.SerialPort $comPort, 115200, None, 8, One
$port.NewLine      = "`n"
$port.DtrEnable    = $false
$port.RtsEnable    = $false
$port.Encoding     = [System.Text.Encoding]::UTF8
$port.ReadTimeout  = 3000
$port.WriteTimeout = 5000
$port.Open()

Start-Sleep -Milliseconds 500

$chunkSize = 128
$offset    = 0
$total     = $bytes.Length

Write-Host "Sending in chunks of $chunkSize bytes..."

while ($offset -lt $total) {
    $remaining = $total - $offset
    $toSend    = [Math]::Min($chunkSize, $remaining)
    $port.BaseStream.Write($bytes, $offset, $toSend)
    $port.BaseStream.Flush()
    $offset += $toSend
    $pct = [Math]::Round(($offset / $total) * 100)
    Write-Host "  Sent $offset / $total bytes ($pct%)"
    Start-Sleep -Milliseconds 80
}

Start-Sleep -Milliseconds 1500

$port.Close()
Write-Host ""
Write-Host "Done! Folder '$folderName' created in $groupPath" -ForegroundColor Green
Write-Host ""
Read-Host "Press ENTER to close"