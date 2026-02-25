. "$PSScriptRoot\..\functions_windows.ps1"

Function Set-ConfigSSHServer () {
    Write-WColor Green "Configurando SSH Server..."
    Write-Host ""
    Start-Service sshd

    Set-Service -Name sshd -StartupType 'Automatic'

    if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
        Write-Output "Creando regla de firewall para SSH Server"
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    } else {
        Write-Output "Regla de firewall para SSH Server ya existe"
    }
  
    Write-WColor Green "Servidor SSH configurado correctamente."
    Write-Host ""
}


Function Get-SSHInstallation {
    Write-WColor Cyan "Verificando instalacion de SSH Server..."
    Write-Host ""

    $results = Get-WindowsCapability -Online | Where-Object Name -like "OpenSSH.Server*"
    if ($results.Count -gt 0) {
        Write-WColor Green "SSH Server esta instalado"
        Write-Host ""
    } else {
        Write-WColor Red "SSH Server NO esta instalado"
        Write-Host ""
        Install-SSHDependencies
    }
    Write-Host ""
}

Function Install-SSHDependencies {
    Write-WColor Cyan "Instalando SSH Server..."
    Write-Host ""

    $names = (Get-WindowsCapability -Online | Where-Object Name -like "OpenSSH*") 
    $server = $names | Where-Object Name -like "*Server*"
    $client = $names | Where-Object Name -like "*Client*"

    if (-not $server) {
        Write-WColor Red "No se encontro el rol de SSH Server en las capacidades de Windows"
        Write-Host ""
        Write-Host "Instalando OpenSSH Server"
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    } else {
        Write-WColor Yellow "SSH Server ya esta instalado"
        Write-Host ""
    }

    if (-not $client) {
        Write-WColor Red "No se encontro el rol de SSH Client en las capacidades de Windows"
        Write-Host ""
        Write-Host "Instalando OpenSSH Client"
        Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
    } else {
        Write-WColor Yellow "SSH Client ya esta instalado"
        Write-Host ""
    }

    Write-Host ""
}

