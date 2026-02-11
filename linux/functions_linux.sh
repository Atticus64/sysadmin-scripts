
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
        127.0.0.1)   return 1 ;;   
        *)       return 0 ;;
    esac
}

validate_mask() {
    local mask=$1

    # formato correcto
    if ! [[ $mask =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        echo "Invalid format: $mask"
        return 1
    fi

    # extrae los octetos
    IFS='.' read -r -a octets <<< "$mask"

    # checa si cada octeto es uno de los valores válidos para máscaras de subred
    for octet in "${octets[@]}"; do
        case "$octet" in
            0|128|192|224|240|248|252|254|255)
                continue
                ;;
            *)
                echo "Invalid octet value: $octet"
                return 1
                ;;
        esac
    done

    # consistencia de los 0,1s
    local binary_mask=""
    for octet in "${octets[@]}"; do
        local bin_octet=$(echo "obase=2; $octet" | bc)

        while [ ${#bin_octet} -lt 8 ]; do
            bin_octet="0$bin_octet"
        done
        binary_mask="${binary_mask}${bin_octet}"
    done

    if [[ $binary_mask =~ 01 ]]; then
        echo "Invalid mask: ones and zeros are not contiguous."
        return 1
    fi

    #echo "Valid mask: $mask"
    return 0
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

ip_in_network() {
    local ip=$1
    local network=$2
    local prefix=$3

    local ip_network
    ip_network=$(ipcalc -n "$ip/$prefix" | cut -d '=' -f2)

    [[ "$ip_network" == "$network" ]]
}

ip_to_num() {
    local a b c d ip=$@
    IFS=. read -r a b c d <<< "$ip"
    printf '%d\n' "$((a * 256**3 + b * 256**2 + c * 256 + d))"
}

validate_ip_range() {
    local ip1=$1
    local ip2=$2

    local ip1_num=$(ip_to_num "$ip1")
    local ip2_num=$(ip_to_num "$ip2")

    if [[ $ip1_num -gt $ip2_num ]]; then
        echo "La IP inicial debe ser menor o igual a la IP final"
        return 1
    fi


    return 0
}

validate_dhcp_range() {
    local server_ip=$1
    local network=$2
    local prefix=$3
    local start_ip=$4
    local end_ip=$5
    local gateway=$6

    if [[ -n "$gateway" ]]; then
        for ip in "$start_ip" "$end_ip" "$gateway"; do
            if ! ip_in_network "$ip" "$network" "$prefix"; then
                echo "La IP $ip no pertenece a la red $network/$prefix"
                return 1
            fi
        done
    fi

    for ip in "$start_ip" "$end_ip"; do
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
