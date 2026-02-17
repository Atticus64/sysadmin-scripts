
. "./linux/functions_linux.sh"

install_bind_service() {

    #check_DNS=$(check_package_present "DNS-server")
    #echo $check_DNS
    install_required_package "ipcalc"
    install_required_package "bind-utils"

    if ! check_package_present "bind"; then
        echo "No esta instalado"
        install_required_package "bind"
        if [[ $? -eq 0 ]]; then
            echo "Paquete bind instalado correctamente"
        else 
            echo "Error al instalar el paquete bind"
            exit 1
        fi
    else 
        echo "El paquete bind ya está instalado"
    fi

    #configurar_bind_server
}


verificar_instalacion() {
    echo "Verificando instalación de DNS Server..."
    if check_package_present "bind"; then
        echo "[OK] DNS-server está instalado"
    else
        echo "[Error] DNS-server NO está instalado"
    fi
}

instalar_dependencias() {
    echo "Instalando dependencias..."
    install_required_package "ipcalc"

    if ! check_package_present "bind"; then
        install_required_package "bind"
        if [[ $? -eq 0 ]]; then
            echo "[OK] bind instalado correctamente"
        else
            echo "[Error] Fallo al instalar bind"
            exit 1
        fi
    else
        echo "bind ya está instalado"
    fi
}

listar_dominios() {
    echo "Listando dominios configurados en el servidor DNS..."
    # TODO: implementar lista
}

agregar_dominio() {
    echo "Agregando nuevo dominio al servidor DNS..."   
    # TODO: implementar agregar dominio
}

eliminar_dominio() {
    echo "Eliminando un dominio del servidor DNS..."    
    # TODO: implementar eliminar dominio
}

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
  practica2.sh [OPCIÓN]

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
  ./practica2.sh --check
  ./practica2.sh --install
  ./practica2.sh --list
  ./practica2.sh --add
  ./practica2.sh --rm
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