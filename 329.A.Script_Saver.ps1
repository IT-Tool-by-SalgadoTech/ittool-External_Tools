Set-ExecutionPolicy Bypass -Scope Process -Force
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host " _____ _____  _______ ____   ____  _     " -ForegroundColor Cyan
Write-Host "|_   _|_   _||__   __/ __ \ / __ \| |    " -ForegroundColor Cyan
Write-Host "  | |   | |     | | | |  | | |  | | |    " -ForegroundColor Cyan
Write-Host "  | |   | |     | | | |  | | |  | | |    " -ForegroundColor Cyan
Write-Host " _| |_  | |     | | | |__| | |__| | |___ " -ForegroundColor Cyan
Write-Host "|_____| |_|     |_|  \____/ \____/|_____|" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ==================================================================" -ForegroundColor White
Write-Host "  IT-Tool by SalgadoTech" -ForegroundColor Cyan
Write-Host "  Script: 329_A_Script_Saver.ps1" -ForegroundColor DarkCyan
Write-Host "  ScriptID: ST-WIN-0329" -ForegroundColor Cyan
Write-Host "  Version: 1.1" -ForegroundColor DarkCyan
Write-Host "  Date: 2026-06-09" -ForegroundColor DarkCyan
Write-Host "  Category: Windows > ReadyUSB" -ForegroundColor DarkCyan
Write-Host "  Description: Saves scripts to IT-Tool SD card via chunked serial protocol" -ForegroundColor DarkCyan
Write-Host "  (c) 2025 SalgadoTech - All Rights Reserved" -ForegroundColor DarkCyan
Write-Host "  Unauthorized distribution prohibited" -ForegroundColor DarkCyan
Write-Host "  ==================================================================" -ForegroundColor White
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
# ============================================================
$comPort    = ""
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
#  STEP 2 — CONTROLLED RESET
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
#  STEP 3 — FILE NAME
# ============================================================
$fileName = ""
while ([string]::IsNullOrWhiteSpace($fileName)) {
    $fileName = (Read-Host "Enter file name (without extension)").Trim()
}

# ============================================================
#  STEP 4 — SCRIPT TYPE
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
#  STEP 5 — DESTINATION FOLDER
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
Write-Host "Destination: $targetFolder" -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 6 — PASTE YOUR SCRIPT
# ============================================================
Write-Host "Paste your script below." -ForegroundColor Cyan
Write-Host "When finished, press ENTER twice, type exactly ITTOOL, and press ENTER to finish." -ForegroundColor Yellow
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
#  STEP 7 — BUILD THE IT_SCRIPT
# ============================================================
$nl = "`n"

if ($scriptType -eq "Windows") {
    $itscript = 'WTIME 1000' + $nl +
            'SCRIPTL' + $nl +
            $userText  + $nl +
            'FIN_SCRIPTL'
} elseif ($scriptType -eq "WindowsLineal") {
    $itscript = 'WTIME 1000' + $nl +
            'SCRIPT ' + $userText + $nl +
            'ENTER'
} elseif ($scriptType -eq "WindowsBase64") {
    $bytes64 = [System.Text.Encoding]::UTF8.GetBytes($userText)
    $b64     = [Convert]::ToBase64String($bytes64)
    $itscript = 'WTIME 1000' + $nl +
            'SCRIPT powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(' + "'" + $b64 + "'" + ')) | Invoke-Expression"' + $nl +
            'ENTER'
} elseif ($scriptType -eq "LinuxBase64") {
    $bytes64 = [System.Text.Encoding]::UTF8.GetBytes($userText)
    $b64     = [Convert]::ToBase64String($bytes64)
    $itscript = 'WTIME 800' + $nl +
            "SCRIPT echo $b64 | base64 -d > `$HOME/ittool_run.sh && sh `$HOME/ittool_run.sh" + $nl +
            'ENTER'
}

# ============================================================
#  STEP 8 — PREPARAR BYTES DEL PACKET
# ============================================================
$bytes = [System.Text.Encoding]::UTF8.GetBytes($itscript)
$total = $bytes.Length

