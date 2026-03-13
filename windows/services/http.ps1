$script:ServiceNameIIS     = "W3SVC"
$script:ServiceNameApache  = "Apache2.4"
$script:ServiceNameNginx   = "nginx"

$script:ApacheChocoId      = "apache-httpd"
$script:NginxChocoId       = "nginx"

$script:IISFeatures = @(
    "Web-Server",
    "Web-WebServer",
    "Web-Common-Http",
    "Web-Default-Doc",
    "Web-Static-Content",
    "Web-Http-Errors",
    "Web-Http-Redirect",
    "Web-Http-Logging",
    "Web-Request-Monitor",
    "Web-Filtering",
    "Web-Performance",
    "Web-Stat-Compression",
    "Web-Mgmt-Tools",
    "Web-Mgmt-Console"
)


Function Test-Chocolatey {
    return ($null -ne (Get-Command choco -ErrorAction SilentlyContinue))
}

Function Test-ServiceExists {
    param([string]$Name)
    return ($null -ne (Get-Service -Name $Name -ErrorAction SilentlyContinue))
}


Function Get-ServiceStatus {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) { return $svc.Status } else { return "No instalado" }
}



Function Assert-Port {
    param([string]$PortInput)

    
    if ($PortInput -notmatch '^\d+$') {
        Write-Host "[Error] Puerto invalido: '$PortInput'. Debe ser un numero entre 1 y 65535."
        return $null
    }

    $port = [int]$PortInput

    if ($port -lt 1 -or $port -gt 65535) {
        Write-Host "[Error] Puerto fuera de rango: $port. Usa un valor entre 1 y 65535."
        return $null
    }

    
    $inUse = netstat -ano | Select-String ":$port " | Select-String "LISTENING"
    if ($inUse) {
        Write-Host "[Warn] El puerto $port ya esta en uso:"
        $inUse | ForEach-Object { Write-Host "       $_" }
        $confirm = Read-Host "Continuar de todas formas? [s/N]"
        if ($confirm -ne "s" -and $confirm -ne "S") {
            Write-Host "Cancelado."
            return $null
        }
    }

    return $port
}



Function Read-Port {
    param(
        [string]$ServiceName,
        [int]$Default = 80
    )

    Write-Host ""
    Write-Host "Configuracion de puerto para $ServiceName"
    Write-Host "  Puertos comunes: 80 (HTTP), 443 (HTTPS), 8080, 8443"

    do {
        $raw = Read-Host "Puerto a usar [Enter = $Default]"
        if ($raw -eq "") { $raw = "$Default" }
        $port = Assert-Port -PortInput $raw
    } while ($null -eq $port)

    return $port
}


Function Stop-AllHttpServices {
    $services = @($script:ServiceNameIIS, $script:ServiceNameApache, $script:ServiceNameNginx)
    foreach ($svc in $services) {
        if (Test-ServiceExists $svc) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s.Status -eq "Running") {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Write-Host "[OK] Servicio '$svc' detenido."
            }
        }
    }
}


Function Assert-Chocolatey {
    if (Test-Chocolatey) {
        Write-Host "[OK] Chocolatey ya esta instalado: $(choco --version)"
        return
    }

    Write-Host "Instalando Chocolatey..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = `
            [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString(
            'https://community.chocolatey.org/install.ps1'))

        
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path", "User")

        if (Test-Chocolatey) {
            Write-Host "[OK] Chocolatey instalado correctamente."
        } else {
            throw "choco no encontrado despues de la instalacion."
        }
    } catch {
        Write-Host "[Error] No se pudo instalar Chocolatey: $($_.Exception.Message)"
        exit 1
    }
}






