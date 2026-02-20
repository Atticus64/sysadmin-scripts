
Function Write-WColor ($color, $text) {
    Write-Host -ForegroundColor $color $text -NoNewLine
}

Function Convert-IpToInt($Ip) {

    Try {

        $num = [IPAddress]::HostToNetworkOrder([BitConverter]::ToInt32([IPAddress]::Parse($Ip).GetAddressBytes(), 0))
        return $num
    } Catch {
        return 0
    }

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

Function ValidInput($inputUser, $rule) {

    if ($inputUser -match $rule) {
        return $true
    } else {
        return $false
    }
}

Function ValidDomain($domainName) {
    return ValidInput $domainName "^((?!-)[A-Za-z0-9-]{1,63}(?<!-)\.)+[A-Za-z]{2,6}$"
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

function Get-PrefixLengthFromMask($mask) {

    $netMaskIP = [IPAddress]$mask
    $binaryString = [String]::Empty
    $netMaskIP.GetAddressBytes() | ForEach-Object {
        # Convert each byte to its binary string representation and append to $binaryString
        $binaryString += [Convert]::ToString($_, 2).PadLeft(8, '0')
    }

    # The prefix length is the count of leading '1' bits
    $prefixLength = $binaryString.TrimEnd('0').Length

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

