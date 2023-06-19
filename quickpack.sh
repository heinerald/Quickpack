#!/bin/bash
# programa para utilidades de seridor
#Autor: Heiner Aldana, Paula Diaz, Juan Araque
opcion=0
fechaActual=`date +%Y%m%d`

# Función para instalar paquetes basicos
instalar_basico () {
    echo -e "\n Instalando componentes"
    echo -e "\n"
    read -s -p "Ingresar contraseña de sudo:" password
    echo "$password" | sudo -S apt update
    # Consultar programas de seguridad (lynis, ufw, fail2ban, crontab, ssh y  configuraciónes)
    echo "$password" | sudo -S apt-get -y install htop  lynis ufw fail2ban
    echo -e "\n Instalación completa"
}

# Función lynis auditoria
lynis () {
    echo -e "\n Lynis se esta ejecutando ...."
    echo -e "\n"
    read -s -p "Ingresar contraseña de sudo:" password
    spin & pid=$!
    #verifica la existencia de audit_lynis.txt para crear el archivo
    verifylogLynis=$(which audit_lynis.txt)
    if [ $? -eq 0 ]; then
        touch audit_lynis.txt
    else
       echo -e "\n"   
    fi
    #crea el archivo audit_lynis.txt
    echo "$password" | sudo -S lynis audit system > audit_lynis.txt
    kill $pid
    echo "Se creo el archivo audit_lynis.txt, puedes ver los resultados del diagnostivo"
}

#función ssh
ssh_funcion(){
    nuevo=22
    read -p "Ingresar puerto a cambiar: " nuevo
    salida=$(grep "Port " /etc/ssh/sshd_config)
    sudo cp "/etc/ssh/sshd_config" "/etc/ssh/sshd_config_backup"
    echo "$salida-----------------------"
    if [ $nuevo -ge 1024 ] && [ $nuevo -le 6553 ] ; then
        if grep -Fxq "${salida}" /etc/ssh/sshd_config
        then
            sudo sed -i -e "s/${salida}/Port ${nuevo}/" /etc/ssh/sshd_config
        else
            sudo sed -i -e "s/${salida}/Port ${nuevo}/" /etc/ssh/sshd_config
        fi
        sudo /etc/init.d/ssh start
        sudo /etc/init.d/sshd restart
        sudo netstat -tlpn

    elif [ $nuevo == 22 ]; then
        if grep -Fxq "${salida}" /etc/ssh/sshd_config
        then
            sudo sed -i "s/${salida}/Port ${nuevo}/" /etc/ssh/sshd_config
        else
            sudo sed -i "s/${salida}/Port ${nuevo}/" /etc/ssh/sshd_config
        fi
        sudo /etc/init.d/ssh start
        sudo /etc/init.d/sshd restart
        sudo netstat -tlpn
    else
        echo "Sustituya por un puerto entre 1024 y 65536 o por defecto el 22"
    fi
}

#funcion para cambiar de valor de Swap
swap_funcion(){
    clear
    echo "Porcentaje actual de prioridad 1-100 de la memoria swap: "
    #uso de la memoria swap
    swapactual=$(cat /proc/sys/vm/swappiness)
    echo "Uso actual % de swap: $swapactual "
    echo -e "\n"
    echo "Se recomienda mantener un uso entre el 10% y 60%"
    echo -e "\n"
    read -p "Ingrese el porcentaje de memoria para comenzar a usar SWAP: " nuevop

    if [ $nuevop -ge 10 ] && [ $nuevop -le 60 ] ; then
        echo -e "\n"
        #read -n2 -p "cambio permanente  s(si), cambio parcial n(no) " permanente
        read -n2 -p "solo se realizara un cambio parcial s(si) " permanente

        # if [ $permanente = "s" ]; then
        #     sudo sysctl -w vm.swappiness=$nuevop
        # elif [ $permanente = "n" ] ; then
        #     sudo sysctl -w vm.swappiness=$nuevop
        # else
        #     echo "No es valido"
        # fi
        if [ $permanente = "s" ] || [ $permanente = "S" ]; then
            sudo sysctl -w vm.swappiness=$nuevop
        else
            echo "No es valido"
        fi
        echo "Uso actual % de swap: $swapactual "
    else
        echo "Solo se permiten ingresar valores entre el 10% y 60% para el uso de swap"
    fi
}

