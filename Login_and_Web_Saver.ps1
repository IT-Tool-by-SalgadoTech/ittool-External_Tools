Set-ExecutionPolicy Bypass -Scope Process -Force
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  ==================================================================" -ForegroundColor White
Write-Host "  IT-Tool by SalgadoTech" -ForegroundColor Cyan
Write-Host "  Script: Login_and_Web_Saver.ps1" -ForegroundColor DarkCyan
Write-Host "  Version: 2.0" -ForegroundColor DarkCyan
Write-Host "  Date: 2026-06-15" -ForegroundColor DarkCyan
Write-Host "  Category: Windows > ReadyUSB" -ForegroundColor DarkCyan
Write-Host "  Description: Saves Web Link, Username and Password scripts to IT-Tool SD card" -ForegroundColor DarkCyan
Write-Host "  (c) 2025 SalgadoTech - All Rights Reserved" -ForegroundColor DarkCyan
Write-Host "  Unauthorized distribution prohibited" -ForegroundColor DarkCyan
Write-Host "  ==================================================================" -ForegroundColor White
Write-Host ""

# ============================================================
#  STEP 0 -- CONNECT IT-TOOL
# ============================================================
Write-Host "Before continuing:" -ForegroundColor Yellow
Write-Host "  1. Push the IT-Tool Reset button" -ForegroundColor White
Write-Host ""
Read-Host "2. Come back here and press 'ENTER'"

# ============================================================
#  STEP 1 -- DETECT COM PORT
# ============================================================
$comPort     = ""
$portEntries = @()

$portEntries = @(Get-PnpDevice -Class Ports -ErrorAction SilentlyContinue |
    Where-Object { $_.Status -eq "OK" -and $_.FriendlyName -match "COM\d+" } |
    ForEach-Object {
        $com  = [regex]::Match($_.FriendlyName, "COM\d+").Value
        $desc = $_.FriendlyName -replace "\s*\(COM\d+\)\s*$", ""
        [pscustomobject]@{ Com = $com; Desc = $desc }
    } |
    Sort-Object { [int]($_.Com -replace "COM","") })

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
Write-Host "IT-Tool reset, Please come to:" -ForegroundColor Yellow
try {
    $portReset = New-Object System.IO.Ports.SerialPort $comPort, 460800, None, 8, One
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
#  STEP 3 -- FOLDER NAME
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
        "1"  { $targetFolder = "A.OS_System/A.Windows/A__Admin_And_Security" }
        "2"  { $targetFolder = "A.OS_System/A.Windows/B__Networks" }
        "3"  { $targetFolder = "A.OS_System/A.Windows/C__Folder_and_Files" }
        "4"  { $targetFolder = "A.OS_System/A.Windows/D__Storage" }
        "5"  { $targetFolder = "A.OS_System/A.Windows/E__Monitoring" }
        "6"  { $targetFolder = "A.OS_System/A.Windows/F__External_links_tools" }
        "7"  { $targetFolder = "A.OS_System/A.Windows/G__Nmap" }
        "8"  { $targetFolder = "A.OS_System/A.Windows/H__App_Downloader" }
        "11" { $targetFolder = "A.OS_System/B.Linux/A__Admin_And_Security" }
        "12" { $targetFolder = "A.OS_System/B.Linux/B__Networks" }
        "13" { $targetFolder = "A.OS_System/B.Linux/C__Folder_and_Files" }
        "14" { $targetFolder = "A.OS_System/B.Linux/D__Storage" }
        "15" { $targetFolder = "A.OS_System/B.Linux/E__Monitoring" }
        "16" { $targetFolder = "A.OS_System/B.Linux/F__External_links_tools" }
        "17" { $targetFolder = "A.OS_System/B.Linux/G__Nmap" }
        "18" { $targetFolder = "A.OS_System/B.Linux/H__Kali_Linux" }
        "0"  { $targetFolder = "Favorites" }
        default { Write-Host "  Invalid option." -ForegroundColor Yellow }
    }
}
Write-Host "Destination: $targetFolder/$folderName" -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 8 -- BUILD IT_SCRIPT PAYLOADS
#  A.WebLink  -> WTIME 1000 / SCRIPT <url>  / ENTER
#  B.Username -> WTIME 1000 / SCRIPT <user> / TAB
#  C.Password -> WTIME 1000 / SCRIPT <pass> / ENTER
# ============================================================
$nl        = "`n"
$subFolder = "$targetFolder/$folderName"

