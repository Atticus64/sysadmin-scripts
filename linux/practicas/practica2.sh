
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

    sudo ifconfig "$con_name" $address"/"$prefix 
    
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

install_dhcp_server
