. "$PSScriptRoot\..\functions_windows.ps1"

Function ImprimirInfo () {
	$IpActual = GetIpAddress 7
	$EspacioDisco = ((Get-Volume -DriveLetter C).Size / 1GB).ToString('F2')
	$EspacioLibre = ((Get-Volume -DriveLetter C).SizeRemaining / 1GB).ToString('F2')
    $NombreEquipo = hostname
    

	Write-WColor Red "Nombre Equipo    " 
	Write-WColor Blue "IP actual     "
	Write-WColor Yellow "Disco Total/Libre"
	Write-Host ""
	Write-Host  $NombreEquipo"," $IpActual"," $EspacioDisco"GB/"$EspacioLibre"GB"
}
