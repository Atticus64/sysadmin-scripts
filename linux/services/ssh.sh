SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )

source $SCRIPT_DIR/../functions_linux.sh

install_ssh_service() {

    install_required_package "ipcalc"

    if ! check_package_present "openssh-server"; then
        echo "No esta instalado"
        install_required_package "openssh-server"
        if [[ $? -eq 0 ]]; then
            echo "Paquete openssh-server instalado correctamente"
        else 
            echo "Error al instalar el paquete openssh-server"
            exit 1
        fi
    else 
        echo "El paquete openssh-server ya está instalado"
    fi

}


verificar_instalacion() {
    echo "Verificando instalación de SSH Server..."
    if check_package_present "openssh-server"; then
        echo "[OK] SSH service está instalado"
    else
        echo "[Error] SSH service NO está instalado"
    fi

    verificar_setup_ssh
}

verificar_setup_ssh() {
    echo "Verificando configuración del servidor SSH..."

    if systemctl is-enabled --quiet sshd; then
        echo "[OK] El servicio SSH está habilitado para iniciar al arranque"
    else
        echo "Configurando el arranque del servicio SSH"
        systemctl enable sshd 
    fi

    if firewall-cmd -q --query-service ssh; then
        echo "[OK] El servicio SSH está permitido en el firewall"
    else
        echo "[INFO] Agregando regla para SSH"
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --reload
    fi

    if systemctl is-active --quiet sshd; then
        echo "[OK] El servicio SSH está activo"
    else
        echo "[Error] El servicio SSH se fue de sabatico, (esta dormido)"
        echo "Iniciando el servicio SSH"
        systemctl start sshd
    fi
}

instalar_dependencias() {
    echo "Instalando dependencias..."

    if ! check_package_present "openssh-server"; then
        install_required_package "openssh-server"
        if [[ $? -eq 0 ]]; then
            echo "[OK] openssh-server instalado correctamente"
        else
            echo "[Error] Fallo al instalar openssh-server"
            exit 1
        fi
    else
        echo "openssh-server ya está instalado"
    fi


    verificar_setup_ssh
}

mostrar_menu() {
    echo ""
    echo "========= MENÚ SSH ========="
    echo "1) Verificar instalación"
    echo "2) Instalar dependencias"
    echo "3) Conectarse a un servidor SSH"
    echo "4) Salir"
    echo "============================="
}

conectarse_ssh() {
    echo "Conexion SSH"
    server=$(get_valid_ipaddr "Ingresa la dirección IPv4 del servidor SSH a conectarse: ")
    user=$(input "Ingresa el nombre de usuario para la conexión SSH: ")

    while [[ -z "$user" ]]; do
        echo "El nombre de usuario no puede estar vacío. Por favor, inténtalo de nuevo." >&2
        user=$(input "Ingresa el nombre de usuario para la conexión SSH: ")
    done    

    ssh "$user@$server"
}