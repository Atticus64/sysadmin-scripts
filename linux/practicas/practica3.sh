
. "./linux/functions_linux.sh"

install_bind_service() {

    #check_DNS=$(check_package_present "bind")
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
        echo "[OK] DNS service está instalado"
    else
        echo "[Error] DNS service NO está instalado"
    fi

    verificar_setup
}


verificar_setup() {
    echo "Verificando configuración del servidor DNS..."

    # checar si ya tiene allow query y listen port
    query=$(sudo grep 'allow-query  * { any; };' /etc/named.conf)  
    listenp=$(sudo grep 'listen-on port 53 { any; };' /etc/named.conf)
    if [[ -n "$query" && -n "$listenp" ]]; then
        echo "[OK] Configuración de named.conf ya tiene allow-query y listen-on configurados"
    else
        sudo sed -i '/options {/,/};/ s/allow-query {.*};/allow-query { any; };/' /etc/named.conf
        sudo sed -i '/options {/,/};/ s/listen-on port .*;/listen-on port 53 { any; };/' /etc/named.conf
    fi 

    sudo named-checkconf /etc/named.conf
    if [[ $? -eq 0 ]]; then
        echo "[OK] Configuración de named.conf es válida"
    else
        echo "[Error] Configuración de named.conf es inválida"
        exit 1
    fi

    state_ip=$(ip -br addr show enp0s8 | awk '{print $2}')
    ip_value=$(ip -br addr show enp0s8 | awk '{print $3}')


    if [[ "$state_ip" == "UP" && -n "$ip_value" ]]; then
        echo "[OK] Interfaz enp0s8 está activa y tiene una dirección IP asignada"
    else
        echo "[Error] Interfaz enp0s8 no está activa o no tiene una dirección IP asignada"

        ip_new=$(input "Ingresa una dirección IP válida para la interfaz enp0s8: ")
        prefix=$(input "Ingresa el prefijo de la máscara de subred (24)")

        network=$(ipcalc -n $ip_new | awk -F= '{print $2}')
        mascara=$(ipcalc -m $ip_new/$prefix | awk -F= '{print $2}') 
        sudo ip addr add $ip_new/$prefix dev enp0s8
        sudo route add --net $network netmask $mascara dev enp0s8

        exit 1
    fi

    services=$(sudo firewall-cmd --list-services | grep -w "dns")

    if [[ -z "$services" ]]; then
        sudo firewall-cmd --add-service=dns --permanent
        sudo firewall-cmd --reload
    fi

    sudo systemctl restart named
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


    verificar_setup
}

listar_dominios() {
    echo "Listando dominios configurados en el servidor DNS..."

    path="/etc/bind/zones/"

    if [ -d "$path" ]; then
        echo "Dominios configurados:"
        for file in "$path"/*; do
            if [ -f "$file" ]; then
                echo "- $(basename "$file")"
            fi
        done
    else
        echo "No se encontró el directorio de zonas: $path"
        echo "Creando directorio"
        sudo mkdir -p "$path"
    fi
}

agregar_dominio() {
    echo "Agregando nuevo dominio al servidor DNS..."   
    # TODO: implementar agregar dominio
    dominio=$(input "Ingresa el nombre del dominio a agregar: ")

    ip_dominio=$(get_valid_ipaddr "Ingresa la IPv4 para el dominio: ")

    if ! [[ -d "/etc/bind/zones" ]]; then
        sudo mkdir -p "/etc/bind/zones"
    fi  

    sudo touch /etc/bind/zones/$dominio.zone

    {
        echo "\$TTL 604800"
        echo "@ IN SOA ns.$dominio. root.$dominio. ("
        echo "    2;"
        echo "    604800;"
        echo "    86400;"
        echo "    2419200;"
        echo "    604800)" 
        echo ";"
        echo "@ IN NS $dominio."
        echo "@ IN A $ip_dominio"
        echo "www IN CNAME $dominio."
    } > "/etc/bind/zones/$dominio.zone"

    name_file=$(ls /etc/ | grep zones | grep -n 1)

    cat <<EOF >> "/etc/$name_file"
zone "$dominio" IN {
    type master;
    file "/etc/bind/zones/$dominio.zone";
};
EOF

    sudo systemctl restart named
}

eliminar_dominio() {
    echo "Eliminando un dominio del servidor DNS" 

    if [ -d "/etc/bind/zones" ]; then
        echo "Dominios configurados:"
        for file in "/etc/bind/zones/"*; do
            if [ -f "$file" ]; then
                echo "- $(basename "$file")"
            fi
        done

        dominio=$(input "Ingresa el nombre del dominio a eliminar: ")
        sudo rm -f "/etc/bind/zones/$dominio.zone"

        # eliminar zona de archivo zones

        name_file=$(ls /etc/ | grep zones | head -n 1)

        zones_file="/etc/$name_file"

        #rm -f $zones_file.bak 2>/dev/null

        #sudo cp $zones_file $zones_file.bak

        sudo sed -i "/zone \"$dominio\" IN {/,/};/d" $zones_file 

        sudo systemctl restart named
    else
        echo "No se encontró el directorio de zonas: /etc/bind/zones"
    fi      

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