. "./linux/functions_linux.sh"
# checar si esta instalado un programa llamado cowsay 

check_cowsay() {

  if ! check_package_present cowsay ; then
    sudo dnf install cowsay -y --quiet > /dev/null 2>&1
    if [ $? -ne 0 ]; then   
        echo "Error al instalar cowsay"
        exit 1
    fi          
  else
    echo "[OK] Cowsay ya esta instalado! :)" 
  fi


  cowsay "El server esta andando!"
}


check_cowsay
