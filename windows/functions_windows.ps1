
Function Write-WColor ($color, $text) {
    Write-Host -ForegroundColor $color $text -NoNewLine
}

Function GetIpAddress($index) {
    $ip = (Get-NetIPAddress -InterfaceIndex $index -AddressFamily Ipv4).IPAddress
    return $ip
}

Function CheckWindowsFeature($name) {
    $feature = Get-WindowsFeature -Name $name
    return $feature.Installed
}

Function ValidIpAddress($ip) {
    $ipv4Regex = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
    $isValid = $ip -match $ipv4Regex

    return $isValid 
} 

Function PromptForValidIpAddress($msg = "Ingresa una direccion IP para validar") {
    $inputIp = Read-Host $msg
    $validation = ValidIpAddress $inputIp
    
    while (-not $validation) {
        Write-Host "Direccion IP invalida. Por favor ingresa una direccion IP valida."
        $inputIp = Read-Host $msg
        $validation = ValidIpAddress $inputIp
    }                       

    return $inputIp
}    

