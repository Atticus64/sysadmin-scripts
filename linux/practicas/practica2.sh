
. "./linux/functions_linux.sh"

install_dhcp_server() {

    check_dhcp=$(check_package_present "dhcp-server")
    echo $check_dhcp
}



install_dhcp_server