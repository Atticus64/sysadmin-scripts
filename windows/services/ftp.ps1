$script:ServiceName = "FTP Daemon IIS"
$script:FtpRootPath = "C:\FTP"
$script:LocalUserPath = "C:\FTP\LocalUser"
$script:PublicPath = "C:\FTP\LocalUser\Public"
$script:GeneralPath = "C:\FTP\LocalUser\Public\General"
$script:ReprobadosPath = "C:\FTP\Reprobados"
$script:RecursadoresPath = "C:\FTP\Recursadores"
$script:UserListPath = "C:\FTP\ftp_user_list.txt"
$global:ADSI = $null


# ─────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────

# FIX: Resuelve el nombre real del grupo local para icacls
# Evita "No mapping between account names and security IDs"
Function Get-LocalGroupName {
    param([string]$Name)
    try {
        $g = Get-LocalGroup -Name $Name -ErrorAction Stop
        return $g.Name
    } catch {
        return $Name
    }
}

# FIX: Crea symlink con fallback a cmd /c mklink si New-Item falla
Function New-SymbolicLink {
    param(
        [string]$Path,
        [string]$Target,
        [switch]$Directory
    )

    # Eliminar si ya existe (archivo, carpeta o link)
    if (Test-Path $Path) {
        $item = Get-Item $Path -Force -ErrorAction SilentlyContinue
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            cmd /c rmdir """$Path""" 2>$null
        } else {
            Remove-Item $Path -Force -Recurse -ErrorAction SilentlyContinue
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Path -Target $Target -ErrorAction Stop | Out-Null
    } catch {
        # FIX: Fallback a mklink cuando New-Item lanza IOException o Win32Exception
        Write-Host "  [Warn] New-Item falló, usando mklink como fallback..."
        if ($Directory) {
            cmd /c mklink /D """$Path""" """$Target""" | Out-Null
        } else {
            cmd /c mklink """$Path""" """$Target""" | Out-Null
        }

        if ($LASTEXITCODE -ne 0) {
            throw "mklink también falló para '$Path' -> '$Target'"
        }
    }
}


# ─────────────────────────────────────────────
#  INSTALACION
# ─────────────────────────────────────────────

