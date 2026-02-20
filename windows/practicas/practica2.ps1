
# Practica DHCP Server
. "$PSScriptRoot\..\functions_windows.ps1"

Function InstallDhcpServer() {

    if (-not (CheckWindowsFeature "DHCP")) {
        Write-WColor Green "Instalando DHCP Server..."
        Write-Host ""
        Install-WindowsFeature DHCP -IncludeManagementTools

        $validInst = CheckWindowsFeature "DHCP"
        if ($validInst) {
            Write-WColor Green "DHCP Server instalado correctamente."  
            Write-Host ""
            #ConfigureDhcpServer
        }
        else {
            Write-WColor Red "Error al instalar DHCP Server."  
            Write-Host ""
            exit 1
        }


    }
    else {
        Write-WColor Yellow "DHCP Server ya esta instalado."  
        Write-Host ""
    }


    ConfigureDhcpServer


}

Function Get-Valid-DhcpNetworkConfig($ServerIp, $StartRange, $EndRange, $SubnetMask) {
    
    $serverInt = Convert-IpToInt $ServerIp
    $startInt = Convert-IpToInt $StartRange
    $endInt = Convert-IpToInt $EndRange
    $maskInt = Convert-MaskToInt $SubnetMask

    $networkInt = $serverInt -band $maskInt
    $broadcastInt = $networkInt -bor (-bnot $maskInt)


    if ($startInt -gt $endInt) {
        Write-Host "[ERROR] El rango inicial es mayor que el rango final"
        return $false
    }

    foreach ($ip in @($serverInt, $startInt, $endInt)) {
        if (($ip -band $maskInt) -ne $networkInt) {
            Write-Host "[ERROR] Una IP no pertenece a la misma red"
            return $false
        }
    }

    if ($startInt -le $networkInt -or $endInt -ge $broadcastInt) {
        Write-Host "[ERROR] El rango incluye IP de red o broadcast"
        return $false
    }

    Write-Host "[OK] La configuración de red DHCP es válida"
    return $true
}


