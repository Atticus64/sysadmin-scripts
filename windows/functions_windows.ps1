
Function Write-WColor ($color, $text) {
    Write-Host -ForegroundColor $color $text -NoNewLine
}

Function Convert-IpToInt($Ip) {

    $bytes = $Ip.Split('.') | ForEach-Object { [int]$_ }
    return ($bytes[0] -shl 24) -bor
           ($bytes[1] -shl 16) -bor
           ($bytes[2] -shl 8)  -bor
           $bytes[3]
}

function Get-NetworkAddress($Ip, $Mask) {

    $ipInt   = Convert-IPToInt $Ip
    $maskInt = Convert-IPToInt $Mask

    $networkInt = $ipInt -band $maskInt
    return Convert-IntToIP $networkInt
}

Function Test-SubnetMask($mask) {
    if (-not ([System.Net.IPAddress]::TryParse($mask, [ref]([System.Net.IPAddress]$null)))) {
        return $false
    }

    $bytes = $mask.Split('.') | ForEach-Object {
        [Convert]::ToString($_, 2).PadLeft(8, '0')
    }

    $binary = $bytes -join ''
    return ($binary -match '^1+0+$')
}

Function Convert-IntToIP($int) {
    return "$(($int -shr 24) -band 255)." +
    "$(($int -shr 16) -band 255)." +
    "$(($int -shr 8) -band 255)." +
    "$($int -band 255)"
}
 

Function Convert-MaskToInt($Mask) {

    return Convert-IpToInt $Mask
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

