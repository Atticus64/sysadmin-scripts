
. "$PSScriptRoot\..\functions_windows.ps1"

Function Get-StatusCmd($cmd) {

    Try {
        Invoke-Expression $cmd -OutVariable output 
        return 0
    } catch {
        exit 1
    }                                  
}


Function InstallCowsay {

    if (Get-StatusCmd "Get-Command cowsay") {
        Write-WColor Yellow "Cowsay ya esta instalado"
    } else {
        Write-WColor Yellow "Cowsay no esta instalado"

        Invoke-WebRequest "https://raw.githubusercontent.com/kanej/Posh-Cowsay/refs/heads/master/cowsay.psm1" -OutFile "cowsay.psm1"
    
        Import-Module .\cowsay.psm1 -Force
    }


    Write-WColor Green "Cowsay instalado correctamente."

    cowsay "El servidor esta andando"
}


