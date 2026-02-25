SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )
source $SCRIPT_DIR/../services/ssh.sh

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