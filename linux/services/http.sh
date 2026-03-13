#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Ejecuta este script como root o con sudo."
    exit 1
fi

set_puerto_tomcat() {
    local puerto=$1
    local conf

    conf=$(find /etc/tomcat* /opt/tomcat* -name "server.xml" 2>/dev/null | head -1)

    if [ -z "$conf" ]; then
        echo "[ERROR] No se encontro server.xml de Tomcat."
        return 1
    fi

    sed -i "s/port=\"[0-9]*\" protocol=\"HTTP/port=\"$puerto\" protocol=\"HTTP/" "$conf"
    echo "[OK] Puerto de Tomcat cambiado a $puerto en $conf."

    local svc
    svc=$(systemctl list-units --type=service | grep -i tomcat | awk '{print $1}' | head -1)
    if [ -n "$svc" ]; then
        systemctl restart "$svc"
        echo "[OK] Tomcat reiniciado."
    else
        echo "[ADVERTENCIA] No se encontro el servicio tomcat. Reinicia manualmente."
    fi
}

# Repos adicionales que se habilitan temporalmente para buscar mas versiones.
REPOS_EXTRA=(
    "updates-testing"
    "updates-testing-modular"
    "fedora-cisco-openh264"
    "rpmfusion-free"
    "rpmfusion-free-updates"
    "rpmfusion-free-updates-testing"
)

get_versiones() {
    local paquete=$1

    local enable_flags=()
    for repo in "${REPOS_EXTRA[@]}"; do
        enable_flags+=("--enablerepo=$repo")
    done

    local versiones
    versiones=$(dnf repoquery --available \
        --queryformat "%{version}-%{release}" \
        "$paquete" 2>/dev/null \
        | sort -rV | uniq | head -12)

    if [ -z "$versiones" ]; then
        echo "[ADVERTENCIA] No se encontraron versiones extra. Usando solo repos activos." >&2
        versiones=$(dnf repoquery --available \
            --queryformat "%{version}-%{release}" \
            "$paquete" 2>/dev/null \
            | sort -rV | uniq | head -12)
    fi

    echo "$versiones"
}

# Buscar paquetes tomcat disponibles en dnf (nombre del paquete, no version)
get_paquetes_tomcat() {
    local pkgs

    # repoquery con wildcard para encontrar todos los paquetes tomcat*
    pkgs=$(dnf repoquery --available \
        --queryformat "%{name}" \
        "tomcat*" 2>/dev/null \
        | grep -E "^tomcat[0-9]*$" \
        | sort -rV | uniq)

    # Fallback: dnf search si repoquery no devuelve nada
    if [ -z "$pkgs" ]; then
        pkgs=$(dnf search tomcat 2>/dev/null \
            | grep -E "^tomcat[0-9]*\." \
            | awk -F'.' '{print $1}' \
            | sort -rV | uniq)
    fi

    echo "$pkgs"
}

