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
#  STEP 4 — DESTINATION FOLDER
# ============================================================
Write-Host ""
Write-Host "Choose destination folder:" -ForegroundColor Cyan
Write-Host "  1. A. Admin_And_Security"
Write-Host "  2. B. Networks"
Write-Host "  3. C. Folder_and_File_options"
Write-Host "  4. D. Storage"
Write-Host "  5. E. Monitoring"
Write-Host "  6. F. App_Downloader"
Write-Host "  7. G. External_links_tools"
Write-Host "  8. H. Nmap"
Write-Host "  9. I. Linux and Kali"
Write-Host "  0. Custom"
Write-Host ""

$targetFolder = ""
while ([string]::IsNullOrWhiteSpace($targetFolder)) {
    $fc = (Read-Host "Folder number").Trim()
    switch ($fc) {
        "1"  { $targetFolder = "A. Admin_And_Security" }
        "2"  { $targetFolder = "B. Networks" }
        "3"  { $targetFolder = "C. Folder_and_File_options" }
        "4"  { $targetFolder = "D. Storage" }
        "5"  { $targetFolder = "E. Monitoring" }
        "6"  { $targetFolder = "F. App_Downloader" }
        "7"  { $targetFolder = "G. External_links_tools" }
        "8"  { $targetFolder = "H. Nmap" }
        "9"  { $targetFolder = "I. Linux and Kali" }
        "0"  { $targetFolder = "Custom" }
        default { Write-Host "  Invalid option." -ForegroundColor Yellow }
    }
}

# ============================================================
#  STEP 5 — CONSOLE TYPE
# ============================================================
Write-Host ""
Write-Host "Choose console type:" -ForegroundColor Cyan
Write-Host "  1. PowerShell Admin  (Run As Administrator)"
Write-Host "  2. CMD Admin         (Run As Administrator)"
Write-Host "  3. PowerShell        (normal, no UAC)"
Write-Host "  4. CMD               (normal, no UAC)"
Write-Host "  5. Linux             (CTRL+ALT+T terminal)"
Write-Host "  6. Script Only       (no console launch)"
Write-Host ""

$systemType = ""
while ([string]::IsNullOrWhiteSpace($systemType)) {
    $sc = (Read-Host "Console number").Trim()
    switch ($sc) {
        "1" { $systemType = "PowerShellAdmin" }
        "2" { $systemType = "CMDAdmin" }
        "3" { $systemType = "PowerShell" }
        "4" { $systemType = "CMD" }
        "5" { $systemType = "Linux" }
        "6" { $systemType = "ScriptOnly" }
        default { Write-Host "  Invalid option. Use 1 to 6." -ForegroundColor Yellow }
    }
}

# ============================================================
#  STEP 6 — PASTE YOUR SCRIPT
# ============================================================
Write-Host ""
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
$nl = "`n"

if ($systemType -eq "PowerShellAdmin") {
    # Step 1: Open normal PowerShell via Run (short — safe for Run 260-char limit)
    # Step 2: Inside console, STRINGLN sends Start-Process -EncodedCommand
    # -EncodedCommand (Base64 UTF-16LE) sends full script in one line — no >> mode.
    $utf16  = [System.Text.Encoding]::Unicode.GetBytes($userText)
    $b64    = [Convert]::ToBase64String($utf16)
    $duck   = 'DELAY 1000' + $nl +
              'GUI r' + $nl +
              'DELAY 1000' + $nl +
              'STRING powershell' + $nl +
              'ENTER' + $nl +
              'DELAY 2000' + $nl +
              'STRINGLN' + $nl +
              'Start-Process powershell -Verb RunAs -ArgumentList "-EncodedCommand ' + $b64 + '"' + $nl +
              'END_STRINGLN' + $nl +
              'DELAY 3000' + $nl +
              'LEFT' + $nl +
              'ENTER'
}
elseif ($systemType -eq "CMDAdmin") {
    # Opens CMD as Administrator via Run dialog + UAC confirm (LEFT+ENTER)
    $header = 'DELAY 1000' + $nl +
              'GUI r' + $nl +
              'DELAY 800' + $nl +
              'STRING powershell -Command "Start-Process cmd -Verb RunAs -WindowStyle Maximized"' + $nl +
              'ENTER' + $nl +
              'DELAY 4000' + $nl +
              'LEFT' + $nl +
              'ENTER' + $nl +
              'DELAY 1000' + $nl +
              'STRINGLN' + $nl
    $duck = $header + $userText + $nl + 'END_STRINGLN' + $nl + 'ENTER'
}
elseif ($systemType -eq "PowerShell") {
    # Opens normal PowerShell via Run, then STRINGLN sends -EncodedCommand inside console
    # -EncodedCommand (Base64 UTF-16LE) sends full script in one line — no >> mode.
    $utf16  = [System.Text.Encoding]::Unicode.GetBytes($userText)
    $b64    = [Convert]::ToBase64String($utf16)
    $duck   = 'DELAY 1000' + $nl +
              'GUI r' + $nl +
              'DELAY 1000' + $nl +
              'STRING powershell' + $nl +
              'ENTER' + $nl +
              'DELAY 2000' + $nl +
              'STRINGLN' + $nl +
              'powershell -EncodedCommand ' + $b64 + $nl +
              'END_STRINGLN'
}
elseif ($systemType -eq "CMD") {
    # Opens CMD normal (no UAC)
    $header = 'DELAY 1000' + $nl +
              'GUI r' + $nl +
              'DELAY 1000' + $nl +
              'STRING cmd' + $nl +
              'ENTER' + $nl +
              'DELAY 2000' + $nl +
              'STRINGLN' + $nl
    $duck = $header + $userText + $nl + 'END_STRINGLN' + $nl + 'ENTER'
}
elseif ($systemType -eq "Linux") {
    # Opens terminal with CTRL+ALT+T
    $header = 'DELAY 1500' + $nl +
              'CTRL ALT T' + $nl +
              'DELAY 2000' + $nl +
              'STRINGLN' + $nl
    $duck = $header + $userText + $nl + 'END_STRINGLN' + $nl + 'ENTER'
}
else {
    # Script Only — no console launch, just send keystrokes
    $header = 'DELAY 1000' + $nl +
              'STRINGLN' + $nl
    $duck = $header + $userText + $nl + 'END_STRINGLN' + $nl + 'ENTER'
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
