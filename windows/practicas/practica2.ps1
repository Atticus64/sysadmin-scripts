
# Practica DHCP Server
. "$PSScriptRoot\..\functions_windows.ps1"
. "$PSScriptRoot\..\services\dhcp.ps1"


Function Show-Help {
    @"
Uso:
  practica2.ps1 [OPCION]

Opciones:
  --check        Verifica si el rol DHCP Server esta instalado.
  --install      Instala el rol DHCP Server y herramientas administrativas.
  --config       Configura el servidor DHCP solicitando los datos de red.
  --monitor      Monitorea eventos del servicio DHCP.
  --help         Muestra esta ayuda y sale.

Sin opciones:
  Ejecuta el script en modo interactivo mostrando un menu.

Ejemplos:
  .\practica2.ps1 --check
  .\practica2.ps1 --install
  .\practica2.ps1 --config
  .\practica2.ps1 --monitor
  .\practica2.ps1
"@
}


Function Show-Menu {
    Write-Host ""
    Write-Host "========= MENU DHCP ========="
    Write-Host "1) Verificar instalacion"
    Write-Host "2) Instalar DHCP Server"
    Write-Host "3) Configurar DHCP"
    Write-Host "4) Monitorear DHCP"
    Write-Host "5) Salir"
    Write-Host "============================="
}

Function Show-Interactive-Menu () {
    while ($true) {
        Show-Menu
        $option = Read-Host "Selecciona una opcion"

        switch ($option) {
            1 { Get-DhcpInstallation }
            2 { Install-DhcpDependencies }
            3 { ConfigureDhcpServer }
            4 { Get-Monitor-Dhcp }
            5 { Write-Host "Saliendo..."; exit 0 }
            default { Write-Host "Opcion invalida" }
        }
    }
}

Function Main($arguments) {
    switch ($arguments[0]) {
        "--check" { Get-DhcpInstallation }
        "--install" { Install-DhcpDependencies }
        "--config" { ConfigureDhcpServer }
        "--monitor" { Get-Monitor-Dhcp }
        "--help" { Show-Help }
        $null { Show-Interactive-Menu }
        default {
            Write-Host "Opcion no valida. Usa --help para ver las opciones disponibles."
            exit 1
        }
    }
}

Main $args