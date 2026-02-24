
# Practica SSH Server
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




Function Show-Help {
@"
Uso:
  practica4.ps1 [OPCION]

Opciones:
  --check        Verifica si el rol SSH Server esta instalado.
  --install      Instala el rol SSH Server y herramientas administrativas.
  --config       Configura el servidor SSH solicitando los datos de red.
  --help         Muestra esta ayuda y sale.

Sin opciones:
  Ejecuta el script en modo interactivo mostrando un menu.

Ejemplos:
  .\practica4.ps1 --check
  .\practica4.ps1 --config
"@
}


Function Show-Menu {
    Write-Host ""
    Write-Host "========= MENU SSH ========="
    Write-Host "1) Verificar instalacion"
    Write-Host "2) Instalar SSH Server"
    Write-Host "3) Configurar SSH"
    Write-Host "4) Salir"
    Write-Host "============================="
}

Function Show-Interactive-Menu () {
    while ($true) {
        Show-Menu
        $option = Read-Host "Selecciona una opcion"

        switch ($option) {
            1 { Get-SSHInstallation }
            2 { Install-SSHDependencies }
            3 { Set-ConfigSSHServer }
            4 { Write-Host "Saliendo..."; exit 0 }
            default { Write-Host "Opcion invalida" }
        }
    }
}

Function Main($arguments) {
    switch ($arguments[0]) {
        "--check"   { Get-SSHInstallation }
        "--install" { Install-SSHDependencies }
        "--config"  { Set-ConfigSSHServer }
        "--help"    { Show-Help }
        $null       { Show-Interactive-Menu }
        default {
            Write-Host "Opcion no valida. Usa --help para ver las opciones disponibles."
            exit 1
        }
    }
}

Main $args