Write-Host ""
Write-Host "Payload size : $total bytes  ($([Math]::Round($total/1024, 1)) KB)" -ForegroundColor Cyan
Write-Host "Protocol     : Chunked v55 (4096 B/chunk, ACK por chunk)" -ForegroundColor Cyan
Write-Host "Baud rate    : 460800" -ForegroundColor Cyan
$estSec = [Math]::Round($total / (460800 / 8), 1)
Write-Host "Est. time    : ~$estSec sec" -ForegroundColor Cyan
Write-Host ""

# ============================================================
#  STEP 9 — ABRIR PUERTO
# ============================================================
Write-Host "Connecting to IT-Tool on $comPort @ 460800..." -ForegroundColor Yellow

$port = New-Object System.IO.Ports.SerialPort $comPort, 460800, None, 8, One
$port.NewLine      = "`n"
$port.DtrEnable    = $false
$port.RtsEnable    = $false
$port.Encoding     = [System.Text.Encoding]::UTF8
$port.ReadTimeout  = 10000   # 10 s — tiempo para SD_MMC.open() y fs ops
$port.WriteTimeout = 10000
$port.Open()

Start-Sleep -Milliseconds 300

# ============================================================
#  STEP 10 — ENVIAR SS_BEGIN y esperar SS_READY
# ============================================================
$header = "SS_BEGIN:${targetFolder}|${fileName}|${total}`n"
$headerBytes = [System.Text.Encoding]::UTF8.GetBytes($header)
$port.BaseStream.Write($headerBytes, 0, $headerBytes.Length)
$port.BaseStream.Flush()

Write-Host "Waiting for SS_READY..." -ForegroundColor Yellow
$ready = ""
$deadline = (Get-Date).AddMilliseconds($port.ReadTimeout)
try {
    while ((Get-Date) -lt $deadline) {
        $line = $port.ReadLine().Trim()
        if ($line -eq "SS_READY") { $ready = $line; break }
        if ($line.StartsWith("SS:ERR:")) { $ready = $line; break }
        # Cualquier otra línea es ruido Serial del firmware (ej: [SD_MMC] OK) — ignorar
        Write-Host "  [serial noise] $line" -ForegroundColor DarkGray
    }
} catch {
    # timeout de ReadLine
}
if ($ready -ne "SS_READY") {
    $port.Close()
    Write-Host ""
    if ($ready -eq "") {
        Write-Host "ERROR: IT-Tool did not respond to SS_BEGIN (timeout)." -ForegroundColor Red
        Write-Host "  Make sure IT-Tool is on ReadyUSB > Script_Saver > Script_Saver screen." -ForegroundColor Yellow
    } else {
        Write-Host "ERROR: Unexpected response to SS_BEGIN: '$ready'" -ForegroundColor Red
    }
    Read-Host "Press ENTER to close"
    exit
}
Write-Host "IT-Tool ready. Starting transfer..." -ForegroundColor Green
Write-Host ""

# ============================================================
#  STEP 11 — ENVIAR CHUNKS CON ACK
# ============================================================
$CHUNK_SIZE  = 4096
$offset      = 0
$chunkNum    = 0
$ACK_TIMEOUT = 10000   # ms — tiempo para que el ESP escriba a SD y responda
$MAX_RETRIES = 3

function Write-Progress-Bar {
    param([int]$pct, [int]$rxBytes, [int]$total)
    $bar   = [int]($pct / 2)   # 50 chars de barra
    $filled = "#" * $bar
    $empty  = "-" * (50 - $bar)
    $kb     = [Math]::Round($rxBytes / 1024, 1)
    $totalKb= [Math]::Round($total   / 1024, 1)
    Write-Host "`r  [$filled$empty] $pct%  ${kb}/${totalKb} KB  " -NoNewline -ForegroundColor Green
}