Function Get-HttpInstallation {
    param([int]$Port = 0)   

    Write-Host ""
    Write-Host "Verificando instalacion de servicios HTTP..."
    Write-Host ""

    
    if (Test-Chocolatey) {
        Write-Host "[OK] Chocolatey:  $(choco --version)"
    } else {
        Write-Host "[--] Chocolatey:  No instalado"
    }

    
    $iisFeature = Get-WindowsFeature -Name "Web-Server" -ErrorAction SilentlyContinue
    if ($iisFeature -and $iisFeature.Installed) {
        $iisStatus = Get-ServiceStatus $script:ServiceNameIIS

        
        Import-Module WebAdministration -ErrorAction SilentlyContinue
        $iisSite    = Get-WebSite -Name "Default Web Site" -ErrorAction SilentlyContinue
        $iisBinding = if ($iisSite) { $iisSite.Bindings.Collection[0].bindingInformation } else { "?" }
        $iisPort    = if ($iisBinding -match ":(\d+):") { $Matches[1] } else { "?" }

        Write-Host "[OK] IIS (W3SVC): Instalado | Estado: $iisStatus | Puerto: $iisPort"
    } else {
        Write-Host "[--] IIS (W3SVC): No instalado"
    }

    
    if (Test-ServiceExists $script:ServiceNameApache) {
        $apacheStatus = Get-ServiceStatus $script:ServiceNameApache
        $apachePort   = Get-ServicePort -ServiceName $script:ServiceNameApache
        Write-Host "[OK] Apache:      Instalado | Estado: $apacheStatus | Puerto: $apachePort"
    } else {
        Write-Host "[--] Apache:      No instalado"
    }

    
    if (Test-ServiceExists $script:ServiceNameNginx) {
        $nginxStatus = Get-ServiceStatus $script:ServiceNameNginx
        $nginxPort   = Get-ServicePort -ServiceName $script:ServiceNameNginx
        Write-Host "[OK] Nginx:       Instalado | Estado: $nginxStatus | Puerto: $nginxPort"
    } else {
        Write-Host "[--] Nginx:       No instalado"
    }

    
    Write-Host ""
    $portsToCheck = if ($Port -gt 0) { @($Port) } else { @(80, 8080, 443, 8443) }
    foreach ($p in $portsToCheck) {
        $listening = netstat -ano | Select-String ":$p " | Select-String "LISTENING"
        if ($listening) {
            Write-Host "[Info] Puerto ${p}: EN USO"
            $listening | ForEach-Object { Write-Host "       $_" }
        } else {
            Write-Host "[Info] Puerto ${p}: Libre"
        }
    }
}


Function Get-ServicePort {
    param([string]$ServiceName)
    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $svc -or $svc.Status -ne "Running") { return "N/A" }

        $processID = (Get-WmiObject Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue).ProcessId
        if (-not $processID) { return "?" }

        $line = netstat -ano | Select-String "LISTENING" | Select-String "\s$processID$" | Select-Object -First 1
        if ($line -match ":(\d+)\s") { return $Matches[1] }
        return "?"
    } catch { return "?" }
}

Function Get-HttpConfiguration {
    param([int]$Port = 80)

    Write-Host ""
    Write-Host "Verificando configuracion de IIS (puerto $Port)..."

    $site = Get-WebSite -Name "Default Web Site" -ErrorAction SilentlyContinue
    if ($site) {
        Write-Host "[OK] Sitio IIS 'Default Web Site' existe. Estado: $($site.State)"
    } else {
        Write-Host "[--] Sitio IIS 'Default Web Site' no encontrado."
    }

    
    $ruleName = "HTTP-$Port"
    $fwRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($fwRule) {
        Write-Host "[OK] Regla de firewall '$ruleName' existe."
    } else {
        Write-Host "[--] Regla de firewall '$ruleName' no existe."
    }
}






