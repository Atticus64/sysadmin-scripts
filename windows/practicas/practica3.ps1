
# Practica DNS Server
. "$PSScriptRoot\..\functions_windows.ps1"
. "$PSScriptRoot\..\services\dns.ps1"

Function Show-Help {
@"
Uso:
  practica3.ps1 [OPCION]

Opciones:
  --check        Verifica si el rol DNS Server esta instalado.
  --install      Instala el rol DNS Server y herramientas administrativas.
  --config       Configura el servidor DNS solicitando los datos de red.
  --list         Muestra los dominios configurados en el servidor DNS.
  --add          Agregar un dominio al servidor DNS
  --remove       Eliminar un dominio del servidor DNS
  --help         Muestra esta ayuda y sale.

Sin opciones:
  Ejecuta el script en modo interactivo mostrando un menu.

Ejemplos:
  .\practica3.ps1 --check
  .\practica3.ps1 --install
  .\practica3.ps1 --config
  .\practica3.ps1 --add
  .\practica3.ps1 --remove
"@
}


Function Show-Menu {
    Write-Host ""
    Write-Host "========= MENU DNS ========="
    Write-Host "1) Verificar instalacion"
    Write-Host "2) Instalar DNS Server"
    Write-Host "3) Configurar DNS"
    Write-Host "4) Listar dominios"
    Write-Host "5) Agregar dominio"
    Write-Host "6) Eliminar dominio"
    Write-Host "7) Salir"
    Write-Host "============================="
}

Function Show-Interactive-Menu () {
    while ($true) {
        Show-Menu
        $option = Read-Host "Selecciona una opcion"

        switch ($option) {
            1 { Get-DnsInstallation }
            2 { Install-DnsDependencies }
            3 { AdministrateDNSServer }
            4 { Get-DnsDomains }
            5 { Add-DnsDomain }
            6 { Remove-DnsDomain }
            7 { Write-Host "Saliendo..."; exit 0 }
            default { Write-Host "Opcion invalida" }
        }
    }
}

Function Main($arguments) {
    switch ($arguments[0]) {
        "--check"   { Get-DnsInstallation }
        "--install" { Install-DnsDependencies }
        "--config"  { AdministrateDNSServer }
        "--list"    { Get-DnsDomains }
        "--add"     { Add-DnsDomain }
        "--remove"  { Remove-DnsDomain }
        "--help"    { Show-Help }
        $null       { Show-Interactive-Menu }
        default {
            Write-Host "Opcion no valida. Usa --help para ver las opciones disponibles."
            exit 1
        }
    }
}

Main $args