while ($offset -lt $total) {
    $remaining   = $total - $offset
    $toSend      = [Math]::Min($CHUNK_SIZE, $remaining)
    $chunkNum++
    $isLastChunk = ($offset + $toSend -ge $total)

    $sent = $false
    for ($retry = 1; $retry -le $MAX_RETRIES; $retry++) {
        try {
            $port.BaseStream.Write($bytes, $offset, $toSend)
            $port.BaseStream.Flush()

            if ($isLastChunk) {
                # Último chunk — el IT-Tool detecta SS_END y cierra el archivo
                # sin enviar ACK para el chunk parcial; pasamos directo a SS_END
                $offset += $toSend
                Write-Progress-Bar -pct 100 -rxBytes $offset -total $total
                $sent = $true
                break
            }

            # Esperar ACK:<N> — drenar ruido Serial hasta encontrarlo
            $port.ReadTimeout = $ACK_TIMEOUT
            $ack = ""
            $ackDeadline = (Get-Date).AddMilliseconds($ACK_TIMEOUT)
            while ((Get-Date) -lt $ackDeadline) {
                $ackLine = $port.ReadLine().Trim()
                if ($ackLine.StartsWith("ACK:") -or $ackLine.StartsWith("SS:")) {
                    $ack = $ackLine; break
                }
                # ruido Serial — ignorar silenciosamente
            }

            if ($ack -eq "ACK:$chunkNum") {
                $offset += $toSend
                $pct = [Math]::Round(($offset / $total) * 100)
                Write-Progress-Bar -pct $pct -rxBytes $offset -total $total
                $sent = $true
                break
            } elseif ($ack.StartsWith("SS:ERR:")) {
                $port.Close()
                Write-Host ""
                Write-Host "ERROR from IT-Tool: $ack" -ForegroundColor Red
                Read-Host "Press ENTER to close"
                exit
            } else {
                Write-Host "`n  Unexpected ACK '$ack' (expected ACK:$chunkNum), retry $retry..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "`n  Chunk $chunkNum timeout (retry $retry/$MAX_RETRIES)..." -ForegroundColor Yellow
            if ($retry -eq $MAX_RETRIES) {
                $port.Close()
                Write-Host ""
                Write-Host "ERROR: Transfer failed after $MAX_RETRIES retries on chunk $chunkNum." -ForegroundColor Red
                Read-Host "Press ENTER to close"
                exit
            }
            Start-Sleep -Milliseconds 500
        }
    }

    if (-not $sent) {
        $port.Close()
        Write-Host ""
        Write-Host "ERROR: Could not confirm chunk $chunkNum." -ForegroundColor Red
        Read-Host "Press ENTER to close"
        exit
    }
}

Write-Host ""   # newline tras la barra de progreso

# ============================================================
#  STEP 12 — ENVIAR SS_END y esperar SS:OK
# ============================================================
Write-Host "Finalizing..." -ForegroundColor Yellow
$endBytes = [System.Text.Encoding]::UTF8.GetBytes("SS_END`n")
$port.BaseStream.Write($endBytes, 0, $endBytes.Length)
$port.BaseStream.Flush()

$port.ReadTimeout = 15000   # 15 s — el ESP hace rename en SD
$finalResp = ""
try {
    $finalDeadline = (Get-Date).AddMilliseconds(15000)
    while ((Get-Date) -lt $finalDeadline) {
        $fl = $port.ReadLine().Trim()
        if ($fl.StartsWith("SS:OK:") -or $fl.StartsWith("SS:ERR:")) {
            $finalResp = $fl; break
        }
        # ruido Serial — ignorar
    }
} catch {
    # timeout
}

$port.Close()

Write-Host ""
if ($finalResp -eq "") {
    Write-Host "ERROR: No final response from IT-Tool (SD write timeout?)." -ForegroundColor Red
} elseif ($finalResp.StartsWith("SS:OK:")) {
    $savedName = $finalResp.Substring(6)
    Write-Host "======================================" -ForegroundColor Green
    Write-Host "   SAVED OK" -ForegroundColor Green
    Write-Host "   File : $savedName" -ForegroundColor Green
    Write-Host "   Dest : ReadyUSB > $targetFolder" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Green
} elseif ($finalResp.StartsWith("SS:ERR:")) {
    Write-Host "ERROR from IT-Tool: $finalResp" -ForegroundColor Red
} else {
    Write-Host "Unexpected final response: '$finalResp'" -ForegroundColor Yellow
}
Write-Host ""
Read-Host "Press ENTER to close"