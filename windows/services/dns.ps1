
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

    $NombreDominio = Read-Host "Ingrese el nombre del dominio a agregar (ejemplo: reprobados.com)"

    while (-not (ValidDomain $NombreDominio)) {
        Write-WColor Red "Nombre de dominio no valido. Asegurate de ingresar un nombre de dominio correcto."
        $NombreDominio = Read-Host "Ingrese el nombre del dominio a agregar (ejemplo: reprobados.com)"  
    }

    while ($true) {
        $inputIp = Read-Host "Ingrese la Ip para el domino:"
    
        if (-not $inputIp) {
            $IpAddr = (Get-NetIPAddress -AddressFamily Ipv4 -InterfaceAlias "Ethernet 2").IPAddress
            break
        } else {
            if (ValidIpAddress $inputIp) {
                $IpAddr = $inputIp
                break
            } else {
                Write-WColor Red "Direccion IP invalida"
                Write-Host "Asegurate de ingresar una direccion IP valida o deja el campo vacio"
            }
        }

    }


    if (-not (ValidIpAddress $IpAddr)) {
        Write-WColor Red "No se pudo obtener la Ip fija"
        Write-Host "Asegurate de tener una IP fija configurada en la interfaz de red y vuelve a intentarlo!" 
        exit 1       
    }
    Write-Host "[OK] " -NoNewline
    Write-WColor Blue "Agregando dominio A y CNAME para $NombreDominio con IP $IpAddr"
    write-Host ""
    
    Add-DnsServerPrimaryZone -Name $NombreDominio -zonefile "$NombreDominio.dns"
    Add-DnsServerResourceRecordA -Name "@" -ZoneName $NombreDominio -Ipv4Address $IpAddr
    Add-DnsServerResourceRecordCName -Name "www" -ZoneName $NombreDominio -HostNameAlias "$NombreDominio"

    Restart-NetAdapter -Name "Ethernet 2"
    Write-WColor Green "Dominio agregado correctamente."
}


Function Get-DnsDomains {
    Write-WColor Green "Obteniendo dominios del DNS Server"
    write-Host ""
    $zones = Get-DnsServerZone | Where-Object IsAutoCreated -ne $true

    foreach ($zone in $zones) {
        $recordA = Get-DnsServerResourceRecord -ZoneName $zone.ZoneName -RRType "A" | Where-Object { $_.HostName -eq "@" }
        $recordCName = Get-DnsServerResourceRecord -ZoneName $zone.ZoneName -RRType "CNAME"
        Write-Host "Zona: $($zone.ZoneName)"    
        if ($recordA) {
            Write-Host "Registro A: $($recordA.RecordData.IPv4Address)"
        }
        if ($recordCName) {
            foreach ($cname in $recordCName) {
                Write-Host "Registro CNAME: $($cname.HostName) -> $($cname.RecordData.HostNameAlias)"
            }
        }
        Write-Host ""
    }   

}

Function Remove-DnsDomain {
    Write-WColor Green "Eliminando dominio del DNS Server..."
    Write-Host ""


    if (-not (Get-DnsServerZone -ErrorAction SilentlyContinue)) {
        Write-WColor Red "No hay dominios configurados en el DNS Server."
        return
    }

    $NombreDominio = Read-Host "Ingrese el nombre del dominio a eliminar (ejemplo: reprobados.com)"

    while (-not (ValidDomain $NombreDominio)) {
        Write-WColor Red "Nombre de dominio no valido. Asegurate de ingresar un nombre de dominio correcto."
        $NombreDominio = Read-Host "Ingrese el nombre del dominio a eliminar (ejemplo: reprobados.com)"  
    }

    if (-not (Get-DnsServerZone -Name $NombreDominio -ErrorAction SilentlyContinue)) {
        Write-WColor Red "El dominio" 
        Write-Host "$NombreDominio" -NoNewline 
        Write-WColor Red " no existe en el DNS Server."
        return
    } 

    Remove-DnsServerZone -Name $NombreDominio -Force
    Restart-NetAdapter -Name "Ethernet 2"

    Write-WColor Green "Dominio eliminado correctamente."
}

