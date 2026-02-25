source ../functions_linux.sh

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

    if grep -q "allow-query { any; };" /etc/named.conf &&
       grep -q "listen-on port 53 { any; };" /etc/named.conf &&
       grep -q "listen-on-v6 port 53 { any; };" /etc/named.conf; then

        echo "[OK] Configuración de named.conf ya tiene allow-query y listen configurados"

    else
        echo "Actualizando bloque options en named.conf..."

        sudo sed -i '
/^[[:space:]]*options[[:space:]]*{/ {
    :a
    n
    /^[[:space:]]*};/ b
    /allow-query/d
    /listen-on port/d
    /listen-on-v6/d
    ba
}
' /etc/named.conf

        sudo sed -i '/^[[:space:]]*options[[:space:]]*{/a\
    allow-query { any; };\
    listen-on port 53 { any; };\
    listen-on-v6 port 53 { any; };' /etc/named.conf

        echo "[OK] Bloque options actualizado correctamente"
    fi

    # Validar configuración
    if sudo named-checkconf /etc/named.conf; then
        echo "[OK] Configuración de named.conf es válida"
    else
        echo "[Error] Configuración de named.conf es inválida"
        exit 1
    fi

    # Verificar interfaz
    state_ip=$(ip -br addr show enp0s8 | awk '{print $2}')
    ip_value=$(ip -br addr show enp0s8 | awk '{print $3}')

    if [[ "$state_ip" == "UP" && -n "$ip_value" ]]; then
        echo "[OK] Interfaz enp0s8 está activa y tiene IP asignada"
    else
        echo "[Error] Interfaz enp0s8 no está activa o sin IP"

        ip_new=$(input "Ingresa una dirección IP válida para la interfaz enp0s8: ")
        prefix=$(input "Ingresa el prefijo de la máscara (ej. 24): ")

        network=$(ipcalc -n $ip_new/$prefix | awk -F= '{print $2}')
        mascara=$(ipcalc -m $ip_new/$prefix | awk -F= '{print $2}')

        sudo ip addr add $ip_new/$prefix dev enp0s8
        sudo route add --net $network netmask $mascara dev enp0s8

        exit 1
    fi

    # Verificar firewall
    if ! sudo firewall-cmd --list-services | grep -qw dns; then
        sudo firewall-cmd --add-service=dns --permanent
        sudo firewall-cmd --reload
        echo "[OK] Servicio DNS agregado al firewall"
    fi

    sudo systemctl restart named
    echo "[OK] Servicio named reiniciado"
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
    ip_dominio=$(input "Ingresa la IPv4 para el dominio (default server): ")

    # la ip es opcional 
    if [[ -z "$ip_dominio" ]]; then
        ip_dominio=$(ip -br addr show enp0s8 | awk '{print $3}' | cut -d'/' -f1)
    fi

    while [[ -z "$dominio" ]]; do
        echo "Error: El nombre del dominio no pueden estar vacío"
        dominio=$(input "Ingresa el nombre del dominio a agregar: ")
    done  

   

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

    name_file=$(ls /etc/ | grep zones | head -n 1)

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
        con_name=$(nmcli -t -f DEVICE,NAME con show --active | grep $device: | cut -d ':' -f2)

        sudo cp /etc/$name_file /etc/$name_file.bak

        sudo sed -i "/zone \"$dominio\" IN {/,/};/d" /etc/$name_file 

        nmcli con mod up "$con_name"
        sudo systemctl restart named
    else
        echo "No se encontró el directorio de zonas: /etc/bind/zones"
    fi      

}