Function Install-IISDaemon {
    param([int]$Port = 80)

    Write-Host ""
    Write-Host "Instalando IIS (Internet Information Services) en puerto $Port..."

    
    Stop-AllHttpServices

    foreach ($f in $script:IISFeatures) {
        $feat = Get-WindowsFeature -Name $f -ErrorAction SilentlyContinue
        if ($feat -and -not $feat.Installed) {
            Install-WindowsFeature $f -IncludeAllSubFeature | Out-Null
            Write-Host "[OK] $f instalado."
        } else {
            Write-Host "[OK] $f ya estaba instalado."
        }
    }

    Import-Module WebAdministration -ErrorAction SilentlyContinue

    
    $site = Get-WebSite -Name "Default Web Site" -ErrorAction SilentlyContinue
    if ($site) {
        
        Set-WebBinding -Name "Default Web Site" -BindingInformation "*:80:" `
            -PropertyName "bindingInformation" -Value "*:${Port}:" -ErrorAction SilentlyContinue

        
        $binding = Get-WebBinding -Name "Default Web Site" -ErrorAction SilentlyContinue
        if (-not ($binding | Where-Object { $_.bindingInformation -like "*:${Port}:*" })) {
            New-WebBinding -Name "Default Web Site" -Protocol "http" -Port $Port | Out-Null
        }
        Write-Host "[OK] Sitio IIS configurado en puerto $Port."
    }

    
    $ruleName = "HTTP-$Port"
    if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound `
            -Protocol TCP -LocalPort $Port -Action Allow | Out-Null
        Write-Host "[OK] Regla de firewall '$ruleName' (puerto $Port) creada."
    } else {
        Write-Host "[OK] Regla de firewall '$ruleName' ya existe."
    }

    if (-not (Get-NetFirewallRule -DisplayName "HTTPS" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "HTTPS" -Direction Inbound `
            -Protocol TCP -LocalPort 443 -Action Allow | Out-Null
        Write-Host "[OK] Regla de firewall HTTPS (443) creada."
    }

    
    Start-Service -Name $script:ServiceNameIIS -ErrorAction SilentlyContinue
    Write-Host ""
    Write-Host "[OK] IIS instalado y en ejecucion."
    Write-Host "     Acceder en: http://localhost:$Port"

    Get-HttpConfiguration -Port $Port
}

Function Uninstall-IISDaemon {
    Write-Host ""
    Write-Host "Desinstalando IIS..."

    Stop-Service -Name $script:ServiceNameIIS -Force -ErrorAction SilentlyContinue

    foreach ($f in ($script:IISFeatures | Sort-Object -Descending)) {
        $feat = Get-WindowsFeature -Name $f -ErrorAction SilentlyContinue
        if ($feat -and $feat.Installed) {
            Uninstall-WindowsFeature $f | Out-Null
            Write-Host "[OK] $f desinstalado."
        }
    }

    Write-Host "[OK] IIS desinstalado."
}

Function Reinstall-IISDaemon {
    param([int]$Port = 80)
    Write-Host "Reinstalando IIS en puerto $Port..."
    Uninstall-IISDaemon
    Install-IISDaemon -Port $Port
}








Function Get-ChocoVersionList {
    param([string]$ChocoId)

    Assert-Chocolatey

    $raw = choco search $ChocoId --all-versions --exact 2>&1

    
    
    $versions = $raw |
        Where-Object { $_ -match "^\S+\s+[\d\.]+" } |
        ForEach-Object {
            if ($_ -match "^\S+\s+([\d\.]+)") { $Matches[1] }
        } |
        Where-Object { $_ -ne $null -and $_ -ne "" } |
        Sort-Object { [version]$_ } -Descending

    return $versions
}


Function Get-HttpServiceVersions {
    param(
        [ValidateSet("apache", "nginx")]
        [string]$Service
    )

    $chocoId = if ($Service -eq "apache") { $script:ApacheChocoId } else { $script:NginxChocoId }

    Write-Host ""
    Write-Host "Consultando versiones disponibles de '$Service'..."
    Write-Host ""

    $versions = Get-ChocoVersionList -ChocoId $chocoId

    if (-not $versions -or $versions.Count -eq 0) {
        Write-Host "[Error] No se encontraron versiones para '$chocoId'."
        Write-Host "        Verifica tu conexion o el nombre del paquete en Chocolatey."
        return $null
    }

    $latest = $versions[0]
    $oldest = $versions[-1]

    
    
    if ($Service -eq "apache") {
        $minApache = [version]"2.4.33"
        $filtered  = $versions | Where-Object { [version]$_ -ge $minApache }

        if ($filtered.Count -lt $versions.Count) {
            $skipped = $versions.Count - $filtered.Count
            Write-Host "[Warn] Se omiten $skipped versiones anteriores a 2.4.33 (incompatibles con Chocolatey moderno)."
        }

        if ($filtered.Count -eq 0) {
            Write-Host "[Error] No hay versiones compatibles disponibles para Apache."
            return $null
        }

        $versions = $filtered
        $latest   = $versions[0]
        $oldest   = $versions[-1]
    }

    
    
    $lts = switch ($Service) {
        "apache" {
            
            $versions | Where-Object { $_ -like "2.4.*" } | Select-Object -First 1
        }
        "nginx" {
            
            $versions | Where-Object {
                $parts = $_.Split(".")
                $parts.Count -ge 2 -and ([int]$parts[1] % 2 -eq 0)
            } | Select-Object -First 1
        }
    }

    
    if (-not $lts) { $lts = $latest }

    Write-Host "Versiones disponibles ($($versions.Count) encontradas):"
    Write-Host "----------------------------------------------------"
    Write-Host "  [L] Latest  : $latest"
    Write-Host "  [S] Oldest  : $oldest"
    Write-Host "  [T] LTS     : $lts"
    Write-Host ""
    Write-Host "  Todas las versiones:"
    $versions | ForEach-Object { Write-Host "    - $_" }
    Write-Host "----------------------------------------------------"

    return [PSCustomObject]@{
        Latest   = $latest
        Oldest   = $oldest
        LTS      = $lts
        All      = $versions
    }
}






Function Install-HttpService {
    param(
        [ValidateSet("apache", "nginx")]
        [string]$Service,
        [string]$Version = "",  
        [int]$Port = 80
    )

    Assert-Chocolatey
    Stop-AllHttpServices

    $chocoId = if ($Service -eq "apache") { $script:ApacheChocoId } else { $script:NginxChocoId }
    $svcName = if ($Service -eq "apache") { $script:ServiceNameApache } else { $script:ServiceNameNginx }

    Write-Host ""
    if ($Version -ne "") {
        Write-Host "Instalando $Service version $Version en puerto $Port via Chocolatey..."
        choco install $chocoId --version=$Version -y --no-progress
    } else {
        Write-Host "Instalando $Service (ultima version) en puerto $Port via Chocolatey..."
        choco install $chocoId -y --no-progress
    }

    
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    
    if ($Service -eq "apache") {
        Set-ApachePort -Port $Port
    } elseif ($Service -eq "nginx") {
        Set-NginxPort -Port $Port

        
        
        if (Test-ServiceExists $script:ServiceNameNginx) {
            Restart-Service -Name $script:ServiceNameNginx -Force -ErrorAction SilentlyContinue
            Write-Host "[OK] Nginx reiniciado para aplicar nuevo puerto."
        } else {
            
            $nginxExe = Get-ChildItem -Path "C:\tools" -Filter "nginx.exe" -Recurse `
                            -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($nginxExe) {
                & $nginxExe.FullName -s stop 2>$null
                Start-Process $nginxExe.FullName -WorkingDirectory $nginxExe.DirectoryName
                Write-Host "[OK] Nginx reiniciado (proceso) para aplicar nuevo puerto."
            }
        }
    }

    
    $ruleName = "$Service-HTTP-$Port"
    if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound `
            -Protocol TCP -LocalPort $Port -Action Allow | Out-Null
        Write-Host "[OK] Regla de firewall '$ruleName' (puerto $Port) creada."
    } else {
        Write-Host "[OK] Regla de firewall '$ruleName' ya existe."
    }

    
    if (Test-ServiceExists $svcName) {
        Start-Service -Name $svcName -ErrorAction SilentlyContinue
        Write-Host "[OK] Servicio '$svcName' iniciado."
    } else {
        Write-Host "[Info] El servicio no se registro automaticamente como Windows Service."
        Write-Host "       Revisa la carpeta de instalacion para iniciar manualmente."
    }

    Write-Host ""
    Write-Host "[OK] $Service instalado correctamente."
    Write-Host "     Acceder en: http://localhost:$Port"
}


Function Set-ApachePort {
    param([int]$Port)

    $confPath = $null

    
    $staticCandidates = @(
        "C:\Apache24\conf\httpd.conf",
        "C:\tools\Apache24\conf\httpd.conf",
        "C:\tools\apache-httpd\conf\httpd.conf",
        "$env:ChocolateyInstall\lib\apache-httpd\tools\Apache24\conf\httpd.conf"
    )
    $confPath = $staticCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    
    if (-not $confPath) {
        $found = Get-ChildItem -Path "C:\tools" -Filter "httpd.conf" -Recurse `
                     -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $confPath = $found.FullName }
    }

    
    if (-not $confPath) {
        $found = Get-ChildItem -Path "$env:ChocolateyInstall\lib" -Filter "httpd.conf" `
                     -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $confPath = $found.FullName }
    }

    if (-not $confPath) {
        Write-Host "[Error] No se encontro httpd.conf tras busqueda recursiva."
        Write-Host "        Rutas buscadas: C:\tools, C:\Apache24, $env:ChocolateyInstall\lib"
        Write-Host "        Configura el puerto $Port manualmente en httpd.conf."
        return
    }

    Write-Host "[OK] Configurando Apache en: $confPath"

    
    
    $content = Get-Content $confPath -Raw
    $content = $content -replace '(?m)^(Listen\s+)[\d\.]*:?\d+', "`${1}0.0.0.0:$Port"
    $content | Set-Content $confPath -Encoding UTF8 -NoNewline
    Write-Host "[OK] Apache: escuchando en 0.0.0.0:$Port (todas las interfaces)."
}


