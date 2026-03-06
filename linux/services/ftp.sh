SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )
export package="vsftpd"
export service_name="FTP Daemon vsftpd"

source $SCRIPT_DIR/../functions_linux.sh

install_ftp_daemon() {

    install_required_package "net-tools"

    if ! check_package_present $package; then
        echo "No esta instalado"
        install_required_package $package
        if [[ $? -eq 0 ]]; then
            echo "Paquete para $service_name instalado correctamente"
        else 
            echo "Error al instalar el paquete para $service_name"
            exit 1
        fi
    else 
        echo "El paquete $service_name ya está instalado"
    fi
}


verificar_instalacion() {
    echo "Verificando instalación de FTP Server..."
    if check_package_present $package;then
        echo "[OK] $service_name está instalado"
    else
        echo "[Error] $service_name NO está instalado"
    fi

    verificar_setup_ftp
}

verificar_setup_ftp() {
    echo "Verificando configuración del $service_name..."

    enable_service $package $service_name
    enable_firewall_rule ftp $service_name

    filename="/etc/vsftpd/vsftpd.conf"

    sed -i.bak \
    -e 's/#ftpd_banner=.*/ftpd_banner=Bienvenido a tu servicio FTP linuxero/' \
    -e 's/#anonymous_enable=.*/anonymous_enable=YES/' \
    -e 's/anonymous_enable=.*/anonymous_enable=YES/' \
    -e 's/#chroot_local_user=.*/chroot_local_user=YES/' \
    $filename  
    
    add_to_file "/sbin/nologin" /etc/shells
    add_to_file "allow_writeable_chroot=YES" $filename
    add_to_file "no_anon_password=YES" $filename
    add_to_file "anon_root=/var/ftp" $filename
    add_to_file "anon_world_readable_only=YES" $filename
    add_to_file "userlist_enable=YES" $filename
    add_to_file "userlist_deny=NO" $filename
    add_to_file "local_enable=YES" $filename
    add_to_file "userlist_file=/etc/vsftpd/user_list" $filename

    add_to_file "anonymous" /etc/vsftpd/user_list

    configurar_grupos

    systemctl restart vsftpd
}