#funcion de inicio de UFW
ufw_funcion_init(){
    estado=$(sudo ufw status)
    echo "Estado del servicio: $estado"
    if [[ $estado == *"inactive"* ]]; then
        echo "Tenga cuidado de hacer uso de QuickPack en conexiones remotas, puede deshabilitar puertos y perder la conexion"
        read -p "Desea encender el firewall? s(si) o n(no): " encender
        if [ $encender = "s" ] || [ $encender = "S" ]; then
            sudo ufw enable
        else
            echo "ufw inactivo"
        fi
    else 
        read -p "Desea apagar el firewall? s(si) o n(no)" apagar
        if [ $apagar = "s" ] || [ $apagar = "S" ]; then
            sudo ufw disable
        else
            echo "ufw activo"
        fi
    fi
}

#funcion para la configuracion basica de UFW
ufw_funcion(){
    estado=$(sudo ufw status)
    if [[ $estado == *"inactive"* ]]; then
        ufw_funcion_init
    else 
        read -p "Desea habilitar A(si) o deshabilitar D(no) un puerto: " opcion
         if [ $opcion = "a" ] || [ $opcion = "A" ]; then
            read -p "indique el puerto a habilitar: " puertoa
            sudo ufw allow $puertoa
            echo "$puertoa puesto habilitado"
        elif [ $opcion = "d" ] || [ $opcion = "D" ]; then
            read -p "indique el puerto a deshabilitar: " puertod
            sudo ufw deny $puertod
            echo "$puertod puesto deshabilitado"
        else 
            echo "no es valido"
        fi
        sudo ufw status
    fi

}

#funcion de inicio basica de fail2ban
fali2ban_funcion_init(){
    ruta=/etc/fail2ban
    sudo cp "$ruta/jail.conf" "$ruta/jail.conf_backup"

    estado=$(sudo /etc/init.d/fail2ban status)
    echo "Estado del servicio: $estado"
    if [[ $estado == *"inactive"* ]]; then
        read -p "Desea encender el fail2ban? s(si) o n(no): " encender
        if [ $encender = "s" ] || [ $encender = "S" ]; then
            sudo /etc/init.d/fail2ban start
        else
            echo "fail2ban inactivo"
        fi
    else 
        read -p "Desea apagar el firefail2banwall? s(si) o n(no)" apagar
        if [ $apagar = "s" ] || [ $apagar = "S" ]; then
            sudo /etc/init.d/fail2ban stop
        else
            echo "fail2ban activo"
        fi
    fi

}

periodo_val_fail2ban(){
    salida=$(grep "findtime =" /etc/fail2ban/jail.d/defaults-debian.conf)
    read -n2 -p "Ingrese el timepo de baneo : " tiempop
    if [[ $salida == *"findtime ="* ]]; then
        sudo sed -i -e "s/${salida}/findtime = ${tiempop}/" /etc/fail2ban/jail.d/defaults-debian.conf
    else
        sudo sh -c "echo 'findtime = ${tiempop}' >> /etc/fail2ban/jail.d/defaults-debian.conf"
    fi
    /etc/init.d/fail2ban restart
}
baneo_fail2ban(){
    salida=$(grep "bantime =" /etc/fail2ban/jail.d/defaults-debian.conf)    
    #salida=$(grep "findtime =" /etc/fail2ban/jail.d/defaults-debian.conf)
    read -n2 -p "Ingrese el timepo de baneo : " tiempob
    if [[ $salida == *"bantime ="* ]]; then
        sudo sed -i -e "s/${salida}/bantime = ${tiempob}/" /etc/fail2ban/jail.d/defaults-debian.conf
    else
        sudo sh -c "echo 'bantime = ${tiempob}' >> /etc/fail2ban/jail.d/defaults-debian.conf"
    fi
    /etc/init.d/fail2ban restart
}
intentos_fail2ban(){
    salida=$(grep "maxentry =" /etc/fail2ban/jail.d/defaults-debian.conf)
    read -n2 -p "Ingrese los inentos maximos de acceso: " intentos
    if [[ $salida == *"maxentry ="* ]]; then
        sudo sed -i -e "s/${salida}/maxentry = ${intentos}/" /etc/fail2ban/jail.d/defaults-debian.conf
    else
        sudo sh -c "echo 'maxentry = ${intentos}' >> /etc/fail2ban/jail.d/defaults-debian.conf"
    fi
    /etc/init.d/fail2ban restart
}

