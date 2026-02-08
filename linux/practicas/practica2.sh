
. "./linux/functions_linux.sh"

install_dhcp_server() {

    #check_dhcp=$(check_package_present "dhcp-server")
    #echo $check_dhcp

    if ! check_package_present "dhcp-server"; then
        echo "No esta instalado"
        #install_required_package "dhcp-server"
        #if [[ $? -eq 0 ]]; then
        #    echo "Paquete dhcp-server instalado correctamente"
        #else 
        #    echo "Error al instalar el paquete dhcp-server"
        #    exit 1
        #fi
    else 
        echo "El paquete dhcp-server ya está instalado"
    fi

}

configurar_dhcp_server() {
    #local nombreScope=$(input "Introduce el nombre del scope: ")
}

install_dhcp_server
