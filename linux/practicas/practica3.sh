
. "./linux/functions_linux.sh"

install_bind_service() {

    #check_dhcp=$(check_package_present "dhcp-server")
    #echo $check_dhcp
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

    address=$()

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
    fi

    sudo ifconfig "$device" $address"/"$prefix 
 
    sudo systemctl enable dhcpd

    sudo systemctl restart dhcpd

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
    if check_package_present "bind"; then
        echo "[OK] dhcp-server está instalado"
    else
        echo "[Error] dhcp-server NO está instalado"
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
  --check        Verifica si el servicio DHCP (dhcp-server) está instalado.
  --install      Instala las dependencias necesarias e instala dhcp-server si no existe.
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