. "$PSScriptRoot\..\functions_windows.ps1"
. "$PSScriptRoot\..\services\ftp.ps1"


Function Show-Help {
@"
Uso:
  practica5.ps1 [OPCION]

Opciones:
  --check        Verifica si el servicio $script:ServiceName esta instalado.
  --install      Instala las dependencias necesarias y configura el servidor FTP.
  --add-users    Agregar usuarios a los grupos.
  --chuser       Cambiar a un usuario de grupo.
  --ls           Listar los usuarios configurados en FTP.
  --help         Muestra esta ayuda y sale.

Sin opciones:
  Ejecuta el script en modo interactivo mostrando un menu.

Ejemplos:
  .\practica5.ps1 --check
  .\practica5.ps1 --install
  .\practica5.ps1 --add-users
  .\practica5.ps1 --chuser
  .\practica5.ps1 --ls
  .\practica5.ps1
"@
}


Function Show-Menu {
    Write-Host ""
    Write-Host "========= MENU FTP ========="
    Write-Host "1) Verificar instalacion"
    Write-Host "2) Instalar dependencias"
    Write-Host "3) Agregar usuarios"
    Write-Host "4) Cambiar usuario grupo"
    Write-Host "5) Listar usuarios"
    Write-Host "6) Salir"
    Write-Host "============================="
}

Function Show-InteractiveMenu {
    while ($true) {
        Show-Menu
        $option = Read-Host "Selecciona una opcion"

        switch ($option) {
            "1" { Get-FtpInstallation }
            "2" {
                Install-FtpDaemon
                Initialize-FtpGroups
            }
            "3" { Add-FtpUsers }
            "4" { Set-FtpUserGroup }
            "5" { Get-FtpUsers }
            "6" { Write-Host "Saliendo..."; exit 0 }
            default { Write-Host "Opcion invalida." }
        }
    }
}

Function Main($arguments) {
    switch ($arguments[0]) {
        "--check"     { Get-FtpInstallation }
        "--install"   {
            Install-FtpDaemon
            Initialize-FtpGroups
        }
        "--add-users" { Add-FtpUsers }
        "--chuser"    { Set-FtpUserGroup }
        "--ls"        { Get-FtpUsers }
        "--help"      { Show-Help }
        $null         { Show-InteractiveMenu }
        default {
            Write-Host "Opcion no valida. Usa --help para ver las opciones disponibles."
            exit 1
        }
    }
}

Main $args