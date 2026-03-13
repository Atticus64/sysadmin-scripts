#!/bin/bash
SOURCE_DIR="$(dirname "$(readlink -f "$0")")"
source "$SOURCE_DIR/../services/http.sh"

echo ""
echo "======================================================"
echo "   Instalador de servidor HTTP para Fedora"
echo "======================================================"
echo "  1) Apache (httpd)"
echo "  2) Nginx"
echo "  3) Tomcat"
echo "  4) Cambiar puerto de un servidor ya instalado"
echo "  0) Salir"
echo ""

while true; do
    read -rp "  Selecciona el servidor a instalar: " opc
    [[ "$opc" =~ ^[0-3]$ ]] && break
    echo "  Opcion invalida."
done

case "$opc" in
0)
    echo "  Saliendo."
    exit 0
    ;;
1)
    mapfile -t versiones < <(get_versiones "httpd")
    select_version "Apache (httpd)" "${versiones[@]}"
    read_puerto 80
    install_servicio "httpd" "$VERSION_ELEGIDA" "$PUERTO_ELEGIDO"
    ;;
2)
    mapfile -t versiones < <(get_versiones "nginx")
    select_version "Nginx" "${versiones[@]}"
    read_puerto 80
    install_servicio "nginx" "$VERSION_ELEGIDA" "$PUERTO_ELEGIDO"
    ;;
3)
    echo ""
    echo "  Buscando paquetes de Tomcat disponibles..."
    mapfile -t pkgs < <(get_versiones "tomcat")

    if [ ${#pkgs[@]} -eq 0 ]; then
        echo "[ERROR] No se encontraron paquetes de Tomcat."
        exit 1
    fi

    echo ""
    echo "  Paquetes de Tomcat disponibles:"
    for ((i = 0; i < ${#pkgs[@]}; i++)); do
        echo "  $((i + 1))) ${pkgs[$i]}"
    done

    while true; do
        read -rp "
  ¿Cual paquete deseas instalar? [1-${#pkgs[@]}]: " eleccion
        if [[ "$eleccion" =~ ^[0-9]+$ ]] && [ "$eleccion" -ge 1 ] && [ "$eleccion" -le ${#pkgs[@]} ]; then
            PKG_TOMCAT="${pkgs[$((eleccion - 1))]}"
            break
        fi
        echo "  Opcion invalida."
    done

    mapfile -t versiones < <(get_versiones "$PKG_TOMCAT")
    select_version "Tomcat ($PKG_TOMCAT)" "${versiones[@]}"
    read_puerto 8080
    install_servicio "tomcat" "$VERSION_ELEGIDA" "$PUERTO_ELEGIDO"
    ;;
4)
    echo "  ¿De que servicio deseas cambiar el puerto?"
    echo "  1) Apache (httpd)"
    echo "  2) Nginx"
    echo "  3) Tomcat"
    while true; do
        read -rp "  Selecciona el servicio: " servicio
        [[ "$servicio" =~ ^[1-3]$ ]] && break
        echo "  Opcion invalida."
    done
    read_puerto 80
    case "$servicio" in
    1) set_puerto_apache2 "$PUERTO_ELEGIDO" ;;
    2) set_puerto_nginx "$PUERTO_ELEGIDO" ;;
    3) set_puerto_tomcat "$PUERTO_ELEGIDO" ;;
    esac
    ;;
esac