Function Install-FtpDaemon {
    Write-Host "Instalando dependencias de FTP..."

    $features = @("Web-Server", "Web-FTP-Service", "Web-FTP-Server", "Web-Basic-Auth")
    foreach ($f in $features) {
        $installed = Get-WindowsFeature -Name $f
        if (-not $installed.Installed) {
            Install-WindowsFeature $f -IncludeAllSubFeature | Out-Null
            Write-Host "[OK] $f instalado."
        } else {
            Write-Host "[OK] $f ya estaba instalado."
        }
    }

    Import-Module WebAdministration -ErrorAction SilentlyContinue

    # Regla de firewall
    if (-not (Get-NetFirewallRule -DisplayName "FTP" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "FTP" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow | Out-Null
        Write-Host "[OK] Regla de firewall FTP creada."
    } else {
        Write-Host "[OK] Regla de firewall FTP ya existe."
    }

    # Estructura de carpetas
    $dirs = @($script:FtpRootPath, $script:LocalUserPath, $script:PublicPath, $script:GeneralPath, $script:ReprobadosPath, $script:RecursadoresPath)
    foreach ($d in $dirs) {
        if (-not (Test-Path $d)) {
            New-Item -ItemType Directory -Path $d | Out-Null
            Write-Host "[OK] Directorio creado: $d"
        }
    }

    # FIX: Usar nombre SID-safe "Administrators" en lugar de "Administradores"
    # para evitar "No mapping between account names and security IDs"
    $adminGroup = (New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")).Translate([System.Security.Principal.NTAccount]).Value

    # Permisos en Public
    icacls $script:LocalUserPath /inheritance:r
    icacls $script:LocalUserPath /grant "Users:(RX)"
    icacls $script:FtpRootPath /grant "Users:(RX)"

    #icacls $script:PublicPath /inheritance:r | Out-Null
    #icacls $script:PublicPath /remove "BUILTIN\Usuarios" 2>$null | Out-Null
    icacls $script:PublicPath /grant "IUSR:(OI)(CI)RX"           | Out-Null
    icacls $script:PublicPath /grant "SYSTEM:(OI)(CI)F"           | Out-Null
    icacls $script:PublicPath /grant "${adminGroup}:(OI)(CI)F"    | Out-Null

    # Permisos en General (anonimo solo lectura)
    icacls $script:GeneralPath /grant "IUSR:(OI)(CI)RX" | Out-Null

    # Crear sitio FTP si no existe
    if (-not (Get-WebSite -Name "FTP" -ErrorAction SilentlyContinue)) {
        New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath $script:FtpRootPath | Out-Null
        Write-Host "[OK] Sitio FTP creado."
    } else {
        Write-Host "[OK] Sitio FTP ya existe."
    }

    # Autenticacion
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.authentication.basicAuthentication.enabled  -Value $true
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.authentication.anonymousAuthentication.username -Value "IUSR"

    # Aislamiento de usuarios
    Set-WebConfigurationProperty `
        -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/userIsolation" `
        -Name "mode" -Value "IsolateAllDirectories"

    # SSL desactivado (lab)
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.dataChannelPolicy    -Value 0

    # Reglas de autorizacion
    Clear-WebConfiguration -Filter "/system.ftpServer/security/authorization" -PSPath IIS:\ -Location "FTP"
    Add-WebConfiguration "/system.ftpServer/security/authorization" `
        -Value @{accessType="Allow"; users="?"; permissions=1} `
        -PSPath IIS:\ -Location "FTP"
    Add-WebConfiguration "/system.ftpServer/security/authorization" `
        -Value @{accessType="Allow"; users="*"; permissions=3} `
        -PSPath IIS:\ -Location "FTP"

    # Inicializar lista de usuarios
    if (-not (Test-Path $script:UserListPath)) {
        New-Item -ItemType File -Path $script:UserListPath | Out-Null
    }

    Restart-WebItem "IIS:\Sites\FTP"
    Write-Host ""
    Write-Host "[OK] Servidor FTP listo."
}


# ─────────────────────────────────────────────
#  VERIFICACION
# ─────────────────────────────────────────────

Function Get-FtpInstallation {
    Write-Host "Verificando instalacion de FTP Server..."

    $feature = Get-WindowsFeature -Name "Web-FTP-Service"
    if ($feature.Installed) {
        Write-Host "[OK] $script:ServiceName esta instalado."
    } else {
        Write-Host "[Error] $script:ServiceName NO esta instalado."
    }

    Get-FtpConfiguration
}

Function Get-FtpConfiguration {
    Write-Host ""
    Write-Host "Verificando configuracion del $script:ServiceName..."

    $site = Get-WebSite -Name "FTP" -ErrorAction SilentlyContinue
    if ($site) {
        Write-Host "[OK] Sitio FTP existe. Estado: $($site.State)"
    } else {
        Write-Host "[Error] Sitio FTP NO existe."
    }

    $reglaPassive = "FTP Passive Ports"

    $existeFTPPassive = Get-NetFirewallRule -DisplayName $reglaPassive -ErrorAction SilentlyContinue

    if (-not $existeFTPPassive) {
        New-NetFirewallRule -DisplayName "FTP Passive Ports" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort 50000-50100 `
            -Action Allow
    }


    $reglaControl = "FTP Control Port"

    $existeFTPControl = Get-NetFirewallRule -DisplayName $reglaControl -ErrorAction SilentlyContinue

    if (-not $existeFTPControl) {
        New-NetFirewallRule `
            -DisplayName "FTP Control Port" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort 21 `
            -Action Allow

    }

    

    foreach ($path in @($script:GeneralPath, $script:ReprobadosPath, $script:RecursadoresPath)) {
        if (Test-Path $path) {
            Write-Host "[OK] Directorio existe: $path"
        } else {
            Write-Host "[Error] Directorio faltante: $path"
        }
    }

    Restart-Service ftpsvc
}


# ─────────────────────────────────────────────
#  GRUPOS
# ─────────────────────────────────────────────

Function Initialize-FtpGroups {
    Write-Host "Configurando grupos FTP..."

    $global:ADSI = [ADSI]"WinNT://$env:ComputerName"

    $groups = @{
        "Reprobados"   = @{ Desc = "Grupo de reprobados";   Path = $script:ReprobadosPath }
        "Recursadores" = @{ Desc = "Grupo de recursadores"; Path = $script:RecursadoresPath }
    }

    foreach ($gName in $groups.Keys) {
        $gInfo = $groups[$gName]
        $exists = $global:ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq $gName }
        if (-not $exists) {
            $grp = $global:ADSI.Create("Group", $gName)
            $grp.SetInfo()
            $grp.Description = $gInfo.Desc
            $grp.SetInfo()
            Write-Host "[OK] Grupo '$gName' creado."
        } else {
            Write-Host "[OK] Grupo '$gName' ya existe."
        }

        if (-not (Test-Path $gInfo.Path)) {
            New-Item -ItemType Directory -Path $gInfo.Path | Out-Null
        }

        # FIX: Resolver nombre real del grupo antes de pasarlo a icacls
        $resolvedGroup = Get-LocalGroupName $gName
        icacls $gInfo.Path /grant "${resolvedGroup}:(OI)(CI)M" | Out-Null
    }

    $reprobados   = Get-LocalGroupName "Reprobados"
    $recursadores = Get-LocalGroupName "Recursadores"
    icacls $script:GeneralPath /grant "${reprobados}:(OI)(CI)M"   | Out-Null
    icacls $script:GeneralPath /grant "${recursadores}:(OI)(CI)M" | Out-Null
    icacls $script:GeneralPath /grant "IUSR:(OI)(CI)RX"           | Out-Null
}


# ─────────────────────────────────────────────
#  CREAR USUARIO
# ─────────────────────────────────────────────

Function New-FtpUser {
    param(
        [string]$Username,
        [string]$Password,
        [string]$Group
    )

    if ($null -eq $global:ADSI) {
        $global:ADSI = [ADSI]"WinNT://$env:ComputerName"
    }

    # Validar que la contraseña no contenga el nombre de usuario (política Windows)
    if ($Password -match [regex]::Escape($Username)) {
        Write-Host "[Error] La contraseña no puede contener el nombre de usuario '$Username'."
        return
    }

    # FIX: Crear usuario y asignar password correctamente
    try {
        $user = $global:ADSI.Create("User", $Username)
        $user.SetInfo()                  # Persistir objeto base primero
        $user.SetPassword($Password)     # Asignar contraseña

        # FIX: psbase.InvokeSet garantiza escritura correcta de flags en todos los Windows Server
        # 0x200   = UF_NORMAL_ACCOUNT
        # 0x10000 = UF_DONT_EXPIRE_PASSWD
        $user.psbase.InvokeSet("UserFlags", 0x10200)
        $user.SetInfo()
        Write-Host "[OK] Usuario '$Username' creado."
    } catch {
        Write-Host "[Error] No se pudo crear usuario '$Username': $($_.Exception.Message)"
        return
    }

    # FIX: Forzar PasswordNeverExpires via cmdlet como respaldo por si ADSI no propagó el flag
    try {
        Set-LocalUser -Name $Username -PasswordNeverExpires $true -ErrorAction Stop
        Write-Host "[OK] PasswordNeverExpires confirmado."
    } catch {
        Write-Host "[Warn] No se pudo confirmar PasswordNeverExpires: $($_.Exception.Message)"
    }

    $adminGroup = (New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")).Translate([System.Security.Principal.NTAccount]).Value

    # FIX: Tomar ownership de LocalUserPath para garantizar que
    # el proceso Admin pueda crear subdirectorios y symlinks
    takeown /F $script:LocalUserPath /R /D Y 2>$null | Out-Null
    # FIX: Cortar herencia para que BUILTIN\Users no se propague a carpetas de usuarios
    icacls $script:LocalUserPath /inheritance:r                    | Out-Null
    icacls $script:LocalUserPath /remove "BUILTIN\Users"      /T   | Out-Null
    icacls $script:LocalUserPath /grant "${adminGroup}:(OI)(CI)F" /T | Out-Null
    icacls $script:LocalUserPath /grant "SYSTEM:(OI)(CI)F"         /T | Out-Null
    icacls $script:LocalUserPath /grant "IUSR:(OI)(CI)RX"          /T | Out-Null
    icacls $script:LocalUserPath /grant "IIS_IUSRS:(OI)(CI)RX"     /T | Out-Null
    Write-Host "[OK] Permisos asignados a LocalUserPath."

    # Carpeta raiz del usuario (chroot) — IIS FTP busca esta ruta como home directory
    # FIX: IsolateAllDirectories requiere C:\FTP\LocalUser\<username>\ accesible por IUSR e IIS_IUSRS
    $userRoot = "$script:LocalUserPath\$Username"
    if (-not (Test-Path $userRoot)) {
        New-Item -ItemType Directory -Path $userRoot | Out-Null
    }

    # Carpeta personal exclusiva
    $personalDir = "$userRoot\$Username"
    if (-not (Test-Path $personalDir)) {
        New-Item -ItemType Directory -Path $personalDir | Out-Null
    }

    # FIX: Permisos en userRoot — heredados desactivados, pero IUSR e IIS_IUSRS
    # necesitan RX para que IIS pueda verificar la carpeta al hacer login (530 fix)
    icacls $userRoot /inheritance:r                              | Out-Null
    icacls $userRoot /grant "SYSTEM:(OI)(CI)F"                  | Out-Null
    icacls $userRoot /grant "${adminGroup}:(OI)(CI)F"           | Out-Null
    icacls $userRoot /grant "IUSR:(OI)(CI)RX"                   | Out-Null
    icacls $userRoot /grant "IIS_IUSRS:(OI)(CI)RX"              | Out-Null
    icacls $userRoot /grant "${Username}:(OI)(CI)RX"            | Out-Null
    icacls $personalDir /grant "${Username}:(OI)(CI)M"          | Out-Null
    Write-Host "[OK] Permisos asignados al directorio home FTP: $userRoot"

    # FIX: Crear symlinks usando helper con fallback a mklink
    $generalLink = "$userRoot\General"
    New-SymbolicLink -Path $generalLink -Target $script:GeneralPath -Directory

    $groupTarget = "$script:FtpRootPath\$Group"
    $groupLink   = "$userRoot\$Group"
    New-SymbolicLink -Path $groupLink -Target $groupTarget -Directory

    # Agregar al grupo
    Add-LocalGroupMember -Group $Group -Member $Username -ErrorAction SilentlyContinue

    # Registrar en lista
    if (-not (Select-String -Path $script:UserListPath -Pattern "^$Username$" -Quiet -ErrorAction SilentlyContinue)) {
        Add-Content -Path $script:UserListPath -Value $Username
    }

    Write-Host "[OK] Usuario '$Username' creado en grupo '$Group'."
}


# ─────────────────────────────────────────────
#  AGREGAR USUARIOS (interactivo)
# ─────────────────────────────────────────────

Function Add-FtpUsers {
    Write-Host "Agregar usuarios FTP"

    if (-not (Get-WebSite -Name "FTP" -ErrorAction SilentlyContinue)) {
        Write-Host "El sitio FTP no existe. Ejecuta primero la instalacion."
        return
    }

    $n = Read-Host "Cuantos usuarios deseas crear?"
    if (-not ($n -match '^\d+$') -or [int]$n -le 0) {
        Write-Host "Numero invalido."
        return
    }

    # FIX: Regex alineado con política de Windows: May + min + número + mín 8 chars
    $regex = "^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9]).{8,}$"

    for ($i = 1; $i -le [int]$n; $i++) {
        Write-Host ""
        Write-Host "--- Usuario $i de $n ---"

        $username = Read-Host "Nombre de usuario"

        if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
            Write-Host "El usuario '$username' ya existe. Saltando..."
            continue
        }

        do {
            $pwd = Read-Host "Contrasena (Mayuscula, minuscula, numero, min 8 chars)"
            if ($pwd -notmatch $regex) {
                Write-Host "Contrasena no valida. Debe tener mayuscula, minuscula, numero y minimo 8 caracteres."
            } elseif ($pwd -match [regex]::Escape($username)) {
                Write-Host "Contrasena no valida. No puede contener el nombre de usuario."
                $pwd = ""  # forzar re-ingreso
            }
        } while ($pwd -notmatch $regex -or $pwd -match [regex]::Escape($username))

        Write-Host "Rol:"
        Write-Host "  1) Reprobado  (Reprobados)"
        Write-Host "  2) Recursador (Recursadores)"
        $rol = Read-Host "Opcion [1/2]"

        switch ($rol) {
            "1" { $group = "Reprobados" }
            "2" { $group = "Recursadores" }
            default {
                Write-Host "Opcion invalida. Saltando usuario '$username'."
                continue
            }
        }

        New-FtpUser -Username $username -Password $pwd -Group $group
    }

    Restart-WebItem "IIS:\Sites\FTP"
    Write-Host ""
    Write-Host "**********************"
    Write-Host "Usuarios registrados en FTP:"
    Get-Content $script:UserListPath
    Write-Host "**********************"
}


# ─────────────────────────────────────────────
#  CAMBIAR GRUPO (en caliente)
# ─────────────────────────────────────────────

Function Set-FtpUserGroup {
    Write-Host "Usuarios FTP:"
    if (Test-Path $script:UserListPath) { Get-Content $script:UserListPath }

    $username = Read-Host "Usuario a cambiar"

    if (-not (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
        Write-Host "El usuario '$username' no existe."
        return
    }

    $currentGroup = $null
    $newGroup     = $null

    if (Get-LocalGroupMember -Group "Reprobados" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$username" }) {
        $currentGroup = "Reprobados"
        $newGroup     = "Recursadores"
    } elseif (Get-LocalGroupMember -Group "Recursadores" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$username" }) {
        $currentGroup = "Recursadores"
        $newGroup     = "Reprobados"
    } else {
        Write-Host "El usuario no pertenece a ningun grupo FTP valido."
        return
    }

    Write-Host "Grupo actual: $currentGroup"
    $confirm = Read-Host "Cambiar a '$newGroup'? [s/N]"
    if ($confirm -ne "s" -and $confirm -ne "S") {
        Write-Host "Cancelado."
        return
    }

    Update-FtpUserGroup -Username $username -CurrentGroup $currentGroup -NewGroup $newGroup
    Restart-WebItem "IIS:\Sites\FTP"
    Write-Host "Cambio completado."
}

Function Update-FtpUserGroup {
    param(
        [string]$Username,
        [string]$CurrentGroup,
        [string]$NewGroup
    )

    $userRoot = "$script:LocalUserPath\$Username"

    Write-Host "Cambiando '$Username' de '$CurrentGroup' a '$NewGroup'..."

    Remove-LocalGroupMember -Group $CurrentGroup -Member $Username -ErrorAction SilentlyContinue
    Add-LocalGroupMember    -Group $NewGroup     -Member $Username -ErrorAction SilentlyContinue

    # Eliminar symlink del grupo anterior
    $oldLink = "$userRoot\$CurrentGroup"
    if (Test-Path $oldLink) {
        cmd /c rmdir """$oldLink""" 2>$null | Out-Null
        Write-Host "[OK] Enlace simbolico '$CurrentGroup' eliminado."
    }

    # FIX: Crear nuevo symlink usando helper con fallback
    $newLink   = "$userRoot\$NewGroup"
    $newTarget = "$script:FtpRootPath\$NewGroup"
    New-SymbolicLink -Path $newLink -Target $newTarget -Directory
    Write-Host "[OK] Enlace simbolico '$NewGroup' creado."

    $personalDir = "$userRoot\$Username"
    icacls $personalDir /grant "${Username}:(OI)(CI)M" | Out-Null

    Write-Host "[OK] '$Username' ahora pertenece a '$NewGroup'."
}


# ─────────────────────────────────────────────
#  LISTAR USUARIOS
# ─────────────────────────────────────────────

Function Get-FtpUsers {
    Write-Host "Usuarios en FTP:"
    Write-Host "**********************"

    if (-not (Test-Path $script:UserListPath)) {
        Write-Host "(sin usuarios registrados)"
        Write-Host "**********************"
        return
    }

    Get-Content $script:UserListPath | Where-Object { $_ -ne "" } | ForEach-Object {
        $u = $_
        $group = "sin grupo"
        try {
            if (Get-LocalGroupMember -Group "Reprobados" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$u" }) {
                $group = "Reprobados"
            } elseif (Get-LocalGroupMember -Group "Recursadores" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$u" }) {
                $group = "Recursadores"
            }
        } catch {}
        Write-Host "  usuario $u -> $group"
    }

    Write-Host "**********************"
}
