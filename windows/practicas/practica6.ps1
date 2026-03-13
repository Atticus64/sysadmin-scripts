. "$PSScriptRoot\..\services\http.ps1"


Function Show-Help {
@"
Uso:
  http_manager.ps1 [OPCION] [ARGS]

Opciones:
  --check                              Verifica si los servicios HTTP estan instalados.
  --install-iis [--port <num>]         Instala IIS. Puerto por defecto: 80.
  --uninstall-iis                      Desinstala IIS.
  --reinstall-iis [--port <num>]       Reinstala IIS en el puerto indicado.
  --versions <apache|nginx>            Lista versiones disponibles en Chocolatey.
  --install <apache|nginx> [--port <num>]
                                       Instala la ultima version. Puerto por defecto: 80.
  --install <apache|nginx> <version> [--port <num>]
                                       Instala una version especifica.
  --uninstall <apache|nginx>           Desinstala Apache o Nginx.
  --reinstall <apache|nginx> [--port <num>]
                                       Reinstala Apache o Nginx.
  --reinstall <apache|nginx> <version> [--port <num>]
                                       Reinstala en version especifica.
  --help                               Muestra esta ayuda y sale.

Sin opciones:
  Ejecuta el script en modo interactivo mostrando un menu.

Ejemplos:
  .\http_manager.ps1 --check
  .\http_manager.ps1 --install-iis
  .\http_manager.ps1 --install-iis --port 8080
  .\http_manager.ps1 --versions apache
  .\http_manager.ps1 --install apache
  .\http_manager.ps1 --install apache --port 8080
  .\http_manager.ps1 --install apache 2.4.57 --port 8081
  .\http_manager.ps1 --install nginx --port 9090
  .\http_manager.ps1 --uninstall nginx
  .\http_manager.ps1 --reinstall apache 2.4.62 --port 80
  .\http_manager.ps1
"@
}






Function Show-Menu {
    Write-Host ""
    Write-Host "======= MENU HTTP MANAGER ======="
    Write-Host "1) Verificar instalacion"
    Write-Host "2) Instalar dependencias IIS"
    Write-Host "3) Listar versiones  <apache|nginx>"
    Write-Host "4) Instalar servicio <apache|nginx>"
    Write-Host "5) Desinstalar servicio <apache|nginx>"
    Write-Host "6) Reinstalar servicio <apache|nginx>"
    Write-Host "7) Salir"
    Write-Host "=================================="
}


Function Select-HttpService {
    param([string]$Action)

    Write-Host ""
    Write-Host "Selecciona el servicio para '$Action':"
    Write-Host "  1) Apache (Win64)"
    Write-Host "  2) Nginx  (Windows)"
    $opt = Read-Host "Opcion [1/2]"

    switch ($opt) {
        "1" { return "apache" }
        "2" { return "nginx"  }
        default {
            Write-Host "Opcion invalida."
            return $null
        }
    }
}


Function Select-ServiceVersion {
    param([string]$Service)

    $info = Get-HttpServiceVersions -Service $Service

    if (-not $info) {
        Write-Host "[Error] No se pudo obtener la lista de versiones. Abortando."
        return $null
    }

    Write-Host ""
    Write-Host "Selecciona la version a instalar:"
    Write-Host "  1) Latest  [$($info.Latest)]"
    Write-Host "  2) Oldest  [$($info.Oldest)]"
    Write-Host "  3) LTS     [$($info.LTS)]"
    Write-Host "  4) Otra    (ingresar manualmente)"

    do {
        $opt = Read-Host "Opcion [1/2/3/4]"
        switch ($opt) {
            "1" { return $info.Latest }
            "2" { return $info.Oldest }
            "3" { return $info.LTS    }
            "4" {
                $manual = Read-Host "Escribe la version exacta (ej: 2.4.57)"
                $manual = $manual.Trim()
                if ($manual -eq "") {
                    Write-Host "[Error] Version vacia. Intenta de nuevo."
                    $opt = ""   
                } elseif ($info.All -notcontains $manual) {
                    Write-Host "[Warn] La version '$manual' no esta en la lista de Chocolatey."
                    $confirm = Read-Host "Intentar instalar de todas formas? [s/N]"
                    if ($confirm -eq "s" -or $confirm -eq "S") { return $manual }
                    $opt = ""   
                } else {
                    return $manual
                }
            }
            default { Write-Host "Opcion invalida. Elige 1, 2, 3 o 4." }
        }
    } while ($opt -notin @("1","2","3","4") -or $opt -eq "")

    return $info.Latest  
}



