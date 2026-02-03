
imprimir_info() {
	nombre_equipo=$(hostname)
	ip_actual=$(hostname -I | cut -d ' ' -f 2)
	espacio_disco=$(df -kh . | grep / | awk -F ' ' '{ print $4 }' )


	if [[ "$ip_actual" = '' ]]; then
		ip_actual=$(hostname -I | cut -d ' ' -f 1)
	fi

	RED='\033[0;31m'
	YELLOW='\033[0;33m'
	BLUE='\033[0;34m'
	NC='\033[0m'

	echo -e "${RED}Nombre equipo${NC}\t | ${BLUE}Ip actual${NC}\t | ${YELLOW}Espacio en disco${NC}"
	echo $nombre_equipo, $ip_actual, $espacio_disco"GB"
}
