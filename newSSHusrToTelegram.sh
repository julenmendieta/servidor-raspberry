#! /bin/bash
# Escript para enviar por telegram las nuevas conexiones al servidor junto con su IP
# Me queda:
# 1-Incluir el supuesto de que se desconecte y conecta alguien al mismo tiempo (el numero de conexiones no cambia)
# 2-Se desconecten dos y conecte uno o al reves

# Direccion al cliente de telegram
telegram=/home/pi/programas/tg/bin/telegram-cli
to=Julen
# Direccion del fichero de control
control=/home/pi/programas/varios/control
# Parece ser que telegram abre nuevas conexiones que aparecen con estado TIME_WAIT al usar netstat, por lo que
# hay que tenerlo en cuenta

# Comprobamos que haya conexiones nuevas cada x segundos
while true
do 
    # Guardamos la cantidad de conexiones SSH que tenemos abiertas
    longi=`w -h | grep "pts/" | wc -l`
    # Siempre que haya usuarios conectados
    if (($longi > 0))
    then
        # Primero comprobamos que haya mayor o menor cantidad de conexiones que en el analisis previo
        previo=`wc -l $control | awk '{print $1}'`
        balance=$((longi - previo))
        # Si el balance es mayor que cero habra alguna conexion nueva
        if (($balance > 0))
        then
            # Por cada nueva linea vamos a recabar los datos y enviar un mensaje (por si se conectan 2 al mismo tiempo)
            for pos in $(seq $longi)
            do
                # Parametros del nuevo usuario conectado
                ip=`netstat -nt | grep "ESTABLISHED" | sed -n ${pos}p | awk '{print $5}'`
                puerto=`w -h | grep "pts/" | sed -n ${pos}p | awk '{print $2}'`
                user=`w -h | grep "pts/" | sed -n ${pos}p | awk '{print $1}'`
                # Comprobamos no haber avisado antes sobre este usuario
                coinci=`grep -c "$user $puerto $ip" $control`
                if [ "$coinci" -eq "0" ]
                then
                    # Si no hay aviso previo mandamos mensaje y guardamos
                    (echo "contact_list";sleep 1;echo "msg $to Usuario $user conectado al puerto $puerto con ip $ip"; echo "safe_quit") |$telegram
                    echo "$user $puerto $ip" >> $control
                fi

            done
        # Si se han perdido usuarios desde la ultima vez
        elif (($balance < 0))
        then
            # Por cada nueva linea vamos a recabar los datos
            longifich=`wc -l $control | awk '{print $1}'`
            for n in $(seq "$longifich")
            do
                # Obtenemos la ip del usuario conectado previamente (suponiendo que no habra ips repetidas)
                ip=`cat $control | sed -n ${n}p | awk '{print $3}'`
                # Buscamos esa IP entre los usuarios conectados
                coinci=`netstat -nt | grep -c "$ip"`
                # Si no hay coincidencia toca eliminarlo e informar de que se ha salido
                if [ "$coinci" -eq "0" ]
                then
                    datos=`cat $control | sed -n ${n}p`
                    (echo "contact_list";sleep 1;echo "msg $to $datos desconectado"; echo "safe_quit") |$telegram
                    grep -v "$datos" $control > $control
                fi
            done
        fi
    fi
    sleep 5
done
