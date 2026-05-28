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
Write-Host "  1. Push the IT-Tool Reset button" -ForegroundColor White
Write-Host ""
Read-Host "2. Come back here and press 'ENTER'"

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
Write-Host "ReadyUSB > Script_Saver > Script_Saver." -ForegroundColor Green
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
Write-Host "  1. Composite Script (Windows-Linux)"
Write-Host "  2. Lineal Script (Windows-Linux)"
Write-Host "  3. Base64 (Windows-Linux)"
Write-Host ""

$scriptType = ""
while ([string]::IsNullOrWhiteSpace($scriptType)) {
    $st = (Read-Host "Script type").Trim()
    switch ($st) {
        "1" { $scriptType = "Windows" }
        "2" { $scriptType = "WindowsLineal" }
        "3" {
            Write-Host ""
            Write-Host "Base64 for:" -ForegroundColor Cyan
            Write-Host "  1. Windows"
            Write-Host "  2. Linux"
            Write-Host ""
            $b64os = ""
            while ([string]::IsNullOrWhiteSpace($b64os)) {
                $b = (Read-Host "Base64 for").Trim()
                switch ($b) {
                    "1" { $b64os = "Windows"; $scriptType = "WindowsBase64" }
                    "2" { $b64os = "Linux";   $scriptType = "LinuxBase64" }
                    default { Write-Host "  Invalid option." -ForegroundColor Yellow }
                }
            }
        }
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
Write-Host "    1. A__Admin_And_Security"
Write-Host "    2. B__Networks"
Write-Host "    3. C__Folder_and_Files"
Write-Host "    4. D__Storage"
Write-Host "    5. E__Monitoring"
Write-Host "    6. F__External_links_tools"
Write-Host "    7. G__Nmap"
Write-Host "    8. H__App_Downloader"
Write-Host ""
Write-Host "  Linux folders:"
Write-Host "    11. A__Admin_And_Security"
Write-Host "    12. B__Networks"
Write-Host "    13. C__Folder_and_Files"
Write-Host "    14. D__Storage"
Write-Host "    15. E__Monitoring"
Write-Host "    16. F__External_links_tools"
Write-Host "    17. G__Nmap"
Write-Host "    18. H__Kali_Linux"
Write-Host ""
Write-Host "    0. Favorites"
Write-Host ""

$targetFolder = ""
while ([string]::IsNullOrWhiteSpace($targetFolder)) {
    $fc = (Read-Host "Folder number").Trim()
    switch ($fc) {
        "1"  { $targetFolder = "B.OS_System/A.Windows/A__Admin_And_Security" }
        "2"  { $targetFolder = "B.OS_System/A.Windows/B__Networks" }
        "3"  { $targetFolder = "B.OS_System/A.Windows/C__Folder_and_Files" }
        "4"  { $targetFolder = "B.OS_System/A.Windows/D__Storage" }
        "5"  { $targetFolder = "B.OS_System/A.Windows/E__Monitoring" }
        "6"  { $targetFolder = "B.OS_System/A.Windows/F__External_links_tools" }
        "7"  { $targetFolder = "B.OS_System/A.Windows/G__Nmap" }
        "8"  { $targetFolder = "B.OS_System/A.Windows/H__App_Downloader" }
        "11" { $targetFolder = "B.OS_System/B.Linux/A__Admin_And_Security" }
        "12" { $targetFolder = "B.OS_System/B.Linux/B__Networks" }
        "13" { $targetFolder = "B.OS_System/B.Linux/C__Folder_and_Files" }
        "14" { $targetFolder = "B.OS_System/B.Linux/D__Storage" }
        "15" { $targetFolder = "B.OS_System/B.Linux/E__Monitoring" }
        "16" { $targetFolder = "B.OS_System/B.Linux/F__External_links_tools" }
        "17" { $targetFolder = "B.OS_System/B.Linux/G__Nmap" }
        "18" { $targetFolder = "B.OS_System/B.Linux/H__Kali_Linux" }
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
Write-Host "When finished type exactly:  ITTOOL  and double press ENTER" -ForegroundColor Yellow
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
} elseif ($scriptType -eq "WindowsLineal") {
    $duck = 'DELAY 1000' + $nl +
            'STRING ' + $userText + $nl +
            'ENTER'
} elseif ($scriptType -eq "WindowsBase64") {
    $bytes64 = [System.Text.Encoding]::UTF8.GetBytes($userText)
    $b64     = [Convert]::ToBase64String($bytes64)
    $duck = 'DELAY 1000' + $nl +
            'STRING powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(' + "'" + $b64 + "'" + ')) | Invoke-Expression"' + $nl +
            'ENTER'
} elseif ($scriptType -eq "LinuxBase64") {
    $bytes64 = [System.Text.Encoding]::UTF8.GetBytes($userText)
    $b64     = [Convert]::ToBase64String($bytes64)
    $duck = 'DELAY 800' + $nl +
            "STRING echo $b64 | base64 -d > `$HOME/ittool_run.sh && sh `$HOME/ittool_run.sh" + $nl +
            'ENTER'
}

# ============================================================
#  STEP 8 — ASSEMBLE THE PACKET
# ============================================================
$packet = "FOLDER:" + $targetFolder + "`nNAME:" + $fileName + "`nDATA:`n" + $duck + "`nEND_SCRIPT_SAVER`n"
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