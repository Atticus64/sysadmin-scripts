
# Practica DNS Server
. "$PSScriptRoot\..\functions_windows.ps1"

Function InstallDNSServer() {

    if (-not (CheckWindowsFeature "DNS")) {
        Write-WColor Green "Instalando DNS Server..."
        Write-Host ""
        Install-WindowsFeature DNS -IncludeManagementTools

        $validInst = CheckWindowsFeature "DNS"
        if ($validInst) {
            Write-WColor Green "DNS Server instalado correctamente."  
            Write-Host ""
            #ConfigureDnsServer
        } else {
            Write-WColor Red "Error al instalar DNS Server."  
            Write-Host ""
            exit 1
        }


    } else {
        Write-WColor Yellow "DNS Server ya esta instalado."  
        Write-Host ""
    }


    ConfigureDhcpServer


}

Function Get-Valid-DnsNetworkConfig() {
    
    #$serverInt = Convert-IpToInt $ServerIp
    #$startInt  = Convert-IpToInt $StartRange
    #$endInt    = Convert-IpToInt $EndRange
    #$maskInt   = Convert-MaskToInt $SubnetMask

    #$networkInt   = $serverInt -band $maskInt
    #$broadcastInt = $networkInt -bor (-bnot $maskInt)


    #if ($startInt -gt $endInt) {
    #    Write-Host "[ERROR] El rango inicial es mayor que el rango final"
    #    return $false
    #}

    #foreach ($ip in @($serverInt, $startInt, $endInt)) {
    #    if (($ip -band $maskInt) -ne $networkInt) {
    #        Write-Host "[ERROR] Una IP no pertenece a la misma red"
    #        return $false
    #    }
    #}

    #if ($startInt -le $networkInt -or $endInt -ge $broadcastInt) {
    #    Write-Host "[ERROR] El rango incluye IP de red o broadcast"
    #    return $false
    #}

    Write-Host "[OK] La configuración de red DNS es válida"
    return $true
}



Function AdministrateDNSServer () {
    Write-WColor Green "Configurando DNS Server..."
    Write-Host ""
  
   Write-WColor Green "Servidor DNS configurado correctamente."
}


Function Get-DNSInstallation {
    Write-WColor Cyan "Verificando instalacion de DNS Server..."
    Write-Host ""

    if (CheckWindowsFeature "DNS") {
        Write-WColor Green "DNS Server esta instalado"
    } else {
        Write-WColor Red "DNS Server NO esta instalado"
    }
    Write-Host ""
}

Function Install-DnsDependencies {
    Write-WColor Cyan "Instalando DNS Server..."
    Write-Host ""

    if (-not (CheckWindowsFeature "DNS")) {
        Install-WindowsFeature DNS -IncludeManagementTools

        if (CheckWindowsFeature "DNS") {
            Write-WColor Green "DNS Server instalado correctamente"
        } else {
            Write-WColor Red "Error al instalar DNS Server"
            exit 1
        }
    } else {
        Write-WColor Yellow "DNS Server ya esta instalado"
    }

    Write-Host ""
}

Function Add-DnsDomain {
    Write-WColor Green "Agregando dominio al DNS Server..."
    Write-Host ""

    # TODO: Agregar dominio al DNS Server 

    Write-WColor Green "Dominio agregado correctamente."
}

Function Remove-DnsDomain {
    Write-WColor Green "Eliminando dominio del DNS Server..."
    Write-Host ""

    # TODO: Eliminar dominio del DNS Server 

    Write-WColor Green "Dominio eliminado correctamente."
}




Function Show-Help {
@"
Uso:
  practica3.ps1 [OPCION]

Opciones:
  --check        Verifica si el rol DNS Server esta instalado.
  --install      Instala el rol DNS Server y herramientas administrativas.
  --config       Configura el servidor DNS solicitando los datos de red.
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
    Write-Host "4) Agregar dominio"
    Write-Host "5) Eliminar dominio"
    Write-Host "6) Salir"
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
            4 { Add-DnsDomain }
            5 { Remove-DnsDomain }
            6 { Write-Host "Saliendo..."; exit 0 }
            default { Write-Host "Opcion invalida" }
        }
    }
}

Function Main($arguments) {
    switch ($arguments[0]) {
        "--check"   { Get-DnsInstallation }
        "--install" { Install-DnsDependencies }
        "--config"  { AdministrateDNSServer }
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