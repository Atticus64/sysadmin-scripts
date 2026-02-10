
input() {
    read -p "$1" input

    echo $input  
}

valid_ipaddr() {
    install_required_package "ipcalc"
    local ip=$1

    # regresando el status de la operacion ipcalc
    ipcalc -cs "$ip" || return 1

    case "$ip" in
        0.0.0.0) return 1 ;;   
        255.255.255.255) return 1 ;;   
        127.*)   return 1 ;;   
        *)       return 0 ;;
    esac
}


get_valid_ipaddr() {
    local ip
    local prompt=${1:-"Ingresa una dirección IPv4 válida: "}
    ip=$(input "$prompt")
    while ! valid_ipaddr "$ip"; do
        echo "La dirección IP ingresada no es válida. Por favor, inténtalo de nuevo." >&2
        ip=$(input "$prompt") 
    done

    echo $ip
}

check_package_present() {
    name=$1
    
    rpm -q $name 2>&1 > /dev/null
}

install_required_package() {
    name=$1
    if ! check_package_present $name; then
        # "Instalando paquete $name"
        sudo dnf install -y $name --quiet > /dev/null 2>&1 
        if [ $? -ne 0 ]; then
            echo "Error al instalar el paquete $name"
            return 1
        fi
    fi

    return 0
}

get_network() {
    local ip=$1
    local prefix=$2
    ipcalc -n "$ip/$prefix" | cut -d '=' -f2
}

ip_in_network() {
    local ip=$1
    local network=$2
    local prefix=$3

    ipcalc -c "$ip" "$network/$prefix" >/dev/null 2>&1
}

validate_dhcp_range() {
    local server_ip=$1
    local network=$2
    local prefix=$3
    local start_ip=$4
    local end_ip=$5
    local gateway=$6


    for ip in "$start_ip" "$end_ip" "$gateway"; do
        if ! ip_in_network "$ip" "$network" "$prefix"; then
            echo "La IP $ip no pertenece a la red $network/$prefix"
            return 1
        fi
    done
}




imprimir_info() {
	nombre_equipo=$(hostname)
	ip_actual=$(hostname -I | cut -d ' ' -f 2)
	espacio_disco=$(df -kh . | grep / | awk -F ' ' '{ print $2 "/" $4 }' )


	if [[ "$ip_actual" = '' ]]; then
		ip_actual=$(hostname -I | cut -d ' ' -f 1)
	fi

	RED='\033[0;31m'
	YELLOW='\033[0;33m'
	BLUE='\033[0;34m'
	NC='\033[0m'

	echo -e "${RED}Nombre equipo${NC}\t | ${BLUE}Ip actual${NC}\t | ${YELLOW}Disco Total/Libre${NC}"
	echo $nombre_equipo, $ip_actual, $espacio_disco
}