configurar_grupos() {

    echo "Configurando grupos FTP..."

    if ! getent group reprobados >/dev/null; then
        sudo groupadd reprobados
    fi

    if ! getent group recursadores >/dev/null; then
        sudo groupadd recursadores
    fi

    sudo mkdir -p /home/reprobados
    sudo mkdir -p /home/recursadores

    sudo chown root:reprobados /home/reprobados
    sudo chmod 775 /home/reprobados

    sudo chown root:recursadores /home/recursadores
    sudo chmod 775 /home/recursadores

    sudo chcon -R -t user_home_dir_t /home/reprobados
    sudo chcon -R -t user_home_dir_t /home/recursadores

    sudo chown -R ftp:ftp /var/ftp/pub
    sudo chmod 777 /var/ftp/pub
    sudo chmod -R 664 /var/ftp/pub/*

    sudo setsebool -P ftpd_full_access on

    sudo semanage fcontext -a -t public_content_rw_t "/var/ftp/pub(/.*)?"
    sudo restorecon -Rv /var/ftp/pub
}


montar_carpeta_grupo() {

    local username=$1
    local grupo=$2

    local home_usuario="/home/$username"
    local origen="/home/${grupo}"
    local destino="${home_usuario}/${grupo}"

    sudo mkdir -p "$destino"

    sudo chown root:$grupo "$destino"
    sudo chmod 750 "$destino"

    if ! mountpoint -q "$destino"; then
        sudo mount --bind "$origen" "$destino"
    fi

    sudo semanage fcontext -a -t user_home_dir_t "${destino}(/.*)?"
    sudo restorecon -Rv "$destino"

    local fstab_entry="${origen} ${destino} none bind 0 0"

    if ! grep -qF "$fstab_entry" /etc/fstab; then
        echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
    fi
}


montar_pub() {

    local username=$1
    local home_usuario="/home/$username"

    local origen="/var/ftp/pub"
    local destino="${home_usuario}/pub"

    sudo mkdir -p "$destino"

    sudo chown root:ftp "$destino"
    sudo chmod 775 "$destino"

    if ! mountpoint -q "$destino"; then
        sudo mount --bind "$origen" "$destino"
    fi

    sudo semanage fcontext -a -t public_content_rw_t "${destino}(/.*)?"
    sudo restorecon -Rv "$destino"

    sudo setsebool -P ftp_home_dir on

    local fstab_entry="${origen} ${destino} none bind 0 0"

    if ! grep -qF "$fstab_entry" /etc/fstab; then
        echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
    fi
}


crear_usuario_ftp() {

    local username=$1
    local grupo=$2

    local home_usuario="/home/$username"

    sudo useradd -d "$home_usuario" -s /sbin/nologin -G "$grupo" "$username"

    echo "Contraseña para $username:"
    sudo passwd "$username"

    sudo mkdir -p "$home_usuario"
    sudo chown root:root "$home_usuario"
    sudo chmod 755 "$home_usuario"

    sudo mkdir -p "${home_usuario}/${username}"
    sudo chown "${username}:${username}" "${home_usuario}/${username}"
    sudo chmod 770 "${home_usuario}/${username}"

    montar_pub "$username"

    montar_carpeta_grupo "$username" "$grupo"

    sudo semanage fcontext -a -t user_home_dir_t "${home_usuario}(/.*)?"
    sudo restorecon -Rv "$home_usuario"

    sudo usermod -aG ftp "$username"

    grep -qxF "$username" /etc/vsftpd/user_list || \
    echo "$username" | sudo tee -a /etc/vsftpd/user_list

    echo "Usuario $username creado en grupo $grupo"
}

desmontar_carpeta() {

    local punto_montaje=$1

    if mountpoint -q "$punto_montaje"; then
        sudo umount "$punto_montaje"
        echo "Desmontado: $punto_montaje"
    fi

    sudo sed -i "\| ${punto_montaje} |d" /etc/fstab
}

cambiar_rol() {

    local username=$1
    local grupo_nuevo=$2
    local grupo_viejo=$3

    sudo umount /home/$username/recursadores 2>/dev/null
    sudo umount /home/$username/reprobados 2>/dev/null

    local home_usuario="/home/$username"

    echo "Cambiando $username de '$grupo_viejo' a '$grupo_nuevo'..."

    local punto_viejo="${home_usuario}/${grupo_viejo}"

    desmontar_carpeta "$punto_viejo"

    sudo rmdir "$punto_viejo" 2>/dev/null

    sudo usermod -g "$grupo_nuevo" "$username"
    sudo gpasswd -d "$username" "$grupo_viejo"

    sudo usermod -aG "$grupo_nuevo" "$username"

    sudo chown "${username}:${grupo_nuevo}" "${home_usuario}/${username}"

    montar_carpeta_grupo "$username" "$grupo_nuevo"

    echo "$username ahora pertenece a '$grupo_nuevo'"
}


listar_usuarios () {
    echo "Usuarios en /etc/vsftpd/user_list:"

    grep -v '^#' /etc/vsftpd/user_list | tail -n +16 | while read -r usuario; do
        id -Gn $usuario | awk '{ print "usuario " $1 " -> " $2,$3,$4 }'
    done


    echo "**********************"
}



agregar_usuarios() {
    echo "Agregar usuarios FTP Daemon"

    if ! command -v vsftpd &>/dev/null; then
        echo "vsftpd no está instalado. Instálalo primero."
        exit 1
    fi

    read -p "¿Cuántos usuarios deseas crear? " n

    if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -le 0 ]; then
        echo "Número inválido."
        exit 1
    fi

    for ((i=1; i<=n; i++)); do
        echo ""
        echo "--- Usuario $i de $n ---"

        read -p "Nombre de usuario: " username

        if id "$username" &>/dev/null; then
            echo "El usuario '$username' ya existe. Saltando..."
            continue
        fi

        echo "Rol:"
        echo "  1) Reprobado (reprobados)"
        echo "  2) Recursador (recursadores)"
        read -p "Opción [1/2]: " rol

        case $rol in
            1) grupo="reprobados" ;;
            2) grupo="recursadores" ;;
            *)
                echo "Opción inválida. Saltando usuario $username."
                continue
                ;;
        esac

        crear_usuario_ftp "$username" "$grupo"
    done

    echo "Reiniciando vsftpd..."
    sudo systemctl restart vsftpd

    echo ""
    echo "**********************"
    echo "Usuarios en /etc/vsftpd/user_list:"
    cat /etc/vsftpd/user_list | grep -v "^#" | tail -n +17
    echo "**********************"
}

cambiar_grupo_usuario() {

    echo "Usuarios FTP:"
    cat /etc/vsftpd/user_list | grep -v "^#" | tail -n +17

    read -p "Usuario a cambiar: " username

    if ! id "$username" &>/dev/null; then
        echo "El usuario no existe"
        return
    fi

    grupos=$(id -Gn "$username")


    if [[ $grupos == *"reprobados"* ]]; then
        grupo_actual="reprobados"
        grupo_nuevo="recursadores"
    elif [[ $grupos == *"recursadores"* ]]; then
        grupo_actual="recursadores"
        grupo_nuevo="reprobados"
    else
        echo "El usuario no pertenece a los grupos del sistema FTP"
        return
    fi
    echo "Grupo actual: $grupo_actual"

    read -p "Cambiar a $grupo_nuevo? [s/N]: " confirm

    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo "Cancelado"
        return
    fi

    cambiar_rol "$username" "$grupo_nuevo" "$grupo_actual"

    desmontar_carpeta "/home/$username/$grupo_actual"

    sudo systemctl restart vsftpd

    echo "Cambio completado"
}

