
. "$PSScriptRoot\practicas\practica1.ps1"

Write-Host "Checar estatus de Servidor"
Write-Host "--------------------------" 
Write-Host "1. Checar Servidor local"
Write-Host "2. Checar Servidor remoto"
Write-Host "3. Salir"

$opcion = Read-Host -Prompt "Ingresa una opcion (1-3)" 
while ($opcion -lt 1 -or $opcion -gt 3) {

    try {
        $opcion = [int]$opcion    
    }
    catch {
        Write-Host "Opcion invalida. Por favor ingresa un numero entre 1 y 3."
        $opcion = Read-Host -Prompt "Ingresa una opcion (1-3)" 
    }
}

switch ($opcion) {
    1 {
        Write-Host "Checando Servidor local..."
        ImprimirInfo
    } 
    2 {
        $remoteServer = Read-Host -Prompt "Ingresa el nombre o IP del servidor remoto"
        Write-Host "Checando Servidor remoto: $remoteServer ..."
        $user = Read-Host -Prompt "Ingresa el nombre de usuario"
        Write-Host $user
        #$password = Read-Host -Prompt "Ingresa la contrasena" -As
        #$securePassword = ConvertTo-SecureString $password -AsPlainText -Force

        #ssh "$user@$remoteServer" "-C" 
        $client = New-Object System.Net.Sockets.TcpClient($remoteServer, 22)
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)

        $banner = $reader.ReadLine()
        $client.Close()

        if ($banner -match "Windows") {
            Write-Host "Servidor remoto Windows"
            #ssh "$user@$remoteServer" "powershell -Command `"& { $(Get-Content '$PSScriptRoot\functions_windows.ps1' | Out-String); ImprimirInfo }`""
        } else {
            Write-Host "Servidor remoto Linux"
            #ssh "$user@$remoteServer" "bash -s" $(Get-Content "$PSScriptRoot\..\linux\functions_linux.sh"); imprimir_info"
        }
    } 
    3 {
        Write-Host "Saliendo del programa..."
        exit
    }
}

#ImprimirInfo
