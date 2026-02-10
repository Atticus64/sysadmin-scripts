
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

function Get-PrefixLengthFromMask($SubnetMask) {

    # Convertir la mascara a numero de 32 bits
    $maskBytes = ($SubnetMask -split '\.') -as [byte[]]
    [uint32]$maskInt = ($maskBytes[0] -shl 24) + ($maskBytes[1] -shl 16) + ($maskBytes[2] -shl 8) + $maskBytes[3]

    $prefixLength = 0
    # iterar 32 veces, haciendo un shift a la derecha, sacando el bit menos significativo 
    for ($i = 0; $i -lt 32; $i++) {
        if (($maskInt -band 1) -eq 1) {
            $prefixLength++
        }
        $maskInt = $maskInt -shr 1
    }

    return $prefixLength
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

