. "./linux/functions_linux.sh"

echo "Checar status servidor"

checar_servidor() {
    read -p "Ingrese la IP del servidor remoto: " ip_remota
    read -p "Ingrese el nombre de usuario: " usuario

    echo "checando sistema operativo..."
    SO=$(ssh $usuario@$ip_remota "uname -s" 2>/dev/null)
    STATUS=$?

    if [ $STATUS -eq 0 ] && [ "$SO" = "Linux" ]; then
        #echo "Es Linux"
        ssh $usuario@$ip_remota "$(typeset -f imprimir_info); imprimir_info"
    else
	    ssh $usuario@$ip_remota -C "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \". ([ScriptBlock]::Create([Console]::In.ReadToEnd())); ImprimirInfo\"" < ./windows/functions_windows.ps1 
    fi
}

while true; do
    echo "1. Checar Servidor local"
    echo "2. Checar Servidor remoto"
    echo "3. Salir"
    read -p "Opción: " opcion
    rep=1 

    case $opcion in
        1) imprimir_info ;;
        2) checar_servidor ;;
        3) exit 0 ;;
        *) echo "Opción inválida"; $rep = 0;;
    esac

    if [ $rep -eq 1 ]; then
	exit 0
    fi 

    echo 
done