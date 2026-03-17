[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'SilentlyContinue'

function Reduce-Telemetry {

    # --- Registry: DataCollection ---
    New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Force | Out-Null
    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0 -Type DWord
    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'MaxTelemetryAllowed' 0 -Type DWord
    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1 -Type DWord

    # --- Registry: CloudContent ---
    New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Force | Out-Null
    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1 -Type DWord
    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1 -Type DWord
    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1 -Type DWord

    # --- Registry: Activity History ---
    New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Force | Out-Null
    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0 -Type DWord
    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0 -Type DWord
    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0 -Type DWord

    # --- Registry: Advertising ID ---
    New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' -Force | Out-Null
    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1 -Type DWord
    New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Force | Out-Null
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 -Type DWord

    # --- Registry: Privacy / Tailored Experiences ---
    New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' -Force | Out-Null
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0 -Type DWord

    # --- Registry: Input Personalization ---
    New-Item 'HKCU:\Software\Microsoft\InputPersonalization' -Force | Out-Null
    Set-ItemProperty 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1 -Type DWord
    Set-ItemProperty 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 1 -Type DWord

    # --- Registry: Feedback ---
    New-Item 'HKCU:\Software\Microsoft\Siuf\Rules' -Force | Out-Null
    Set-ItemProperty 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0 -Type DWord
    Set-ItemProperty 'HKCU:\Software\Microsoft\Siuf\Rules' 'PeriodInNanoSeconds' 0 -Type QWord

    # --- Services ---
    Stop-Service DiagTrack -Force
    Set-Service DiagTrack -StartupType Disabled
    Stop-Service dmwappushservice -Force
    Set-Service dmwappushservice -StartupType Disabled

    # --- Scheduled Tasks ---
    $tasks = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
        '\Microsoft\Windows\Application Experience\StartupAppTask',
        '\Microsoft\Windows\Application Experience\PcaPatchDbTask',
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting'
    )
    foreach ($t in $tasks) { schtasks /Change /TN $t /Disable 2>$null | Out-Null }

    Write-Host ""
    Write-Host "Telemetry reduced successfully." -ForegroundColor Green
    Write-Host "Restart Windows for full effect." -ForegroundColor Yellow
}

function Restore-Telemetry {

    # --- Registry: DataCollection ---
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'MaxTelemetryAllowed' -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' -ErrorAction SilentlyContinue

    # --- Registry: CloudContent ---
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' -ErrorAction SilentlyContinue

    # --- Registry: Activity History ---
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' -ErrorAction SilentlyContinue

    # --- Registry: Advertising ID ---
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' -ErrorAction SilentlyContinue

    # --- Registry: Privacy / Input / Feedback ---
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Siuf\Rules' 'PeriodInNanoSeconds' -ErrorAction SilentlyContinue

    # --- Services ---
    Set-Service DiagTrack -StartupType Automatic
    Start-Service DiagTrack
    Set-Service dmwappushservice -StartupType Manual
    Start-Service dmwappushservice

    # --- Scheduled Tasks ---
    $tasks = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
        '\Microsoft\Windows\Application Experience\StartupAppTask',
        '\Microsoft\Windows\Application Experience\PcaPatchDbTask',
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting'
    )
    foreach ($t in $tasks) { schtasks /Change /TN $t /Enable 2>$null | Out-Null }

    Write-Host ""
    Write-Host "Telemetry restored successfully." -ForegroundColor Green
    Write-Host "Restart Windows for full effect." -ForegroundColor Yellow
}

# --- MENU ---
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   Windows Telemetry & Privacy Manager" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Option 1 - REDUCE TELEMETRY:" -ForegroundColor White
Write-Host "  Forces lowest diagnostic level, disables DiagTrack"
Write-Host "  service, CEIP tasks, Advertising ID, Activity History"
Write-Host "  and input personalization data collection."
Write-Host ""
Write-Host "Option 2 - RESTORE TELEMETRY:" -ForegroundColor White
Write-Host "  Removes policy overrides and re-enables services"
Write-Host "  and tasks to Windows defaults."
Write-Host ""

$choice = Read-Host "Type 1 to REDUCE or 2 to RESTORE telemetry"

if ($choice -eq '1') {
    Reduce-Telemetry
} elseif ($choice -eq '2') {
    Restore-Telemetry
} else {
    Write-Host ""
    Write-Host "Invalid option. Run again and choose 1 or 2." -ForegroundColor Red
}
