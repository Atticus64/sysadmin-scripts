SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )

source $SCRIPT_DIR/../functions_linux.sh

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

get_dns_servers() {
    local dns_list

    while true; do
        read -rp "DNS servers (espacio o coma): " dns_list
        record_list=${dns_list//,/ }

        local ok=true
        for dns in $record_list; do
            valid_ipaddr "$dns" || {
                echo "[Error] DNS inválido: $dns"
                ok=false
                break
            }
        done

        $ok && break
    done

    echo "$dns_list"
}

get_lease_time() {
    local lease

    while true; do
        read -rp "Lease time en segundos (ej. 86400): " lease
        [[ "$lease" =~ ^[0-9]+$ && "$lease" -ge 100 ]] && break
        echo "Lease inválido (mínimo 100s)"
    done

    echo "$lease"
}

configurar_dhcp_server() {
    local nombreScope=$(input "Introduce el nombre del scope: ")
    echo "Configurando el servidor DHCP con el scope $nombreScope..."

    sudo systemctl restart NetworkManager
    device="enp0s8"
    con_name=$(nmcli -t -f DEVICE,NAME con show --active | grep $device: | cut -d ':' -f2)
    rango_inicial=$(get_valid_ipaddr "Ingresa la dirección IPv4 del rango inicial: ")
    rango_final=$(get_valid_ipaddr "Ingresa la dirección IPv4 del rango final: ")

    # validar si los rangos tienen sentido 
    while ! validate_ip_range "$rango_inicial" "$rango_final" 
    do
        echo "Rango inválido. Inténtalo de nuevo."
        rango_inicial=$(get_valid_ipaddr "Ingresa la dirección IPv4 del rango inicial: ")
        rango_final=$(get_valid_ipaddr "Ingresa la dirección IPv4 del rango final: ")
    done

    #mask="255.255.255.0"
    #address=$(get_valid_ipaddr "Ingresa la dirección IPv4 que asignará el servidor DHCP: ") 
    mask=$(get_valid_ipaddr "Ingresa la mascara de subred: ")
    while ! validate_mask "$mask" ;
    do
        echo "Máscara de subred inválida. Inténtalo de nuevo."
        mask=$(get_valid_ipaddr "Ingresa la mascara de subred: ")
    done

    gateway=$(input "Ingresa la dirección IPv4 que asignará al Gateway [opcional]: ")

    if [[ -n "$gateway" ]]; then
        while ! valid_ipaddr "$gateway"; do
            echo "La dirección IPv4 del gateway no es válida."
            gateway=$(input "Ingresa la dirección IPv4 que asignará al Gateway [opcional]: ")
            if [[ -z "$gateway" ]]; then
                break
            fi
        done
    fi

    IFS=. read -r o1 o2 o3 o4 <<< "$rango_inicial"

    if (( o4 >= 254 )); then
        echo "No se puede incrementar la IP inicial"
        exit 1
    fi

    address="$rango_inicial"
    rango_inicial="$o1.$o2.$o3.$((o4 + 1))"

    prefix=$(ipcalc -p 0.0.0.0 "$mask" | cut -d= -f2)
    network=$(ipcalc -n $address/$prefix | cut -d '=' -f2 )

    validate_dhcp_range \
        "$address" \
        "$network" \
        "$prefix" \
        "$rango_inicial" \
        "$rango_final" \
        "$gateway" || exit 1

    dns_servers=$(get_dns_servers)
    lease_time=$(get_lease_time)

    if [[ -n "$gateway" ]]; then
        sudo nmcli con mod "$con_name" ipv4.addresses $address/$prefix ipv4.gateway $gateway ipv4.method manual 
    else 
        #sudo ifconfig $device $address netmask $mask  
        sudo nmcli con mod "$con_name" ipv4.addresses $address/$prefix ipv4.method manual   
        sudo ip addr add $address/$prefix dev $device
        sudo route add $network/$prefix dev $device
    fi

    sudo nmcli con mod "$con_name" ipv4.ignore-auto-dns yes
    sudo nmcli con mod "$con_name" ipv4.dns "$dns_servers"

    sudo nmcli con up "$con_name"
 
    sudo systemctl enable dhcpd

    mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf-$(date +%Y%m%d%H%M%S).bak

    {
        echo "default-lease-time $lease_time;"
        echo "max-lease-time $lease_time;"

        [[ -n "$dns_servers" ]] && \
            echo "option domain-name-servers $dns_servers;"

        echo ""
        echo "subnet $network netmask $mask {"
        echo "  range $rango_inicial $rango_final;"

        [[ -n "$gateway" ]] && \
            echo "  option routers $gateway;"

        echo "  option domain-name \"$nombreScope\";"
        echo "}"
    } > /etc/dhcp/dhcpd.conf
   
    sudo systemctl restart dhcpd

}


verificar_instalacion() {
    echo "Verificando instalación de DHCP Server..."
    if check_package_present "dhcp-server"; then
        echo "[OK] dhcp-server está instalado"
    else
        echo "[Error] dhcp-server NO está instalado"
    fi
}

instalar_dependencias() {
    echo "Instalando dependencias..."
    install_required_package "ipcalc"

    if ! check_package_present "dhcp-server"; then
        install_required_package "dhcp-server"
        if [[ $? -eq 0 ]]; then
            echo "[OK] dhcp-server instalado correctamente"
        else
            echo "[Error] Fallo al instalar dhcp-server"
            exit 1
        fi
    else
        echo "dhcp-server ya está instalado"
    fi
}

monitorear_dhcp() {
    echo "Monitoreando servicio DHCP (Ctrl+C para salir)..."
    sudo journalctl -u dhcpd -f
}