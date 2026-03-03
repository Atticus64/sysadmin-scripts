#!/bin/sh
# Servicio FTP
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )
source $SCRIPT_DIR/../services/ftp.sh

mostrar_menu() {
    echo ""
    echo "========= MENÚ FTP ========="
    echo "1) Verificar instalación"
    echo "2) Instalar dependencias"
    echo "3) Agregar usuarios"
    echo "4) Cambiar usuario grupo"
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
            3) agregar_usuarios ;;
            4) cambiar_grupo_usuario ;;
            5) echo "Saliendo..."; exit 0 ;;
            *) echo "Opción inválida" ;;
        esac
    done
}

mostrar_help() {
cat <<EOF
Uso:
  practica5.sh [OPCIÓN]

Opciones:
  --check        Verifica si el servicio $service_name está instalado.
  --install      Instala las dependencias necesarias e instala $package si no existe.
  --add-users    Agregar usuarios a los grupos
  --chuser       Cambiar a un usuario de grupo
  --help         Muestra esta ayuda y sale.

Sin opciones:
  Ejecuta el script en modo interactivo mostrando un menú.

Ejemplos:
  ./practica4.sh --check
  ./practica4.sh --install
  ./practica4.sh --add-users
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
        --add-users)
            agregar_usuarios
            ;;
        --chuser)
            cambiar_grupo_usuario
            ;;
        "")
            menu_interactivo
            ;;
        *)
            echo "Uso:"
            echo " $0 --check        Verifica si el servicio $service_name está instalado."
            echo " $0 --install      Instala las dependencias necesarias e instala $package si no existe."
            echo " $0 --add-users    Agregar usuarios a los grupos"
            echo " $0 --chuser       Cambiar a un usuario de grupo"
            echo " $0 --help         Muestra esta ayuda y sale."
            exit 1
            ;;
    esac
}

main "$@"
