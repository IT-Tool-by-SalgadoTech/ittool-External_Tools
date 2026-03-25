[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "======================================" -ForegroundColor Magenta
Write-Host "   IT-Tool - ReadyUSB Script Saver" -ForegroundColor Magenta
Write-Host "======================================" -ForegroundColor Magenta
Write-Host ""

# ============================================================
#  STEP 0 — CONNECT IT-TOOL
#  The IT-Tool just launched this script via USB.
#  The USB port is not yet visible to Windows.
#  Reconnect the cable and set the IT-Tool to Script_Saver
#  mode BEFORE pressing ENTER so the COM port is detected.
# ============================================================
Write-Host "Before continuing:" -ForegroundColor Yellow
Write-Host "  1. Unplug the IT-Tool USB cable" -ForegroundColor White
Write-Host "  2. Plug it back in" -ForegroundColor White
Write-Host "  3. On the IT-Tool go to: ReadyUSB > Script_Saver" -ForegroundColor White
Write-Host "  4. Wait until screen shows 'Waiting...'" -ForegroundColor White
Write-Host "  5. Come back here and press ENTER" -ForegroundColor White
Write-Host ""
Read-Host "Press ENTER when IT-Tool shows 'Waiting...'"

# ============================================================
#  STEP 1 — DETECT COM PORT
# ============================================================
$comPort = ""
$availablePorts = [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object
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
#  Opens and closes the port to trigger the ESP32 reset.
#  The IT-Tool will reboot. While it boots, fill the form.
# ============================================================
Write-Host "IT-Tool reset, Please come back a second time to:" -ForegroundColor Yellow
$portReset = New-Object System.IO.Ports.SerialPort $comPort, 115200, None, 8, One
$portReset.DtrEnable = $false
$portReset.RtsEnable = $false
$portReset.Open()
Start-Sleep -Milliseconds 400
$portReset.Close()
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
#  STEP 4 — SYSTEM SELECTION (Windows or Linux)
# ============================================================
Write-Host ""
Write-Host "Choose System folders to save:" -ForegroundColor Cyan
Write-Host "  1. Windows"
Write-Host "  2. Linux"
Write-Host ""

$system = ""
while ([string]::IsNullOrWhiteSpace($system)) {
    $sc = (Read-Host "System number").Trim()
    switch ($sc) {
        "1" { $system = "Windows" }
        "2" { $system = "Linux" }
        default { Write-Host "  Invalid option." -ForegroundColor Yellow }
    }
}
Write-Host "System: $system" -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 5 — DESTINATION FOLDER (depends on system)
# ============================================================
Write-Host "Choose destination folder:" -ForegroundColor Cyan

$targetFolder = ""

if ($system -eq "Windows") {
    Write-Host "  1. A.Admin_And_Security"
    Write-Host "  2. B.Networks"
    Write-Host "  3. C.Folder_and_Files"
    Write-Host "  4. D.Storage"
    Write-Host "  5. E. Monitoring"
    Write-Host "  6. F.External_links_tools"
    Write-Host "  7. G.Nmap"
    Write-Host "  8. H.App_Downloader"
    Write-Host "  0. Favorites"
    Write-Host ""

    while ([string]::IsNullOrWhiteSpace($targetFolder)) {
        $fc = (Read-Host "Folder number").Trim()
        switch ($fc) {
            "1" { $targetFolder = "B.Windows\A.Admin_And_Security" }
            "2" { $targetFolder = "B.Windows\B.Networks" }
            "3" { $targetFolder = "B.Windows\C.Folder_and_Files" }
            "4" { $targetFolder = "B.Windows\D.Storage" }
            "5" { $targetFolder = "B.Windows\E. Monitoring" }
            "6" { $targetFolder = "B.Windows\F.External_links_tools" }
            "7" { $targetFolder = "B.Windows\G.Nmap" }
            "8" { $targetFolder = "B.Windows\H.App_Downloader" }
            "0" { $targetFolder = "Favorites" }
            default { Write-Host "  Invalid option." -ForegroundColor Yellow }
        }
    }
}
elseif ($system -eq "Linux") {
    Write-Host "  1. A.Admin_And_Security"
    Write-Host "  2. B.Networks"
    Write-Host "  3. C.Folders_and_Files"
    Write-Host "  4. D.Storage"
    Write-Host "  5. E.Monitoring"
    Write-Host "  6. F.External_links_tools"
    Write-Host "  7. G.Nmap"
    Write-Host "  8. H.Kali_Linux"
    Write-Host "  0. Favorites"
    Write-Host ""

    while ([string]::IsNullOrWhiteSpace($targetFolder)) {
        $fc = (Read-Host "Folder number").Trim()
        switch ($fc) {
            "1" { $targetFolder = "C.Linux\A.Admin_And_Security" }
            "2" { $targetFolder = "C.Linux\B.Networks" }
            "3" { $targetFolder = "C.Linux\C.Folders_and_Files" }
            "4" { $targetFolder = "C.Linux\D.Storage" }
            "5" { $targetFolder = "C.Linux\E.Monitoring" }
            "6" { $targetFolder = "C.Linux\F.External_links_tools" }
            "7" { $targetFolder = "C.Linux\G.Nmap" }
            "8" { $targetFolder = "C.Linux\H.Kali_Linux" }
            "0" { $targetFolder = "Favorites" }
            default { Write-Host "  Invalid option." -ForegroundColor Yellow }
        }
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
# ============================================================
$nl   = "`n"
$duck = 'DELAY 1000' + $nl +
        'STRINGLN' + $nl +
        $userText  + $nl +
        'END_STRINGLN'

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