$itscriptWebLink  = "WTIME 1000" + $nl + "SCRIPT $webLink"  + $nl + "ENTER"
$itscriptUsername = "WTIME 1000" + $nl + "SCRIPT $username" + $nl + "TAB"
$itscriptPassword = "WTIME 1000" + $nl + "SCRIPT $password" + $nl + "ENTER"

$bytesWebLink  = [System.Text.Encoding]::UTF8.GetBytes($itscriptWebLink)
$bytesUsername = [System.Text.Encoding]::UTF8.GetBytes($itscriptUsername)
$bytesPassword = [System.Text.Encoding]::UTF8.GetBytes($itscriptPassword)

Write-Host "Payload sizes:" -ForegroundColor Cyan
Write-Host "  A.WebLink  : $($bytesWebLink.Length) bytes"
Write-Host "  B.Username : $($bytesUsername.Length) bytes"
Write-Host "  C.Password : $($bytesPassword.Length) bytes"
Write-Host "Protocol     : Chunked v55 (4096 B/chunk, ACK per chunk)" -ForegroundColor Cyan
Write-Host "Baud rate    : 460800" -ForegroundColor Cyan
Write-Host ""

# ============================================================
#  STEP 9 -- OPEN PORT
# ============================================================
Write-Host "Connecting to IT-Tool on $comPort @ 460800..." -ForegroundColor Yellow

$port = New-Object System.IO.Ports.SerialPort $comPort, 460800, None, 8, One
$port.NewLine      = "`n"
$port.DtrEnable    = $false
$port.RtsEnable    = $false
$port.Encoding     = [System.Text.Encoding]::UTF8
$port.ReadTimeout  = 10000
$port.WriteTimeout = 10000
$port.Open()

Start-Sleep -Milliseconds 300

$CHUNK_SIZE  = 4096
$ACK_TIMEOUT = 10000
$MAX_RETRIES = 3

# ============================================================
#  STEP 10 -- SEND A.WebLink
# ============================================================
Write-Host "Sending A.WebLink..." -ForegroundColor Yellow

$txBytes  = $bytesWebLink
$txName   = "A.WebLink"
$txTotal  = $txBytes.Length

$txHeader      = "SS_BEGIN:${subFolder}|${txName}|${txTotal}`n"
$txHeaderBytes = [System.Text.Encoding]::UTF8.GetBytes($txHeader)
$port.BaseStream.Write($txHeaderBytes, 0, $txHeaderBytes.Length)
$port.BaseStream.Flush()

Write-Host "  Waiting for SS_READY..." -ForegroundColor Yellow
$txReady    = ""
$txDeadline = (Get-Date).AddMilliseconds($port.ReadTimeout)
try {
    while ((Get-Date) -lt $txDeadline) {
        $txLine = $port.ReadLine().Trim()
        if ($txLine -eq "SS_READY")          { $txReady = $txLine; break }
        if ($txLine.StartsWith("SS:ERR:"))   { $txReady = $txLine; break }
        Write-Host "    [serial noise] $txLine" -ForegroundColor DarkGray
    }
} catch { }

if ($txReady -ne "SS_READY") {
    $port.Close()
    Write-Host ""
    if ($txReady -eq "") {
        Write-Host "ERROR: IT-Tool did not respond to SS_BEGIN for $txName (timeout)." -ForegroundColor Red
        Write-Host "  Make sure IT-Tool is on ReadyUSB > Script_Saver > Script_Saver screen." -ForegroundColor Yellow
    } else {
        Write-Host "ERROR: $txName -- Unexpected response: '$txReady'" -ForegroundColor Red
    }
    Read-Host "Press ENTER to close"
    exit
}
Write-Host "  IT-Tool ready. Transferring $txName..." -ForegroundColor Green