#funcion para la configuracion basica de fail2ban
fali2ban_funcion(){
    ruta=/etc/fail2ban
    sudo cp "$ruta/jail.conf" "$ruta/jail.conf_backup"

    estado=$(sudo /etc/init.d/fail2ban status)
    if [[ $estado == *"inactive"* ]]; then
        fali2ban_funcion_init
    else 
        echo "1. configurar intentos"
        echo "2. configurar tiempo de baneo"
        echo "3. configurar periodo de validación"
        echo "4. regresar"
        read -n1 -p "--Ingrese una opción [1-4]" resp
        case $resp in
            1)
                echo -e "\n"
                intentos_fail2ban
                #tail -100f /var/log/fail2ban.log;;
                sleep 2
                ;;
            2) 
                echo -e "\n"
                baneo_fail2ban
                sleep 2
                ;;
            3) 
                echo -e "\n"
                periodo_val_fail2ban
                sleep 2
                ;;
            4) 
                echo -e "\n"
                echo "saliendo"
                ;;
        esac
    fi
    # lnav /var/log/fail2ban.log
}

# Función spin
spinner=( 0ooo o0ooo ooo0o )
spin () {
    while :
    do
        # for i in "${spinner[@]}"
        # do
        #     echo -ne "\r$i"
        #     sleep 0.2
        # done
        for i in "${spinner[@]}"
          do
            clear
            echo "███████▀▀▀░░░░░░░▀▀▀███████"
            echo "████▀░░░░░░░░░░░░░░░░░▀████"
            echo "███│░░░░░░░░░░░░░░░░░░░│███"
            echo "██▌│░░░░░░░░░░░░░░░░░░░│▐██"
            echo "██░└┐░░░░░░░░░░░░░░░░░┌┘░██"
            echo "██░░└┐░░░░░░░░░░░░░░░┌┘░░██"
            echo "██░░┌┘     ░░░░░     └┐░░██"
            echo "███░│      ░░ ░░      │░███"
            echo "██▀─┘░░░░░░░   ░░░░░░░└─▀██"
            echo "██▄░░░    ░░   ░░    ░░░▄██"
            echo "████▄─┘   ░░░░░░░   └─▄████"
            echo "█████░░  ─┬┬┬┬┬┬┬─  ░░█████"
            echo "████▌░░░ ┬┼┼┼┼┼┼┼  ░░░▐████"
            echo "█████▄░░░└┴┴┴┴┴┴┴┘░░░▄█████"
            echo "███████▄░░░░░░░░░░░▄███████"
            echo "██████████▄▄▄▄▄▄▄██████████"
            echo "LOADING...LOADING...LOADING"
            sleep 0.3
            clear
            echo "███████▀▀▀░░░░░░░▀▀▀███████"
            echo "████▀░░░░░░░░░░░░░░░░░▀████"
            echo "███│░░░░░░░░░░░░░░░░░░░│███"
            echo "██▌│░░░░░░░░░░░░░░░░░░░│▐██"
            echo "██░└┐░░░░░░░░░░░░░░░░░┌┘░██"
            echo "██░░└┐░░░░░░░░░░░░░░░┌┘░░██"
            echo "██░░┌┘▄▄▄▄▄░░░░░▄▄▄▄▄└┐░░██"
            echo "███░│▐███▀▀░░▄░░▀▀███▌│░███"
            echo "██▀─┘░░░░░░░▐█▌░░░░░░░└─▀██"
            echo "██▄░░░▄▄▄▓░░▀█▀░░▓▄▄▄░░░▄██"
            echo "████▄─┘██▌░░░░░░░▐██└─▄████"
            echo "█████░░▐█─┬┬┬┬┬┬┬─█▌░░█████"
            echo "████▌░░░▀┬┼┼┼┼┼┼┼┬▀░░░▐████"
            echo "█████▄░░░└┴┴┴┴┴┴┴┘░░░▄█████"
            echo "███████▄░░░░░░░░░░░▄███████"
            echo "██████████▄▄▄▄▄▄▄██████████"
            echo ".....LOADING.....LOADING..."
            sleep 0.3
            clear
        done
    done
}

