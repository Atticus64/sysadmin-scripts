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
    -e 's/#ftpd_banner=Welcome to blah FTP service./ftpd_banner=Bienvenido a tu servicio FTP linuxero/' \
    -e 's/#anonymous_enable=YES/anonymous_enable=YES/' \
    -e 's/#chroot_local_user=YES/chroot_local_user=YES/' \
    $filename

    if ! grep -q "allow_writeable_chroot=YES" $filename; then
        echo "allow_writeable_chroot=YES" >> $filename
    fi

    if ! grep -q "no_anon_password=YES" $filename; then
        echo "no_anon_password=YES" >> $filename
    fi

    if ! grep -q "anon_root=/var/ftp" $filename; then
        echo "anon_root=/var/ftp" >> $filename
    fi

    if ! grep -q "anon_world_readable_only=YES" $filename; then
        echo "anon_world_readable_only=YES" >> $filename
    fi


    systemctl restart vsftpd
}

instalar_dependencias() {
    echo "Instalando dependencias..."

    if ! check_package_present $package; then
        install_required_package $package
        if [[ $? -eq 0 ]]; then
            echo "[OK] $package instalado correctamente"
        else
            echo "[Error] Fallo al instalar $package"
            exit 1
        fi
    else
        echo "$package ya está instalado"
    fi


    verificar_setup_ftp
}


agregar_usuarios() {
    # agregar usuarios a grupos reprobados o recursadores
    echo "Agregar usuarios a grupos"
}


cambiar_grupo_usuario() {
    # cambiar a un usuario de grupo
    echo "Cambiar a un usuario de grupo"
}