Function Set-NginxPort {
    param([int]$Port)

    
    
    $confPath = $null

    
    $staticCandidates = @(
        "C:\tools\nginx\conf\nginx.conf",
        "C:\nginx\conf\nginx.conf",
        "$env:ChocolateyInstall\lib\nginx\tools\nginx\conf\nginx.conf"
    )
    $confPath = $staticCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    
    if (-not $confPath) {
        $found = Get-ChildItem -Path "C:\tools" -Filter "nginx.conf" -Recurse `
                     -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $confPath = $found.FullName }
    }

    
    if (-not $confPath) {
        $found = Get-ChildItem -Path "$env:ChocolateyInstall\lib" -Filter "nginx.conf" `
                     -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $confPath = $found.FullName }
    }

    if (-not $confPath) {
        Write-Host "[Error] No se encontro nginx.conf tras busqueda recursiva."
        Write-Host "        Rutas buscadas: C:\tools, C:\nginx, $env:ChocolateyInstall\lib"
        Write-Host "        Configura el puerto $Port manualmente en nginx.conf."
        return
    }

    Write-Host "[OK] Configurando Nginx en: $confPath"

    
    
    
    $content = Get-Content $confPath -Raw
    
    $content = $content -replace '(\blisten\s+)[\d\.]*:?\d+(;)', "`${1}0.0.0.0:$Port`$2"
    $content | Set-Content $confPath -Encoding UTF8 -NoNewline
    Write-Host "[OK] Nginx: escuchando en 0.0.0.0:$Port (todas las interfaces)."
}

Function Uninstall-HttpService {
    param(
        [ValidateSet("apache", "nginx")]
        [string]$Service
    )

    Assert-Chocolatey

    $chocoId = if ($Service -eq "apache") { $script:ApacheChocoId } else { $script:NginxChocoId }
    $svcName = if ($Service -eq "apache") { $script:ServiceNameApache } else { $script:ServiceNameNginx }

    Write-Host ""
    Write-Host "Desinstalando $Service..."

    if (Test-ServiceExists $svcName) {
        Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
    }

    choco uninstall $chocoId -y --no-progress
    Write-Host "[OK] $Service desinstalado."
}

Function Reinstall-HttpService {
    param(
        [ValidateSet("apache", "nginx")]
        [string]$Service,
        [string]$Version = "",
        [int]$Port = 80
    )

    Write-Host "Reinstalando $Service en puerto $Port..."
    Uninstall-HttpService -Service $Service
    Install-HttpService   -Service $Service -Version $Version -Port $Port
}