$txOffset   = 0
$txChunkNum = 0
while ($txOffset -lt $txTotal) {
    $txRemaining   = $txTotal - $txOffset
    $txToSend      = [Math]::Min($CHUNK_SIZE, $txRemaining)
    $txChunkNum++
    $txIsLast      = ($txOffset + $txToSend -ge $txTotal)

    $txSent = $false
    for ($txRetry = 1; $txRetry -le $MAX_RETRIES; $txRetry++) {
        try {
            $port.BaseStream.Write($txBytes, $txOffset, $txToSend)
            $port.BaseStream.Flush()

            if ($txIsLast) {
                $txOffset += $txToSend
                $txPct = 100
                Write-Host "`r  [##################################################] $txPct%  $([Math]::Round($txOffset/1024,1))/$([Math]::Round($txTotal/1024,1)) KB  " -NoNewline -ForegroundColor Green
                $txSent = $true
                break
            }

            $port.ReadTimeout = $ACK_TIMEOUT
            $txAck            = ""
            $txAckDeadline    = (Get-Date).AddMilliseconds($ACK_TIMEOUT)
            while ((Get-Date) -lt $txAckDeadline) {
                $txAckLine = $port.ReadLine().Trim()
                if ($txAckLine.StartsWith("ACK:") -or $txAckLine.StartsWith("SS:")) { $txAck = $txAckLine; break }
            }

            if ($txAck -eq "ACK:$txChunkNum") {
                $txOffset += $txToSend
                $txPct = [Math]::Round(($txOffset / $txTotal) * 100)
                Write-Host "`r  [$("$("█" * [int]($txPct/2))$("-" * (50-[int]($txPct/2)))")] $txPct%  $([Math]::Round($txOffset/1024,1))/$([Math]::Round($txTotal/1024,1)) KB  " -NoNewline -ForegroundColor Green
                $txSent = $true
                break
            } elseif ($txAck.StartsWith("SS:ERR:")) {
                $port.Close()
                Write-Host ""
                Write-Host "ERROR from IT-Tool: $txAck" -ForegroundColor Red
                Read-Host "Press ENTER to close"
                exit
            } else {
                Write-Host "`n  Unexpected ACK '$txAck' (expected ACK:$txChunkNum), retry $txRetry..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "`n  Chunk $txChunkNum timeout (retry $txRetry/$MAX_RETRIES)..." -ForegroundColor Yellow
            if ($txRetry -eq $MAX_RETRIES) {
                $port.Close()
                Write-Host ""
                Write-Host "ERROR: Transfer failed after $MAX_RETRIES retries on chunk $txChunkNum." -ForegroundColor Red
                Read-Host "Press ENTER to close"
                exit
            }
            Start-Sleep -Milliseconds 500
        }
    }

    if (-not $txSent) {
        $port.Close()
        Write-Host ""
        Write-Host "ERROR: Could not confirm chunk $txChunkNum." -ForegroundColor Red
        Read-Host "Press ENTER to close"
        exit
    }
}

Write-Host ""
Write-Host "  Finalizing $txName..." -ForegroundColor Yellow
$txEndBytes = [System.Text.Encoding]::UTF8.GetBytes("SS_END`n")
$port.BaseStream.Write($txEndBytes, 0, $txEndBytes.Length)
$port.BaseStream.Flush()

$port.ReadTimeout  = 15000
$txFinalResp       = ""
try {
    $txFinalDeadline = (Get-Date).AddMilliseconds(15000)
    while ((Get-Date) -lt $txFinalDeadline) {
        $txFl = $port.ReadLine().Trim()
        if ($txFl.StartsWith("SS:OK:") -or $txFl.StartsWith("SS:ERR:")) { $txFinalResp = $txFl; break }
    }
} catch { }

if ($txFinalResp -eq "") {
    $port.Close()
    Write-Host ""
    Write-Host "ERROR: No final response from IT-Tool for $txName (SD write timeout?)." -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit
} elseif ($txFinalResp.StartsWith("SS:ERR:")) {
    $port.Close()
    Write-Host ""
    Write-Host "ERROR from IT-Tool: $txFinalResp" -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit
}
Write-Host "  $txName saved OK -> $($txFinalResp.Substring(6))" -ForegroundColor Green
Write-Host ""

Start-Sleep -Milliseconds 1500

# ============================================================
#  STEP 11 -- SEND B.Username
# ============================================================
Write-Host "Sending B.Username..." -ForegroundColor Yellow

$txBytes  = $bytesUsername
$txName   = "B.Username"
$txTotal  = $txBytes.Length

$txHeader      = "SS_BEGIN:${subFolder}|${txName}|${txTotal}`n"
$txHeaderBytes = [System.Text.Encoding]::UTF8.GetBytes($txHeader)
$port.BaseStream.Write($txHeaderBytes, 0, $txHeaderBytes.Length)
$port.BaseStream.Flush()

Write-Host "  Waiting for SS_READY..." -ForegroundColor Yellow
$txReady    = ""
$txDeadline = (Get-Date).AddMilliseconds($port.ReadTimeout)
try {
    while ((Get-Date) -lt $txDeadline) {
        $txLine = $port.ReadLine().Trim()
        if ($txLine -eq "SS_READY")          { $txReady = $txLine; break }
        if ($txLine.StartsWith("SS:ERR:"))   { $txReady = $txLine; break }
        Write-Host "    [serial noise] $txLine" -ForegroundColor DarkGray
    }
} catch { }

if ($txReady -ne "SS_READY") {
    $port.Close()
    Write-Host ""
    if ($txReady -eq "") {
        Write-Host "ERROR: IT-Tool did not respond to SS_BEGIN for $txName (timeout)." -ForegroundColor Red
        Write-Host "  Make sure IT-Tool is on ReadyUSB > Script_Saver > Script_Saver screen." -ForegroundColor Yellow
    } else {
        Write-Host "ERROR: $txName -- Unexpected response: '$txReady'" -ForegroundColor Red
    }
    Read-Host "Press ENTER to close"
    exit
}
Write-Host "  IT-Tool ready. Transferring $txName..." -ForegroundColor Green

$txOffset   = 0
$txChunkNum = 0
while ($txOffset -lt $txTotal) {
    $txRemaining   = $txTotal - $txOffset
    $txToSend      = [Math]::Min($CHUNK_SIZE, $txRemaining)
    $txChunkNum++
    $txIsLast      = ($txOffset + $txToSend -ge $txTotal)

    $txSent = $false
    for ($txRetry = 1; $txRetry -le $MAX_RETRIES; $txRetry++) {
        try {
            $port.BaseStream.Write($txBytes, $txOffset, $txToSend)
            $port.BaseStream.Flush()

            if ($txIsLast) {
                $txOffset += $txToSend
                $txPct = 100
                Write-Host "`r  [##################################################] $txPct%  $([Math]::Round($txOffset/1024,1))/$([Math]::Round($txTotal/1024,1)) KB  " -NoNewline -ForegroundColor Green
                $txSent = $true
                break
            }

            $port.ReadTimeout = $ACK_TIMEOUT
            $txAck            = ""
            $txAckDeadline    = (Get-Date).AddMilliseconds($ACK_TIMEOUT)
            while ((Get-Date) -lt $txAckDeadline) {
                $txAckLine = $port.ReadLine().Trim()
                if ($txAckLine.StartsWith("ACK:") -or $txAckLine.StartsWith("SS:")) { $txAck = $txAckLine; break }
            }

            if ($txAck -eq "ACK:$txChunkNum") {
                $txOffset += $txToSend
                $txPct = [Math]::Round(($txOffset / $txTotal) * 100)
                Write-Host "`r  [$("$("█" * [int]($txPct/2))$("-" * (50-[int]($txPct/2)))")] $txPct%  $([Math]::Round($txOffset/1024,1))/$([Math]::Round($txTotal/1024,1)) KB  " -NoNewline -ForegroundColor Green
                $txSent = $true
                break
            } elseif ($txAck.StartsWith("SS:ERR:")) {
                $port.Close()
                Write-Host ""
                Write-Host "ERROR from IT-Tool: $txAck" -ForegroundColor Red
                Read-Host "Press ENTER to close"
                exit
            } else {
                Write-Host "`n  Unexpected ACK '$txAck' (expected ACK:$txChunkNum), retry $txRetry..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "`n  Chunk $txChunkNum timeout (retry $txRetry/$MAX_RETRIES)..." -ForegroundColor Yellow
            if ($txRetry -eq $MAX_RETRIES) {
                $port.Close()
                Write-Host ""
                Write-Host "ERROR: Transfer failed after $MAX_RETRIES retries on chunk $txChunkNum." -ForegroundColor Red
                Read-Host "Press ENTER to close"
                exit
            }
            Start-Sleep -Milliseconds 500
        }
    }

    if (-not $txSent) {
        $port.Close()
        Write-Host ""
        Write-Host "ERROR: Could not confirm chunk $txChunkNum." -ForegroundColor Red
        Read-Host "Press ENTER to close"
        exit
    }
}

Write-Host ""
Write-Host "  Finalizing $txName..." -ForegroundColor Yellow
$txEndBytes = [System.Text.Encoding]::UTF8.GetBytes("SS_END`n")
$port.BaseStream.Write($txEndBytes, 0, $txEndBytes.Length)
$port.BaseStream.Flush()

$port.ReadTimeout  = 15000
$txFinalResp       = ""
try {
    $txFinalDeadline = (Get-Date).AddMilliseconds(15000)
    while ((Get-Date) -lt $txFinalDeadline) {
        $txFl = $port.ReadLine().Trim()
        if ($txFl.StartsWith("SS:OK:") -or $txFl.StartsWith("SS:ERR:")) { $txFinalResp = $txFl; break }
    }
} catch { }

if ($txFinalResp -eq "") {
    $port.Close()
    Write-Host ""
    Write-Host "ERROR: No final response from IT-Tool for $txName (SD write timeout?)." -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit
} elseif ($txFinalResp.StartsWith("SS:ERR:")) {
    $port.Close()
    Write-Host ""
    Write-Host "ERROR from IT-Tool: $txFinalResp" -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit
}
Write-Host "  $txName saved OK -> $($txFinalResp.Substring(6))" -ForegroundColor Green
Write-Host ""

Start-Sleep -Milliseconds 1500

# ============================================================
#  STEP 12 -- SEND C.Password
# ============================================================
Write-Host "Sending C.Password..." -ForegroundColor Yellow

$txBytes  = $bytesPassword
$txName   = "C.Password"
$txTotal  = $txBytes.Length

$txHeader      = "SS_BEGIN:${subFolder}|${txName}|${txTotal}`n"
$txHeaderBytes = [System.Text.Encoding]::UTF8.GetBytes($txHeader)
$port.BaseStream.Write($txHeaderBytes, 0, $txHeaderBytes.Length)
$port.BaseStream.Flush()

Write-Host "  Waiting for SS_READY..." -ForegroundColor Yellow
$txReady    = ""
$txDeadline = (Get-Date).AddMilliseconds($port.ReadTimeout)
try {
    while ((Get-Date) -lt $txDeadline) {
        $txLine = $port.ReadLine().Trim()
        if ($txLine -eq "SS_READY")          { $txReady = $txLine; break }
        if ($txLine.StartsWith("SS:ERR:"))   { $txReady = $txLine; break }
        Write-Host "    [serial noise] $txLine" -ForegroundColor DarkGray
    }
} catch { }

if ($txReady -ne "SS_READY") {
    $port.Close()
    Write-Host ""
    if ($txReady -eq "") {
        Write-Host "ERROR: IT-Tool did not respond to SS_BEGIN for $txName (timeout)." -ForegroundColor Red
        Write-Host "  Make sure IT-Tool is on ReadyUSB > Script_Saver > Script_Saver screen." -ForegroundColor Yellow
    } else {
        Write-Host "ERROR: $txName -- Unexpected response: '$txReady'" -ForegroundColor Red
    }
    Read-Host "Press ENTER to close"
    exit
}
Write-Host "  IT-Tool ready. Transferring $txName..." -ForegroundColor Green

$txOffset   = 0
$txChunkNum = 0
while ($txOffset -lt $txTotal) {
    $txRemaining   = $txTotal - $txOffset
    $txToSend      = [Math]::Min($CHUNK_SIZE, $txRemaining)
    $txChunkNum++
    $txIsLast      = ($txOffset + $txToSend -ge $txTotal)

    $txSent = $false
    for ($txRetry = 1; $txRetry -le $MAX_RETRIES; $txRetry++) {
        try {
            $port.BaseStream.Write($txBytes, $txOffset, $txToSend)
            $port.BaseStream.Flush()

            if ($txIsLast) {
                $txOffset += $txToSend
                $txPct = 100
                Write-Host "`r  [##################################################] $txPct%  $([Math]::Round($txOffset/1024,1))/$([Math]::Round($txTotal/1024,1)) KB  " -NoNewline -ForegroundColor Green
                $txSent = $true
                break
            }

            $port.ReadTimeout = $ACK_TIMEOUT
            $txAck            = ""
            $txAckDeadline    = (Get-Date).AddMilliseconds($ACK_TIMEOUT)
            while ((Get-Date) -lt $txAckDeadline) {
                $txAckLine = $port.ReadLine().Trim()
                if ($txAckLine.StartsWith("ACK:") -or $txAckLine.StartsWith("SS:")) { $txAck = $txAckLine; break }
            }

            if ($txAck -eq "ACK:$txChunkNum") {
                $txOffset += $txToSend
                $txPct = [Math]::Round(($txOffset / $txTotal) * 100)
                Write-Host "`r  [$("$("█" * [int]($txPct/2))$("-" * (50-[int]($txPct/2)))")] $txPct%  $([Math]::Round($txOffset/1024,1))/$([Math]::Round($txTotal/1024,1)) KB  " -NoNewline -ForegroundColor Green
                $txSent = $true
                break
            } elseif ($txAck.StartsWith("SS:ERR:")) {
                $port.Close()
                Write-Host ""
                Write-Host "ERROR from IT-Tool: $txAck" -ForegroundColor Red
                Read-Host "Press ENTER to close"
                exit
            } else {
                Write-Host "`n  Unexpected ACK '$txAck' (expected ACK:$txChunkNum), retry $txRetry..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "`n  Chunk $txChunkNum timeout (retry $txRetry/$MAX_RETRIES)..." -ForegroundColor Yellow
            if ($txRetry -eq $MAX_RETRIES) {
                $port.Close()
                Write-Host ""
                Write-Host "ERROR: Transfer failed after $MAX_RETRIES retries on chunk $txChunkNum." -ForegroundColor Red
                Read-Host "Press ENTER to close"
                exit
            }
            Start-Sleep -Milliseconds 500
        }
    }

    if (-not $txSent) {
        $port.Close()
        Write-Host ""
        Write-Host "ERROR: Could not confirm chunk $txChunkNum." -ForegroundColor Red
        Read-Host "Press ENTER to close"
        exit
    }
}

Write-Host ""
Write-Host "  Finalizing $txName..." -ForegroundColor Yellow
$txEndBytes = [System.Text.Encoding]::UTF8.GetBytes("SS_END`n")
$port.BaseStream.Write($txEndBytes, 0, $txEndBytes.Length)
$port.BaseStream.Flush()

$port.ReadTimeout  = 15000
$txFinalResp       = ""
try {
    $txFinalDeadline = (Get-Date).AddMilliseconds(15000)
    while ((Get-Date) -lt $txFinalDeadline) {
        $txFl = $port.ReadLine().Trim()
        if ($txFl.StartsWith("SS:OK:") -or $txFl.StartsWith("SS:ERR:")) { $txFinalResp = $txFl; break }
    }
} catch { }

if ($txFinalResp -eq "") {
    $port.Close()
    Write-Host ""
    Write-Host "ERROR: No final response from IT-Tool for $txName (SD write timeout?)." -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit
} elseif ($txFinalResp.StartsWith("SS:ERR:")) {
    $port.Close()
    Write-Host ""
    Write-Host "ERROR from IT-Tool: $txFinalResp" -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit
}
Write-Host "  $txName saved OK -> $($txFinalResp.Substring(6))" -ForegroundColor Green
Write-Host ""

# ============================================================
#  DONE
# ============================================================
$port.Close()

Write-Host "======================================" -ForegroundColor Green
Write-Host "   ALL SCRIPTS SAVED" -ForegroundColor Green
Write-Host "   Folder : $folderName" -ForegroundColor Green
Write-Host "   Dest   : ReadyUSB > $targetFolder" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "  A.WebLink  -> $webLink" -ForegroundColor White
Write-Host "  B.Username -> $username" -ForegroundColor White
Write-Host "  C.Password -> [saved]" -ForegroundColor White
Write-Host ""
Read-Host "Press ENTER to close"