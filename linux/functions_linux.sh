
valid_ipaddr() {
    install_requred_package "ipcalc"
    local ip=$1

    # regresando el status de la operacion ipcalc
    if [[ipcalc -cs $ip]]; then
        return 0
    else 
        return 1
    fi 
}

check_package_present() {
    name=$1
    local message=$(rpm -q $name 2>&1)

    if [[ $message =~ "not installed" ]]; then
        return 1
    else 
        return 0
    fi 
}

install_requred_package() {
    name=$1
    if ! check_package_present $name; then
        echo "Instalando paquete $name"
        sudo dnf install -y $name --quiet 
        if [ $? -ne 0 ]; then
            echo "Error al instalar el paquete $name"
            exit 1
        fi
    fi
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
