
# Practica SSH Server
. "$PSScriptRoot\..\functions_windows.ps1"
. "$PSScriptRoot\..\ssh.ps1"


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