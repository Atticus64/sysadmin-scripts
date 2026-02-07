
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

CheckWindowsFeature "DHCP"