Function Get-PortFromArgs {
    param([string[]]$ArgList)
    for ($i = 0; $i -lt $ArgList.Count - 1; $i++) {
        if ($ArgList[$i] -eq "--port") {
            $raw = $ArgList[$i + 1]
            $p   = Assert-Port -PortInput $raw
            if ($null -ne $p) { return $p }
            exit 1
        }
    }
    return 0   
}






Function Show-InteractiveMenu {
    while ($true) {
        Show-Menu
        $option = Read-Host "Selecciona una opcion"

        switch ($option) {

            "1" {
                Get-HttpInstallation
            }

            "2" {
                $port = Read-Port -ServiceName "IIS" -Default 80
                Install-IISDaemon -Port $port
            }

            "3" {
                $svc = Select-HttpService -Action "listar versiones"
                if ($svc) { Get-HttpServiceVersions -Service $svc }
            }

            "4" {
                $svc = Select-HttpService -Action "instalar"
                if ($svc) {
                    $ver  = Select-ServiceVersion -Service $svc
                    $port = Read-Port -ServiceName $svc -Default 80
                    Install-HttpService -Service $svc -Version $ver -Port $port
                }
            }

            "5" {
                $svc = Select-HttpService -Action "desinstalar"
                if ($svc) {
                    $confirm = Read-Host "Confirmar desinstalacion de '$svc' [s/N]"
                    if ($confirm -eq "s" -or $confirm -eq "S") {
                        Uninstall-HttpService -Service $svc
                    } else {
                        Write-Host "Cancelado."
                    }
                }
            }

            "6" {
                $svc = Select-HttpService -Action "reinstalar"
                if ($svc) {
                    $ver  = Select-ServiceVersion -Service $svc
                    $port = Read-Port -ServiceName $svc -Default 80
                    Reinstall-HttpService -Service $svc -Version $ver -Port $port
                }
            }

            "7" {
                Write-Host "Saliendo..."
                exit 0
            }

            default {
                Write-Host "Opcion invalida."
            }
        }
    }
}






Function Main($arguments) {
    switch ($arguments[0]) {

        "--check" {
            Get-HttpInstallation
        }

        "--install-iis" {
            $port = Get-PortFromArgs -ArgList $arguments
            if ($port -eq 0) { $port = Read-Port -ServiceName "IIS" -Default 80 }
            Install-IISDaemon -Port $port
        }

        "--uninstall-iis" {
            Uninstall-IISDaemon
        }

        "--reinstall-iis" {
            $port = Get-PortFromArgs -ArgList $arguments
            if ($port -eq 0) { $port = Read-Port -ServiceName "IIS" -Default 80 }
            Reinstall-IISDaemon -Port $port
        }

        "--versions" {
            $svc = $arguments[1]
            if ($svc -notin @("apache","nginx")) {
                Write-Host "[Error] Especifica 'apache' o 'nginx'. Ej: --versions apache"
                exit 1
            }
            Get-HttpServiceVersions -Service $svc | Out-Null
        }

        "--install" {
            $svc = $arguments[1]
            if ($svc -notin @("apache","nginx")) {
                Write-Host "[Error] Especifica 'apache' o 'nginx'. Ej: --install apache"
                exit 1
            }
            
            if ($arguments[2] -and $arguments[2] -ne "--port") {
                $ver = $arguments[2]
            } else {
                $ver = Select-ServiceVersion -Service $svc
                if ($null -eq $ver) { exit 1 }
            }
            $port = Get-PortFromArgs -ArgList $arguments
            if ($port -eq 0) { $port = Read-Port -ServiceName $svc -Default 80 }
            Install-HttpService -Service $svc -Version $ver -Port $port
        }

        "--uninstall" {
            $svc = $arguments[1]
            if ($svc -notin @("apache","nginx")) {
                Write-Host "[Error] Especifica 'apache' o 'nginx'. Ej: --uninstall nginx"
                exit 1
            }
            Uninstall-HttpService -Service $svc
        }

        "--reinstall" {
            $svc = $arguments[1]
            if ($svc -notin @("apache","nginx")) {
                Write-Host "[Error] Especifica 'apache' o 'nginx'. Ej: --reinstall apache"
                exit 1
            }
            if ($arguments[2] -and $arguments[2] -ne "--port") {
                $ver = $arguments[2]
            } else {
                $ver = Select-ServiceVersion -Service $svc
                if ($null -eq $ver) { exit 1 }
            }
            $port = Get-PortFromArgs -ArgList $arguments
            if ($port -eq 0) { $port = Read-Port -ServiceName $svc -Default 80 }
            Reinstall-HttpService -Service $svc -Version $ver -Port $port
        }

        "--help" {
            Show-Help
        }

        $null {
            Show-InteractiveMenu
        }

        default {
            Write-Host "Opcion no valida: '$($arguments[0])'. Usa --help para ver las opciones."
            exit 1
        }
    }
}

Main $args