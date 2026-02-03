import subprocess
import os

def checar_plataforma():
    import platform
    sistema = platform.system()
    if sistema == "Windows":
        return "windows"
    elif sistema == "Linux":
        return "linux"
    else:
        return None
    
def script_via_plataforma(plataforma):
    
    if plataforma == "windows":
        ruta_script = os.path.join("windows", "main.ps1")
        comando = ["pwsh.exe", ruta_script]
    elif plataforma == "linux":
        ruta_script = os.path.join("linux", "main.sh")
        comando = ["bash", ruta_script]
    
    return comando

def main():
    print("Menu Principal de Scripts")
    
    print("1. Ejecutar script check_status")
    print("2. Salir")
    opcion = input("Seleccione una opcion: ")
    
    match opcion:
        case "1":
            print("Ejecutando script check_status...")
            plataforma = checar_plataforma()
            comando = script_via_plataforma(plataforma)
            
            subprocess.run(comando)
        case "2":
            print("Saliendo...")   
            exit(0)
            
            
if __name__ == "__main__":
    main()