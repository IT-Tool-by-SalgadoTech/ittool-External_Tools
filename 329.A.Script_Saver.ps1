[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "======================================" -ForegroundColor Magenta
Write-Host "   IT-Tool - ReadyUSB Script Saver" -ForegroundColor Magenta
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
#  Only shows USB serial ports with Status OK (filters out
#  Bluetooth virtual ports which cause GetPortNames() issues)
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

# ============================================================
#  STEP 3 — FILE NAME
# ============================================================
$fileName = ""
while ([string]::IsNullOrWhiteSpace($fileName)) {
    $fileName = (Read-Host "Enter file name (without extension)").Trim()
}

# ============================================================
#  STEP 4 — SCRIPT TYPE (controls transmission method)
# ============================================================
Write-Host ""
Write-Host "What type of script are you saving?" -ForegroundColor Cyan
Write-Host "  1. Windows"
Write-Host "  2. Linux"
Write-Host ""

$scriptType = ""
while ([string]::IsNullOrWhiteSpace($scriptType)) {
    $st = (Read-Host "Script type").Trim()
    switch ($st) {
        "1" { $scriptType = "Windows" }
        "2" { $scriptType = "Linux" }
        default { Write-Host "  Invalid option." -ForegroundColor Yellow }
    }
}
Write-Host "Script type: $scriptType" -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 5 — DESTINATION FOLDER (independent of script type)
# ============================================================
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
Write-Host "   00. New Folder" -ForegroundColor Yellow
Write-Host ""

$targetFolder = ""
while ([string]::IsNullOrWhiteSpace($targetFolder)) {
    $fc = (Read-Host "Folder number").Trim()

    # ── NEW FOLDER (handled before switch) ──────────────────────
    if ($fc -eq "00") {
        Write-Host ""
        Write-Host "New Folder — choose group:" -ForegroundColor Cyan
        Write-Host "  1. Windows"
        Write-Host "  2. Linux"
        Write-Host "  3. Favorites"
        Write-Host ""
        $mkGroup = ""
        while ([string]::IsNullOrWhiteSpace($mkGroup)) {
            $mg = (Read-Host "Group").Trim()
            switch ($mg) {
                "1" { $mkGroup = "B.OS_System/A.Windows" }
                "2" { $mkGroup = "B.OS_System/B.Linux" }
                "3" { $mkGroup = "Favorites" }
                default { Write-Host "  Invalid option." -ForegroundColor Yellow }
            }
        }
        $mkName = ""
        while ([string]::IsNullOrWhiteSpace($mkName)) {
            $mkName = (Read-Host "New folder name").Trim()
            $mkName = $mkName -replace ' ','_'
        }
        $mkPath   = if ($mkGroup -eq "Favorites") { "Favorites/$mkName" } else { "$mkGroup/$mkName" }
        $mkPacket = "MKDIR:$mkPath`nEND_SCRIPT_SAVER`n"
        $mkBytes  = [System.Text.Encoding]::UTF8.GetBytes($mkPacket)

        Write-Host ""
        Write-Host "Creating folder: $mkPath" -ForegroundColor Yellow

        $portMk = New-Object System.IO.Ports.SerialPort $comPort, 115200, None, 8, One
        $portMk.DtrEnable    = $false
        $portMk.RtsEnable    = $false
        $portMk.Encoding     = [System.Text.Encoding]::UTF8
        $portMk.WriteTimeout = 5000
        $portMk.Open()
        Start-Sleep -Milliseconds 500
        $portMk.BaseStream.Write($mkBytes, 0, $mkBytes.Length)
        $portMk.BaseStream.Flush()
        Start-Sleep -Milliseconds 1500
        $portMk.Close()

        Write-Host "Done! Folder '$mkName' created in $mkGroup" -ForegroundColor Green
        Write-Host ""
        Read-Host "Press ENTER to close"
        exit
    }

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
#  STEP 6 — PASTE YOUR SCRIPT
# ============================================================
Write-Host "Paste your script below." -ForegroundColor Cyan
Write-Host "When finished type exactly:  ITTOOL  and press Enter" -ForegroundColor Yellow
Write-Host ""

$lines = New-Object System.Collections.Generic.List[string]
while ($true) {
    $line = Read-Host
    if ($line -eq "ITTOOL") { break }
    $lines.Add($line)
}
while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq "") {
    $lines.RemoveAt($lines.Count - 1)
}
$userText = $lines -join "`n"

if ([string]::IsNullOrWhiteSpace($userText)) {
    Write-Host "ERROR: No content entered." -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit
}

# ============================================================
#  STEP 7 — BUILD THE DUCKY SCRIPT
#  Windows -> STRINGLN
#  Linux   -> base64
# ============================================================
$nl = "`n"

if ($scriptType -eq "Windows") {
    $duck = 'DELAY 1000' + $nl +
            'STRINGLN' + $nl +
            $userText  + $nl +
            'END_STRINGLN'
} else {
    $bytes64 = [System.Text.Encoding]::UTF8.GetBytes($userText)
    $b64     = [Convert]::ToBase64String($bytes64)
    $duck = 'DELAY 800' + $nl +
            "STRING echo $b64 | base64 -d > `$HOME/ittool_run.sh && sh `$HOME/ittool_run.sh" + $nl +
            'ENTER'
}

# ============================================================
#  STEP 8 — ASSEMBLE THE PACKET
# ============================================================
$packet = "FOLDER:$targetFolder`nNAME:$fileName`nDATA:`n$duck`nEND_SCRIPT_SAVER`n"
$bytes  = [System.Text.Encoding]::UTF8.GetBytes($packet)

Write-Host ""
Write-Host "Packet size: $($bytes.Length) bytes" -ForegroundColor Cyan

# ============================================================
#  STEP 9 — SEND
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
Write-Host "Done! Script '$fileName' sent to ReadyUSB > $targetFolder" -ForegroundColor Green
Write-Host ""
Read-Host "Press ENTER to close"