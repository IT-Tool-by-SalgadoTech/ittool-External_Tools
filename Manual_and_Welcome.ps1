Set-ExecutionPolicy Bypass -Scope CurrentUser -Force | Out-Null

$nl = [Environment]::NewLine

# Download PDF to Documents\ITTOOL
$PdfPath = [System.IO.Path]::Combine([Environment]::GetFolderPath('MyDocuments'),'ITTOOL','IT-Tool_Manual.pdf')
$PdfDir  = Split-Path $PdfPath
if(-not(Test-Path $PdfDir)){New-Item -ItemType Directory -Path $PdfDir -Force | Out-Null}
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/IT-Tool-by-SalgadoTech/ittool-External_Tools/main/IT-Tool%20Manual.pdf" -OutFile $PdfPath

# Download Logo
$LogoUrl  = "https://raw.githubusercontent.com/IT-Tool-by-SalgadoTech/ittool-External_Tools/main/LOGO%20VIDEO%20black.png"
$LogoPath = Join-Path $env:TEMP "ittool_logo.png"

try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing

    try { (New-Object Net.WebClient).DownloadFile($LogoUrl, $LogoPath) } catch {}

    # Build Form
    $form                  = New-Object Windows.Forms.Form
    $form.Text             = "IT-Tool"
    $form.StartPosition    = "CenterScreen"
    $form.FormBorderStyle  = "FixedDialog"
    $form.TopMost          = $true
    $form.MaximizeBox      = $false
    $form.MinimizeBox      = $false
    $form.Size             = [Drawing.Size]::new(720, 420)

    # Logo
    $pic          = New-Object Windows.Forms.PictureBox
    $pic.Dock     = "Top"
    $pic.Height   = 300
    $pic.SizeMode = "Zoom"
    if (Test-Path $LogoPath) { $pic.Image = [Drawing.Image]::FromFile($LogoPath) }

    # Subtitle
    $subtitle           = New-Object Windows.Forms.Label
    $subtitle.Text      = "IT-Tool - Welcome to ReadyUSB"
    $subtitle.Font      = New-Object Drawing.Font("Segoe UI Semibold", 16)
    $subtitle.TextAlign = "MiddleCenter"
    $subtitle.Dock      = "Top"
    $subtitle.Height    = 36

    # Ready message
    $ready           = New-Object Windows.Forms.Label
    $ready.Text      = "The environment is ready!" + $nl + "The ReadyUSB Manual is now in the Desktop Folder!!"
    $ready.Font      = New-Object Drawing.Font("Segoe UI", 12, [Drawing.FontStyle]::Italic)
    $ready.TextAlign = "MiddleCenter"
    $ready.Dock      = "Top"
    $ready.Height    = 48

    $form.Controls.AddRange(@($ready, $subtitle, $pic))

    # Auto-close after 5 seconds
    $t = New-Object Windows.Forms.Timer
    $t.Interval = 5000
    $t.Add_Tick({ $t.Stop(); $form.Close() })
    $t.Start()

    [void]$form.ShowDialog()

    # Open PDF
    Start-Process $PdfPath

} catch {}

# Console banner
$banner = "===============================" + $nl +
          " IT-Tool - Welcome to ReadyUSB" + $nl +
          " The environment is ready!"     + $nl +
          " The ReadyUSB Manual is now in the Desktop Folder!!" + $nl +
          "==============================="
Write-Host $banner -ForegroundColor Cyan