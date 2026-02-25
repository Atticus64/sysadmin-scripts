SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )
source $SCRIPT_DIR/../services/dns.sh

mostrar_menu() {
    echo ""
    echo "========= MENÚ DNS ========="
    echo "1) Verificar instalación"
    echo "2) Instalar dependencias"
    echo "3) Listar Dominios configurados"
    echo "4) Agregar nuevo dominio"
    echo "5) Eliminar un dominio"
    echo "6) Salir"
    echo "============================="
}

menu_interactivo() {
    while true; do
        mostrar_menu
        read -p "Selecciona una opción: " opcion

        case $opcion in
            1) verificar_instalacion ;;
            2) instalar_dependencias ;;
            3) listar_dominios ;;
            4) agregar_dominio ;;
            5) eliminar_dominio ;;
            6) echo "Saliendo..."; exit 0 ;;
            *) echo "Opción inválida" ;;
        esac
    done
}

mostrar_help() {
cat <<EOF
Uso:
  practica3.sh [OPCIÓN]

Opciones:
  --check        Verifica si el servicio DNS (bind) está instalado.
  --install      Instala las dependencias necesarias e instala bind si no existe.
  --list         Lista los dominios configurados en el servidor DNS
  --add          Agrega un nuevo dominio al servidor DNS
  --rm           Elimina un dominio del servidor DNS
  --help         Muestra esta ayuda y sale.

Sin opciones:
  Ejecuta el script en modo interactivo mostrando un menú.

Ejemplos:
  ./practica3.sh --check
  ./practica3.sh --install
  ./practica3.sh --list
  ./practica3.sh --add
  ./practica3.sh --rm
  ./practica3.sh
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
        --list)
            listar_dominios
            ;;
        --add)
            agregar_dominio
            ;;
        --rm)
            eliminar_dominio
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
            echo "  $0 --list      Listar dominios configurados"
            echo "  $0 --add       Agregar nuevo dominio"
            echo "  $0 --rm        Eliminar un dominio"
            echo "  $0             Mostrar menú interactivo"
            exit 1
            ;;
    esac
}

main "$@"