#MENU1
while :
do
    #Limpiar la pantalla
    clear
    #Desplegar el menú de opciones
    echo "░██████╗░██╗░░░██╗██╗░█████╗░██╗░░██╗██████╗░░█████╗░░█████╗░██╗░░██╗"
    echo "██╔═══██╗██║░░░██║██║██╔══██╗██║░██╔╝██╔══██╗██╔══██╗██╔══██╗██║░██╔╝"
    echo "██║██╗██║██║░░░██║██║██║░░╚═╝█████═╝░██████╔╝███████║██║░░╚═╝█████═╝░"
    echo "╚██████╔╝██║░░░██║██║██║░░██╗██╔═██╗░██╔═══╝░██╔══██║██║░░██╗██╔═██╗░"
    echo "░╚═██╔═╝░╚██████╔╝██║╚█████╔╝██║░╚██╗██║░░░░░██║░░██║╚█████╔╝██║░╚██╗"
    echo "░░░╚═╝░░░░╚═════╝░╚═╝░╚════╝░╚═╝░░╚═╝╚═╝░░░░░╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝"
    echo "            Programa de utilidad para servidores Ubuntu LTS-20.04"
    echo "_____________________________________________________________________"
    echo "___________________________MENÚ PRINCIPAL____________________________"
    echo "1. Instalación basica de htop, lynis, ufw y fail2ban:"
    echo "2. Configuración Puerto SSH: "
    echo "3. Configuración swap: "
    echo "4. Activación y apagado de ufw (ubuntu-firewall): "
    echo "5. Configuración ufw (ubuntu-firewall): "
    echo "6. Activación y apagado fail2ban: "
    echo "7. Configuración fail2ban: "
    echo "8. Escaneo de seguridad con Lynis: "
    echo "9. Salir"
    #Leer los datos del usuario - capturar información
    read -n1 -p "--Ingrese una opción [1-9]: " opcion
    #Validar la opción ingresada
    case $opcion in
       1)
            echo -e "\n"
            instalar_basico
            sleep 3
            ;;
        2) 
            echo -e "\n"
            ssh_funcion
            sleep 3
            ;;
        3) 
            echo -e "\n"
            swap_funcion
            sleep 3
            ;;
        4) 
            echo -e "\n"
            ufw_funcion_init
            sleep 3
            ;;
        5) 
            echo -e "\n"
            ufw_funcion
            sleep 3
            ;;
        6) 
            echo -e "\n"
            fali2ban_funcion_init
            sleep 3
            ;;
        7) 
            echo -e "\n"
            fali2ban_funcion
            sleep 3
            ;;
                        
        8) 
            echo -e "\n"
            echo -e "\nLynis se esta ejecutando" 
            lynis
            sleep 3
            ;;
        9)  
            echo -e "\n"
            echo "Salir del Programa"
            exit 0
            ;;
    esac
done