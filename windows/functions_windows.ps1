
Function Write-WColor ($color, $text) {
	Write-Host -ForegroundColor $color $text -NoNewLine
}

Function ImprimirInfo () {
	$IpActual = (Get-NetIPAddress -InterfaceIndex 7 -AddressFamily Ipv4).IPAddress 
	$EspacioDisco = ((Get-Volume -DriveLetter C).Size / 1GB).ToString('F2')
	$EspacioLibre = ((Get-Volume -DriveLetter C).SizeRemaining / 1GB).ToString('F2')
    $NombreEquipo = hostname
    

	Write-WColor Red "Nombre Equipo    " 
	Write-WColor Blue "IP actual     "
	Write-WColor Yellow "Disco Total/Libre"
	Write-Host ""
	Write-Host  $NombreEquipo"," $IpActual"," $EspacioDisco"GB/"$EspacioLibre"GB"
}

#ImprimirInfo