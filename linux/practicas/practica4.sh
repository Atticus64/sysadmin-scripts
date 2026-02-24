
. "./linux/functions_linux.sh"

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

menu_interactivo() {
    while true; do
        mostrar_menu
        read -p "Selecciona una opción: " opcion

        case $opcion in
            1) verificar_instalacion ;;
            2) instalar_dependencias ;;
            3) conectarse_ssh ;;
            4) echo "Saliendo..."; exit 0 ;;
            *) echo "Opción inválida" ;;
        esac
    done
}

mostrar_help() {
cat <<EOF
Uso:
  practica4.sh [OPCIÓN]

Opciones:
  --check        Verifica si el servicio SSH está instalado.
  --install      Instala las dependencias necesarias e instala openssh-server si no existe.
  --connect      Conectarse a un servidor SSH
  --help         Muestra esta ayuda y sale.

Sin opciones:
  Ejecuta el script en modo interactivo mostrando un menú.

Ejemplos:
  ./practica4.sh --check
  ./practica4.sh --install
  ./practica4.sh --list
  ./practica4.sh
EOF
}


main() {
    case "$1" in
        --check)
            verificar_instalacion
            ;;
        --install)
            instalar_dependencias
            ;;
        --connect)
            conectarse_ssh
            ;;
        --help)
            mostrar_help
            ;;
        "")
            menu_interactivo
            ;;
        *)
            echo "Uso:"
            echo "  $0 --check     Verificar instalación"
            echo "  $0 --install   Instalar dependencias"
            echo "  $0 --connect   Conectarse a un servidor SSH"
            echo "  $0             Mostrar menú interactivo"
            exit 1
            ;;
    esac
}

main "$@"