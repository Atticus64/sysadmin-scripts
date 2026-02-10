
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
        New-NetIPAddress -IPAddress $ipEstatica -InterfaceAlias "Ethernet 2" -DefaultGateway $puertaEnlace -AddressFamily IPv4 --prefixlength (Get-PrefixLengthFromMask $mascaraSubred)
    } else {
		Get-NetIPAddress -InterfaceAlias "Ethernet 2" -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false
		New-NetIPAddress -IPAddress $ipEstatica -InterfaceAlias "Ethernet 2" -DefaultGateway $puertaEnlace -AddressFamily IPv4 --prefixlength (Get-PrefixLengthFromMask $mascaraSubred)
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

InstallDhcpServer


