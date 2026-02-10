
. "./linux/functions_linux.sh"

install_dhcp_server() {

    #check_dhcp=$(check_package_present "dhcp-server")
    #echo $check_dhcp
    install_required_package "ipcalc"

    if ! check_package_present "dhcp-server"; then
        echo "No esta instalado"
        install_required_package "dhcp-server"
        if [[ $? -eq 0 ]]; then
            echo "Paquete dhcp-server instalado correctamente"
        else 
            echo "Error al instalar el paquete dhcp-server"
            exit 1
        fi
    else 
        echo "El paquete dhcp-server ya está instalado"
    fi

    configurar_dhcp_server
}

configurar_dhcp_server() {
    local nombreScope=$(input "Introduce el nombre del scope: ")
    echo "Configurando el servidor DHCP con el scope $nombreScope..."

    sudo systemctl restart NetworkManager
    device="enp0s8"
    con_name=$(nmcli -t -f DEVICE,NAME con show --active | grep $device: | cut -d ':' -f2)
    address=$(get_valid_ipaddr "Ingresa la dirección IPv4 que asignará el servidor DHCP: ") 
    gateway=$(get_valid_ipaddr "Ingresa la dirección IPv4 que asignará al Gateway: ") 
    mask=$(get_valid_ipaddr "Ingresa la mascara de subred: ")
    prefix=$(ipcalc -p 0.0.0.0 "$mask" | cut -d= -f2)
    rango_inicial=$(get_valid_ipaddr "Ingresa la dirección IPv4 del rango inicial: ")
    rango_final=$(get_valid_ipaddr "Ingresa la dirección IPv4 del rango final: ")
    network=$(ipcalc -n $address/$prefix | cut -d '=' -f2 )

    sudo nmcli con mod "$con_name" ipv4.addresses $address/$prefix ipv4.gateway $gateway ipv4.method manual 

    sudo ifconfig "$device" $address"/"$prefix 
 
    sudo systemctl enable dhcpd

    sudo systemctl restart dhcpd

    mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf-$(date +%Y%m%d%H%M%S).bak

    cat <<EOF > /etc/dhcp/dhcpd.conf
    default-lease-time 600;
    max-lease-time 7200;
    option domain-name-servers 8.8.8.8, 8.8.4.4;

    subnet $network netmask $mask {
      range $rango_inicial $rango_final;
      option routers $gateway;
    }
EOF

    sudo systemctl restart dhcpd

}


verificar_instalacion() {
    echo "Verificando instalación de DHCP Server..."
    if check_package_present "dhcp-server"; then
        echo "✔ dhcp-server está instalado"
    else
        echo "✖ dhcp-server NO está instalado"
    fi
}

instalar_dependencias() {
    echo "Instalando dependencias..."
    install_required_package "ipcalc"

    if ! check_package_present "dhcp-server"; then
        install_required_package "dhcp-server"
        if [[ $? -eq 0 ]]; then
            echo "✔ dhcp-server instalado correctamente"
        else
            echo "✖ Error al instalar dhcp-server"
            exit 1
        fi
    else
        echo "✔ dhcp-server ya está instalado"
    fi
}

monitorear_dhcp() {
    echo "Monitoreando servicio DHCP (Ctrl+C para salir)..."
    sudo journalctl -u dhcpd -f
}

# ========= MENU =========

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