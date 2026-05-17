[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "======================================" -ForegroundColor Magenta
Write-Host "   IT-Tool - Login and Web Saver" -ForegroundColor Magenta
Write-Host "======================================" -ForegroundColor Magenta
Write-Host ""

# ============================================================
#  STEP 0 -- CONNECT IT-TOOL
# ============================================================
Write-Host "Before continuing:" -ForegroundColor Yellow
Write-Host "  1. Unplug the IT-Tool USB cable" -ForegroundColor White
Write-Host "  2. Plug it back in" -ForegroundColor White
Write-Host ""
Read-Host "Come back here and press 'ENTER'"

# ============================================================
#  STEP 1 -- DETECT COM PORT
#  Shows COMx + full device description (like IT_Mirror.py)
#  so you can identify the IT-Tool among Bluetooth virtual ports.
# ============================================================
$comPort = ""
$portEntries = @()

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
#  STEP 2 -- CONTROLLED RESET
# ============================================================
Write-Host "IT-Tool reset, please navigate to:" -ForegroundColor Yellow
try {
    $portReset = New-Object System.IO.Ports.SerialPort $comPort, 115200, None, 8, One
    $portReset.DtrEnable = $false
    $portReset.RtsEnable = $false
    $portReset.Open()
    Start-Sleep -Milliseconds 400
    $portReset.Close()
    # Wait for Windows CDC driver to fully release the port after reset
    Start-Sleep -Milliseconds 1500
} catch {
    Write-Host "Reset warning: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host "ReadyUSB > Script_Saver." -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 3 -- FOLDER NAME (will be created inside destination)
# ============================================================
Write-Host "Enter the name for the new folder that will contain" -ForegroundColor Cyan
Write-Host "the 3 scripts (A.WebLink, B.Username, C.Password):" -ForegroundColor Cyan
Write-Host ""
$folderName = ""
while ([string]::IsNullOrWhiteSpace($folderName)) {
    $folderName = (Read-Host "Folder name").Trim()
}
Write-Host "Folder: $folderName" -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 4 -- WEB LINK
# ============================================================
$webLink = ""
while ([string]::IsNullOrWhiteSpace($webLink)) {
    $webLink = (Read-Host "Enter the web link (URL)").Trim()
}
Write-Host "Web link captured." -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 5 -- USERNAME / EMAIL
# ============================================================
$username = ""
while ([string]::IsNullOrWhiteSpace($username)) {
    $username = (Read-Host "Enter username or email").Trim()
}
Write-Host "Username captured." -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 6 -- PASSWORD
# ============================================================
$password = ""
while ([string]::IsNullOrWhiteSpace($password)) {
    $securePass = Read-Host "Enter password" -AsSecureString
    $password   = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                      [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass))
}
Write-Host "Password captured." -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 7 -- DESTINATION FOLDER
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
Write-Host "Destination: $targetFolder/$folderName" -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 8 -- BUILD DUCKY SCRIPTS
#  A.WebLink  -> DELAY 1000 / STRING <url>  / ENTER
#  B.Username -> DELAY 1000 / STRING <user> / ENTER
#  C.Password -> DELAY 1000 / STRING <pass> / ENTER
# ============================================================
$nl = "`n"

$duckWebLink  = "DELAY 1000"       + $nl + "STRING $webLink"  + $nl + "ENTER"
$duckUsername = "DELAY 1000"       + $nl + "STRING $username" + $nl + "ENTER"
$duckPassword = "DELAY 1000"       + $nl + "STRING $password" + $nl + "ENTER"

$subFolder = "$targetFolder/$folderName"

$packetWebLink  = "FOLDER:$subFolder`nNAME:A.WebLink`nDATA:`n$duckWebLink`nEND_SCRIPT_SAVER`n"
$packetUsername = "FOLDER:$subFolder`nNAME:B.Username`nDATA:`n$duckUsername`nEND_SCRIPT_SAVER`n"
$packetPassword = "FOLDER:$subFolder`nNAME:C.Password`nDATA:`n$duckPassword`nEND_SCRIPT_SAVER`n"

$bytesWebLink  = [System.Text.Encoding]::UTF8.GetBytes($packetWebLink)
$bytesUsername = [System.Text.Encoding]::UTF8.GetBytes($packetUsername)
$bytesPassword = [System.Text.Encoding]::UTF8.GetBytes($packetPassword)

Write-Host "Packet sizes:" -ForegroundColor Cyan
Write-Host "  A.WebLink  : $($bytesWebLink.Length) bytes"
Write-Host "  B.Username : $($bytesUsername.Length) bytes"
Write-Host "  C.Password : $($bytesPassword.Length) bytes"
Write-Host ""

# ============================================================
#  STEP 9 -- SEND (3 packets with pause between each)
# ============================================================
Write-Host "Sending to IT-Tool..." -ForegroundColor Yellow
Write-Host ""

$port = New-Object System.IO.Ports.SerialPort $comPort, 115200, None, 8, One
$port.NewLine      = "`n"
$port.DtrEnable    = $false
$port.RtsEnable    = $false
$port.Encoding     = [System.Text.Encoding]::UTF8
$port.ReadTimeout  = 3000
$port.WriteTimeout = 5000

# Retry open: Windows CDC driver may take a moment to release after reset
$openOk = $false
for ($attempt = 1; $attempt -le 5; $attempt++) {
    try {
        $port.Open()
        $openOk = $true
        break
    } catch {
        Write-Host "  Port busy, retrying ($attempt/5)..." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 1000
    }
}
if (-not $openOk) {
    Write-Host "ERROR: Could not open $comPort after 5 attempts." -ForegroundColor Red
    Write-Host "Make sure no other program is using the port." -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit
}

Start-Sleep -Milliseconds 500

$chunkSize = 128

function Send-Packet {
    param([byte[]]$bytes, [string]$label)
    Write-Host "  Sending $label..." -ForegroundColor Cyan
    $offset = 0
    $total  = $bytes.Length
    while ($offset -lt $total) {
        $toSend = [Math]::Min($chunkSize, $total - $offset)
        $port.BaseStream.Write($bytes, $offset, $toSend)
        $port.BaseStream.Flush()
        $offset += $toSend
        $pct = [Math]::Round(($offset / $total) * 100)
        Write-Host "    $offset / $total bytes ($pct%)"
        Start-Sleep -Milliseconds 80
    }
    Write-Host "  $label sent." -ForegroundColor Green
    Start-Sleep -Milliseconds 1800
    Write-Host ""
}

Send-Packet -bytes $bytesWebLink  -label "A.WebLink"
Send-Packet -bytes $bytesUsername -label "B.Username"
Send-Packet -bytes $bytesPassword -label "C.Password"

$port.Close()

Write-Host "Done!" -ForegroundColor Green
Write-Host "Folder '$folderName' saved inside ReadyUSB > $targetFolder" -ForegroundColor Green
Write-Host "  A.WebLink  -> $webLink" -ForegroundColor White
Write-Host "  B.Username -> $username" -ForegroundColor White
Write-Host "  C.Password -> [saved]" -ForegroundColor White
Write-Host ""
Read-Host "Press ENTER to close"