Function PromptForDnsServers {
    while ($true) {
        $dnsInput = Read-Host "Ingresa los DNS servers (separados por coma)"
        if (! $dnsInput) {
            break
        }
        $dnsServers = $dnsInput -split "," | ForEach-Object { $_.Trim() }

        $valid = $true
        foreach ($dns in $dnsServers) {
            if (-not (Test-Connection -ComputerName $dns -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
                Write-Host "[ERROR] DNS inválido: $dns"
                $valid = $false
                break
            }
        }

        if ($valid -and $dnsServers.Count -gt 0) {
            return $dnsServers
        }
    }
}

Function PromptForLeaseTime {

    while ($true) {

        $leaseSeconds = Read-Host "Ingresa el tiempo de concesión (en segundos, ej. 86400)"

        if ($leaseSeconds -match '^\d+$' -and [int64]$leaseSeconds -gt 0) {

            return New-TimeSpan -Seconds $leaseSeconds
        }

        Write-Host "[ERROR] Ingresa un número válido mayor que 0"
    }
}


Function ConfigureDhcpServer () {
    Write-WColor Green "Configurando DHCP Server..."
    Write-Host ""

    $validInputs = $false   

    $nombreScope = Read-Host "Ingresa el nombre del scope DHCP"

    while (-not $validInputs) {
        $rangoInicial = PromptForValidIpAddress "Ingresa la direccion IP inicial del rango DHCP"
        $rangoFinal = PromptForValidIpAddress "Ingresa la direccion IP final del rango DHCP"
    
        do {
            $mascaraSubred = Read-Host "Ingresa la mascara de subred"
            if (-not (Test-SubnetMask $mascaraSubred)) {
                Write-WColor Red "Mascara invalida."
            }
        } until (Test-SubnetMask $mascaraSubred)

        $validInputs = Get-Valid-DhcpNetworkConfig -ServerIp $rangoInicial -StartRange $rangoInicial -EndRange $rangoFinal -SubnetMask $mascaraSubred

        $networkInicial = Get-NetworkAddress -Ip $rangoInicial -Mask $mascaraSubred
        $networkFinal = Get-NetworkAddress -Ip $rangoFinal -Mask $mascaraSubred

        while ($networkInicial -ne $networkFinal) {
            Write-WColor Red "Las IPs del rango no pertenecen al mismo segmento de red."
            $rangoFinal = PromptForValidIpAddress "Ingresa la direccion IP final del rango DHCP"
            $networkFinal = Get-NetworkAddress -Ip $rangoFinal -Mask $mascaraSubred
        }
        
        $intInicial = Convert-IPToInt $rangoInicial
        $intFinal = Convert-IPToInt $rangoFinal

        if (($intFinal - $intInicial) -lt 2) {
            Write-WColor Red "El rango debe tener minimo 2 IPs de diferencia."
            continue
        }
    
        $prefixLength = (Get-PrefixLengthFromMask $mascaraSubred)

        $validInputs = $true
    }   

    $ipEstatica = $rangoInicial
    $nuevoInicioPool = Convert-IntToIP ($intInicial + 1)


    $puertaEnlace = Read-Host "Ingresa la direccion IP del gateway [opcional]"
    if ($puertaEnlace) {
        while (-not ([System.Net.IPAddress]::TryParse($puertaEnlace, [ref]([System.Net.IPAddress]$null)))) {
            Write-WColor Red "Gateway invalido."
            $puertaEnlace = Read-Host "Ingresa la direccion IP del gateway [opcional]"
            if (-not $puertaEnlace) { break }
        }
    }

    $interface = "Ethernet 2"

    Set-NetIPInterface -InterfaceAlias $interface -Dhcp Disabled
    Get-NetIPAddress -InterfaceAlias $interface -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false
    Get-NetRoute -InterfaceAlias $interface -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false

    if (-not $puertaEnlace) {
        New-NetIPAddress `
        -InterfaceAlias $interface `
        -IPAddress $ipEstatica `
        -PrefixLength $prefixLength 
    }
    else {
        New-NetIPAddress `
            -InterfaceAlias $interface `
            -IPAddress $ipEstatica `
            -PrefixLength $prefixLength `
            -DefaultGateway $puertaEnlace
    }


    $dnsServers = PromptForDnsServers


    $leaseTime = PromptForLeaseTime


    Restart-Service dhcpserver

    if (Get-DhcpServerv4Scope -ErrorAction SilentlyContinue) {
        $scopeIdToDelete = (Get-DhcpServerv4Scope).ScopeId
        Remove-DhcpServerv4Scope -ScopeId $scopeIdToDelete -Confirm:$false -Force
    }


    Add-DhcpServerv4Scope -Name $nombreScope -StartRange $nuevoInicioPool -EndRange $rangoFinal -SubnetMask $mascaraSubred -State Active

    $scopeId = (Get-DhcpServerv4Scope).ScopeId

    if ($dnsServers) {
        if (-not (CheckWindowsFeature "DNS")) {
            Write-WColor Yellow "DNS Server no esta instalado."
            Install-WindowsFeature DNS -IncludeManagementTools -Confirm
        } 

        Set-DhcpServerv4OptionValue -ScopeId $scopeId -DnsServer $dnsServers
        Set-DnsClientServerAddress -InterfaceAlias $interface -ServerAddresses $dnsServers
    }

    if ($puertaEnlace) {
        Set-DhcpServerv4OptionValue -ScopeId $scopeId -Router $puertaEnlace
    }

    Set-DhcpServerv4Scope -ScopeId $scopeId -LeaseDuration $leaseTime

    Write-WColor Green "Servidor DHCP configurado correctamente."
}


Function Get-DhcpInstallation {
    Write-WColor Cyan "Verificando instalacion de DHCP Server..."
    Write-Host ""

    if (CheckWindowsFeature "DHCP") {
        Write-WColor Green "DHCP Server esta instalado"
    }
    else {
        Write-WColor Red "DHCP Server NO esta instalado"
    }
    Write-Host ""
}

Function Install-DhcpDependencies {
    Write-WColor Cyan "Instalando DHCP Server..."
    Write-Host ""

    if (-not (CheckWindowsFeature "DHCP")) {
        Install-WindowsFeature DHCP -IncludeManagementTools

        if (CheckWindowsFeature "DHCP") {
            Write-WColor Green "DHCP Server instalado correctamente"
        }
        else {
            Write-WColor Red "Error al instalar DHCP Server"
            exit 1
        }
    }
    else {
        Write-WColor Yellow "DHCP Server ya esta instalado"
    }

    Write-Host ""
}

Function Get-Monitor-Dhcp {
    Write-WColor Cyan "Monitoreando DHCP Server (Ctrl+C para salir)..."
    Write-Host ""

    $scopeId = (Get-DhcpServerv4Scope).ScopeId 

    Get-DhcpServerv4Lease -ScopeId $scopeId | Format-Table -AutoSize

    while ($true) {
        Start-Sleep -Seconds 5
        Clear-Host
        Write-WColor Cyan "Monitoreando DHCP Server (Ctrl+C para salir)..."
        Write-Host ""
        Get-DhcpServerv4Lease -ScopeId $scopeId | Format-Table -AutoSize
    }                                      

}

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