# Toggle-VMwareServices.ps1
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('stop','start')]
    [string]$mode_star_or_stop
)

# Lista de servicios comunes de VMware que suelen instalarse en Horizon/Tools
$vmwareServices = @(
    'VMAuthdService',           # VMware Workstation/Tools auth
    'VMTools',                  # nombre posible, algunos sistemas usan otros
    'VMwareViewAgent',          # ejemplo de nombre; puede variar
    'VMwareGmsvc',              # VMware Authorization Service (varía)
    'VMwareGraphicsService',
    'VMware USB Arbitration Service','VMUSBArbService',
    'VMwareViewAgent', 'VMwareViewComposerGA', 'VMwareViewComposer', 'VMwareViewPersona',
    'VMwareViewLogon'           # si existen
)

# Detectar nombres reales que contengan 'VMware' (más seguro que lista fija)
$detected = Get-Service | Where-Object { $_.Name -like '*VMware*' -or $_.DisplayName -like '*VMware*' } |
            Select-Object -ExpandProperty Name -ErrorAction SilentlyContinue
$targets = ($vmwareServices + $detected) | Sort-Object -Unique

if (-not $targets -or $targets.Count -eq 0) {
    Write-Host "No se encontraron servicios de VMware en este equipo."
    return
}

if ($Mode -eq 'stop') {
    foreach ($s in $targets) {
        try {
            $svc = Get-Service -Name $s -ErrorAction Stop
            if ($svc.Status -ne 'Stopped') {
                Write-Host "Stopping $s..."
                Stop-Service -Name $s -Force -ErrorAction Stop
            }
            Write-Host "Setting $s startup to Disabled..."
            Set-Service -Name $s -StartupType Disabled
        } catch {
            Write-Host "No encontrado o error con $($s): $($_.Exception.Message)"
        }
    }
    Write-Host "Hecho. Reinicia el PC para asegurar que los controladores se descarguen."
} else {
    foreach ($s in $targets) {
        try {
            Write-Host "Setting $s startup to Manual and starting..."
            Set-Service -Name $s -StartupType Manual
            Start-Service -Name $s -ErrorAction SilentlyContinue
        } catch {
            Write-Host "No encontrado o error con $($s): $($_.Exception.Message)"
        }
    }
    Write-Host "Hecho: servicios intentados para restaurar."
}
