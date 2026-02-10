
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
        } else {
            Write-WColor Red "Error al instalar DHCP Server."  
            Write-Host ""
            exit 1
        }


    } else {
        Write-WColor Yellow "DHCP Server ya esta instalado."  
        Write-Host ""
    }


    ConfigureDhcpServer


}

Function ConfigureDhcpServer () {
    Write-WColor Green "Configurando DHCP Server..."
    Write-Host ""

    $ipEstatica = PromptForValidIpAddress "Ingresa la direccion IP estatica para el servidor DHCP"
    $puertaEnlace = PromptForValidIpAddress "Ingresa la direccion IP del gateway para el servidor DHCP"

    $nombreScope = Read-Host "Ingresa el nombre del scope DHCP"
    $rangoInicial = PromptForValidIpAddress "Ingresa la direccion IP inicial para el rango DHCP"
    $rangoFinal = PromptForValidIpAddress "Ingresa la direccion IP final para el rango DHCP"
    $mascaraSubred = PromptForValidIpAddress "Ingresa la mascara de subred para el rango DHCP"

    if ((Get-NetIPAddress -InterfaceAlias "Ethernet 2" -ErrorAction SilentlyContinue) -eq "") {
        New-NetIPAddress -IPAddress $ipEstatica -InterfaceAlias "Ethernet 2" -DefaultGateway $puertaEnlace -AddressFamily IPv4 -PrefixLength (Get-PrefixLengthFromMask $mascaraSubred)
    } else {
		Get-NetIPAddress -InterfaceAlias "Ethernet 2" -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false
		New-NetIPAddress -IPAddress $ipEstatica -InterfaceAlias "Ethernet 2" -DefaultGateway $puertaEnlace -AddressFamily IPv4 -PrefixLength (Get-PrefixLengthFromMask $mascaraSubred)
    }


    #Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $ipEstatica
    
    #netsh dhcp add securitygroups
    Restart-Service dhcpserver
    #$nombre = hostname
    
    
    Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2
    
    #Set-DhcpServerv4DnsSetting -ComputerName "DHCP1.corp.contoso.com" -DynamicUpdates "Always" -DeleteDnsRRonLeaseExpiry $True

    if (-not (Get-DhcpServerv4Scope -ErrorAction SilentlyContinue)) {
        Add-DhcpServerv4Scope -name $nombreScope -StartRange $rangoInicial -EndRange $rangoFinal -SubnetMask $mascaraSubred -State Active
    } else { 
    	$scopeIdToDelete = (Get-DhcpServerv4Scope).ScopeId
		Remove-DhcpServerv4Scope -ScopeId $scopeIdToDelete -Confirm:$false -Force
        Add-DhcpServerv4Scope -name $nombreScope -StartRange $rangoInicial -EndRange $rangoFinal -SubnetMask $mascaraSubred -State Active
    }

    #$scopeId = (Get-DhcpServerv4Scope).ScopeId
    
    #Set-DhcpServerv4OptionValue -OptionID 3 -Value $puertaEnlace -ScopeID $scopeId -ComputerName $env:COMPUTERNAME
    #Add-DhcpServerv4ExclusionRange -ScopeID 10.0.0.0 -StartRange 10.0.0.1 -EndRange 10.0.0.15
    #Set-DhcpServerv4OptionValue -OptionID 3 -Value 10.0.0.1 -ScopeID 10.0.0.0 -ComputerName DHCP1.corp.contoso.com
    #Set-DhcpServerv4OptionValue -DnsDomain corp.contoso.com -DnsServer 10.0.0.2
}

Function Get-DhcpInstallation {
    Write-WColor Cyan "Verificando instalacion de DHCP Server..."
    Write-Host ""

    if (CheckWindowsFeature "DHCP") {
        Write-WColor Green "DHCP Server esta instalado"
    } else {
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
        } else {
            Write-WColor Red "Error al instalar DHCP Server"
            exit 1
        }
    } else {
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
        Get-DhcpServerv4Lease | Format-Table -AutoSize
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
        "--check"   { Get-DhcpInstallation }
        "--install" { Install-DhcpDependencies }
        "--config"  { ConfigureDhcpServer }
        "--monitor" { Get-Monitor-Dhcp }
        "--help"    { Show-Help }
        $null       { Show-Interactive-Menu }
        default {
            Write-Host "Opcion no valida. Usa --help para ver las opciones disponibles."
            exit 1
        }
    }
}

Main $args