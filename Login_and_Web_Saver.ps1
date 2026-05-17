[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "======================================" -ForegroundColor Magenta
Write-Host "   IT-Tool - Credential Saver" -ForegroundColor Magenta
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
#  Shows COMx + full device description (like IT_Mirror.py)
#  so you can identify the IT-Tool among Bluetooth virtual ports.
# ============================================================
$comPort = ""
$portEntries = @()   # array of [pscustomobject] with .Com and .Desc

$portEntries = @(Get-PnpDevice -Class Ports -ErrorAction SilentlyContinue |
    Where-Object { $_.Status -eq "OK" -and $_.FriendlyName -match "COM\d+" } |
    ForEach-Object {
        $com  = [regex]::Match($_.FriendlyName, "COM\d+").Value
        $desc = $_.FriendlyName -replace "\s*\(COM\d+\)\s*$", ""
        [pscustomobject]@{ Com = $com; Desc = $desc }
    } |
    Sort-Object { [int]($_.Com -replace "COM","") })

$availablePorts = $portEntries | ForEach-Object { $_.Com }

if ($portEntries.Count -eq 0) {
    Write-Host "No COM ports detected. Check IT-Tool USB connection." -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit
}
Write-Host ""
Write-Host "Available COM ports:" -ForegroundColor Cyan
for ($i = 0; $i -lt $portEntries.Count; $i++) {
    $e = $portEntries[$i]
    Write-Host "  $($i + 1). $($e.Com)  --  $($e.Desc)"
}
Write-Host ""
while ([string]::IsNullOrWhiteSpace($comPort)) {
    $choice = (Read-Host "Select port number").Trim()
    $idx = 0
    if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 1 -and $idx -le $portEntries.Count) {
        $comPort = $portEntries[$idx - 1].Com
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

# ============================================================
#  STEP 3 — FILE NAME
# ============================================================
$fileName = ""
while ([string]::IsNullOrWhiteSpace($fileName)) {
    $fileName = (Read-Host "Enter file name (without extension)").Trim()
}

# ============================================================
#  STEP 4 — WHAT DO YOU WANT TO SAVE?
# ============================================================
Write-Host ""
Write-Host "What do you want to save?" -ForegroundColor Cyan
Write-Host "  1. Username and Password"
Write-Host "  2. Website"
Write-Host ""

$saveType = ""
while ([string]::IsNullOrWhiteSpace($saveType)) {
    $st = (Read-Host "Select option").Trim()
    switch ($st) {
        "1" { $saveType = "Credentials" }
        "2" { $saveType = "Website" }
        default { Write-Host "  Invalid option." -ForegroundColor Yellow }
    }
}

# ============================================================
#  STEP 5 — COLLECT DATA & BUILD DUCKY SCRIPT
# ============================================================
$nl = "`n"

if ($saveType -eq "Credentials") {
    Write-Host ""
    $username = ""
    while ([string]::IsNullOrWhiteSpace($username)) {
        $username = (Read-Host "Enter Username").Trim()
    }
    $password = ""
    while ([string]::IsNullOrWhiteSpace($password)) {
        $password = (Read-Host "Enter Password").Trim()
    }

    $duck = "DELAY 1000"       + $nl +
            "STRING $username" + $nl +
            "TAB"              + $nl +
            "DELAY 1000"       + $nl +
            "STRING $password"

    Write-Host ""
    Write-Host "Credentials captured." -ForegroundColor Green

} else {
    Write-Host ""
    $website = ""
    while ([string]::IsNullOrWhiteSpace($website)) {
        $website = (Read-Host "Enter the website to save").Trim()
    }

    $duck = "DELAY 1000"      + $nl +
            "STRING $website"

    Write-Host ""
    Write-Host "Website captured." -ForegroundColor Green
}

# ============================================================
#  STEP 6 — DESTINATION FOLDER
# ============================================================
Write-Host ""
Write-Host "Choose destination folder:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Windows folders:"
Write-Host "    1. B.Admin_And_Security"
Write-Host "    2. C.Networks"
Write-Host "    3. D.Folder_and_Files"
Write-Host "    4. E.Storage"
Write-Host "    5. F. Monitoring"
Write-Host "    6. G.External_links_tools"
Write-Host "    7. H.Nmap"
Write-Host "    8. I.App_Downloader"
Write-Host ""
Write-Host "  Linux folders:"
Write-Host "    11. A.Admin_And_Security"
Write-Host "    12. B.Networks"
Write-Host "    13. C.Folders_and_Files"
Write-Host "    14. D.Storage"
Write-Host "    15. E.Monitoring"
Write-Host "    16. F.External_links_tools"
Write-Host "    17. G.Nmap"
Write-Host "    18. H.Kali_Linux"
Write-Host ""
Write-Host "    0. Favorites"
Write-Host ""

$targetFolder = ""
while ([string]::IsNullOrWhiteSpace($targetFolder)) {
    $fc = (Read-Host "Folder number").Trim()
    switch ($fc) {
        "1"  { $targetFolder = "B.OS_System/A.Windows/B.Admin_And_Security" }
        "2"  { $targetFolder = "B.OS_System/A.Windows/C.Networks" }
        "3"  { $targetFolder = "B.OS_System/A.Windows/D.Folder_and_Files" }
        "4"  { $targetFolder = "B.OS_System/A.Windows/E.Storage" }
        "5"  { $targetFolder = "B.OS_System/A.Windows/F. Monitoring" }
        "6"  { $targetFolder = "B.OS_System/A.Windows/G.External_links_tools" }
        "7"  { $targetFolder = "B.OS_System/A.Windows/H.Nmap" }
        "8"  { $targetFolder = "B.OS_System/A.Windows/I.App_Downloader" }
        "11" { $targetFolder = "B.OS_System/B.Linux/A.Admin_And_Security" }
        "12" { $targetFolder = "B.OS_System/B.Linux/B.Networks" }
        "13" { $targetFolder = "B.OS_System/B.Linux/C.Folders_and_Files" }
        "14" { $targetFolder = "B.OS_System/B.Linux/D.Storage" }
        "15" { $targetFolder = "B.OS_System/B.Linux/E.Monitoring" }
        "16" { $targetFolder = "B.OS_System/B.Linux/F.External_links_tools" }
        "17" { $targetFolder = "B.OS_System/B.Linux/G.Nmap" }
        "18" { $targetFolder = "B.OS_System/B.Linux/H.Kali_Linux" }
        "0"  { $targetFolder = "Favorites" }
        default { Write-Host "  Invalid option." -ForegroundColor Yellow }
    }
}
Write-Host "Destination: $targetFolder" -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 7 — ASSEMBLE THE PACKET
# ============================================================
$packet = "FOLDER:$targetFolder`nNAME:$fileName`nDATA:`n$duck`nEND_SCRIPT_SAVER`n"
$bytes  = [System.Text.Encoding]::UTF8.GetBytes($packet)

Write-Host "Packet size: $($bytes.Length) bytes" -ForegroundColor Cyan

# ============================================================
#  STEP 8 — SEND
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
Write-Host "Done! '$fileName' saved to ReadyUSB > $targetFolder" -ForegroundColor Green
Write-Host ""
Read-Host "Press ENTER to close"