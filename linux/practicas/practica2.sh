source ./services/dhcp.sh

mostrar_menu() {
    echo ""
    echo "========= MENÚ DHCP ========="
    echo "1) Verificar instalación"
    echo "2) Instalar dependencias"
    echo "3) Configurar DHCP"
    echo "4) Monitorear DHCP"
    echo "5) Salir"
    echo "============================="
}

menu_interactivo() {
    while true; do
        mostrar_menu
        read -p "Selecciona una opción: " opcion

        case $opcion in
            1) verificar_instalacion ;;
            2) instalar_dependencias ;;
            3) configurar_dhcp_server ;;
            4) monitorear_dhcp ;;
            5) echo "Saliendo..."; exit 0 ;;
            *) echo "Opción inválida" ;;
        esac
    done
}

mostrar_help() {
cat <<EOF
Uso:
  practica2.sh [OPCIÓN]

Opciones:
  --check        Verifica si el servicio DHCP (dhcp-server) está instalado.
  --install      Instala las dependencias necesarias e instala dhcp-server si no existe.
  --config       Configura el servidor DHCP solicitando los datos de red al usuario.
  --monitor      Monitorea en tiempo real el servicio DHCP (journalctl).
  --help         Muestra esta ayuda y sale.

Sin opciones:
  Ejecuta el script en modo interactivo mostrando un menú.

Ejemplos:
  ./practica2.sh --check
  ./practica2.sh --install
  ./practica2.sh --config
  ./practica2.sh --monitor
  ./practica2.sh
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
        --config)
            configurar_dhcp_server
            ;;
        --monitor)
            monitorear_dhcp
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
            echo "  $0 --config    Configurar DHCP"
            echo "  $0 --monitor   Monitorear DHCP"
            echo "  $0             Mostrar menú interactivo"
            exit 1
            ;;
    esac
}

main "$@"