select_version() {
    local etiqueta=$1
    shift
    local versiones=("$@")
    local total=${#versiones[@]}

    if [ $total -eq 0 ]; then
        echo "[ERROR] No se encontraron versiones de $etiqueta."
        return 1
    fi

    local lts_idx=$((total / 2))

    echo ""
    echo "  Versiones disponibles de $etiqueta:"
    for ((i = 0; i < total; i++)); do
        local label=""
        if [ $i -eq 0 ]; then
            label="  (Latest)"
        elif [ $i -eq $lts_idx ] && [ $total -ge 3 ]; then
            label="  (LTS / Estable)"
        elif [ $i -eq $((total - 1)) ]; then
            label="  (Oldest)"
        fi
        echo "  $((i + 1))) ${versiones[$i]}$label"
    done

    while true; do
        read -rp "
  ¿Cual version deseas instalar? [1-$total]: " eleccion
        if [[ "$eleccion" =~ ^[0-9]+$ ]] && [ "$eleccion" -ge 1 ] && [ "$eleccion" -le $total ]; then
            VERSION_ELEGIDA="${versiones[$((eleccion - 1))]}"
            return 0
        fi
        echo "  Opcion invalida."
    done
}

read_puerto() {
    local default=$1

    while true; do
        read -rp "  ¿En que puerto deseas configurar el servicio? [default: $default]: " puerto
        puerto="${puerto:-$default}"

        if ! [[ "$puerto" =~ ^[0-9]+$ ]]; then
            echo "  Solo se permiten numeros."
            continue
        fi

        if [ "$puerto" -lt 1 ] || [ "$puerto" -gt 65535 ]; then
            echo "  Puerto fuera de rango (1-65535)."
            continue
        fi

        local reservados=(21 22 25 53 110 143 3306 5432 6379 27017 3389 445 139)
        local reservado=false
        for r in "${reservados[@]}"; do
            if [ "$puerto" -eq "$r" ]; then
                echo "  El puerto $puerto esta reservado para otro servicio."
                reservado=true
                break
            fi
        done
        [ "$reservado" = true ] && continue

        if [ "$puerto" -lt 1024 ]; then
            echo "  [ADVERTENCIA] El puerto $puerto es privilegiado (<1024)."
        fi

        PUERTO_ELEGIDO=$puerto
        return 0
    done
}

new_index_html() {
    local servicio=$1
    local version=$2
    local puerto=$3
    local webroot

    case "$servicio" in
    httpd)   webroot="/var/www/httpd" ;;
    nginx)   webroot="/var/www/nginx" ;;
    tomcat*) webroot="/var/lib/${servicio}/webapps/ROOT" ;;
    *)       webroot="/var/www/html" ;;
    esac

    mkdir -p "$webroot"

    cat >"$webroot/index.html" <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>$servicio</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: #f0f2f5;
        }
        .card {
            background: white;
            border-radius: 8px;
            padding: 40px 60px;
            box-shadow: 0 2px 12px rgba(0,0,0,0.1);
            text-align: center;
        }
        h1 { color: #333; margin-bottom: 24px; }
        table { border-collapse: collapse; width: 100%; }
        td { padding: 10px 20px; text-align: left; }
        td:first-child { font-weight: bold; color: #555; }
        tr:nth-child(even) { background: #f9f9f9; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Servidor activo</h1>
        <table>
            <tr><td>Servicio</td><td>$servicio</td></tr>
            <tr><td>Version</td><td>$version</td></tr>
            <tr><td>Puerto</td><td>$puerto</td></tr>
        </table>
    </div>
</body>
</html>
EOF

    echo "[OK] index.html generado en: $webroot/index.html"
}

# Funcion interna: permisos + SELinux sobre un webroot
_fix_webroot() {
    local webroot=$1
    local owner=$2

    mkdir -p "$webroot"
    chmod 755 /var/www
    chmod 755 "$webroot"
    chown -R "$owner" "$webroot"

    if command -v restorecon &>/dev/null; then
        semanage fcontext -a -t httpd_sys_content_t "${webroot}(/.*)?" 2>/dev/null \
            || semanage fcontext -m -t httpd_sys_content_t "${webroot}(/.*)?" 2>/dev/null
        restorecon -Rv "$webroot" &>/dev/null
        echo "[OK] Contexto SELinux aplicado en $webroot."
    fi
}

# Funcion interna: abrir puerto en firewalld si esta activo
_abrir_firewall() {
    local puerto=$1
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port="${puerto}/tcp" &>/dev/null
        firewall-cmd --reload &>/dev/null
        echo "[OK] Puerto $puerto abierto en firewalld."
    fi
}

set_puerto_apache2() {
    local puerto=$1
    local conf="/etc/httpd/conf/httpd.conf"

    # Reemplazar cualquier variante de Listen para escuchar en todas las interfaces
    sed -i "s/^Listen[[:space:]].*/Listen 0.0.0.0:$puerto/" "$conf"
    # Si no habia ninguna linea Listen, agregarla
    grep -q "^Listen" "$conf" || echo "Listen 0.0.0.0:$puerto" >> "$conf"

    _fix_webroot "/var/www/httpd" "apache:apache"

    echo "[OK] Puerto de Apache (httpd) cambiado a $puerto (escuchando en 0.0.0.0)."
    systemctl restart httpd
    echo "[OK] httpd reiniciado."
}

set_puerto_nginx() {
    local puerto=$1
    local conf="/etc/nginx/nginx.conf"

    # Escuchar en todas las interfaces (0.0.0.0)
    sed -i "s/listen[[:space:]]*127\.0\.0\.1:[0-9]*;/listen 0.0.0.0:$puerto;/" "$conf"
    sed -i "s/listen[[:space:]]*[0-9]*;/listen 0.0.0.0:$puerto;/" "$conf"
    sed -i "s/listen[[:space:]]*\[::\]:[0-9]*/listen [::]:$puerto/" "$conf"

    _fix_webroot "/var/www/nginx" "nginx:nginx"

    echo "[OK] Puerto de Nginx cambiado a $puerto (escuchando en 0.0.0.0)."
    systemctl restart nginx
    echo "[OK] Nginx reiniciado."
}

install_servicio() {
    local servicio=$1
    local version=$2
    local puerto=$3

    echo ""
    echo "======================================================"
    echo "  Instalando $servicio $version en puerto $puerto"
    echo "======================================================"

    dnf check-update --quiet

    case "$servicio" in
    httpd)
        if ! dnf install -y "$servicio-$version" 2>/dev/null; then
            echo "[ADVERTENCIA] Version $version no disponible, instalando version actual..."
            dnf install -y httpd
        fi
        systemctl enable httpd
        systemctl start httpd
        sed -i 's|DocumentRoot "/var/www/html"|DocumentRoot "/var/www/httpd"|' /etc/httpd/conf/httpd.conf
        sed -i 's|<Directory "/var/www/html"|<Directory "/var/www/httpd"|' /etc/httpd/conf/httpd.conf
        set_puerto_apache2 "$puerto"
        _abrir_firewall "$puerto"
        ;;
    nginx)
        if ! dnf install -y "nginx-$version" 2>/dev/null; then
            echo "[ADVERTENCIA] Version $version no disponible, instalando version actual..."
            dnf install -y nginx
        fi
        systemctl enable nginx
        systemctl start nginx
        sed -i 's|root[[:space:]]*/usr/share/nginx/html;|root /var/www/nginx;|' /etc/nginx/nginx.conf
        set_puerto_nginx "$puerto"
        _abrir_firewall "$puerto"
        ;;
    tomcat*)
        echo "instalando $servicio-$version" 
        if ! dnf install -y "$servicio-$version" 2>/dev/null; then
            echo "[ADVERTENCIA] Version $version no disponible, instalando version actual..."
            dnf install -y "$servicio"
        fi
        local svc
        svc=$(systemctl list-units --type=service | grep -i tomcat | awk '{print $1}' | head -1)
        if [ -n "$svc" ]; then
            systemctl enable "$svc"
            systemctl start "$svc"
        fi
        set_puerto_tomcat "$puerto"
        _abrir_firewall "$puerto"
        ;;
    esac

    echo ""
    local version_real
    version_real=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}" "$servicio" 2>/dev/null)

    echo "[OK] $servicio instalado correctamente. Version real: $version_real"
    new_index_html "$servicio" "$version_real" "$puerto"
}