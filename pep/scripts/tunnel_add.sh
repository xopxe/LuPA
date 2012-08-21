#!/bin/sh

#xop tocado para wrt
# Crear un tunnel


ipPhyStart=$1
ipPhyEnd=$2
ipVirtStart=$3
ipVirtEnd=$4
name=$5
mode=$6

# Crear la interface tunnel
/usr/sbin/ip tunnel add $name mode $mode remote $ipPhyEnd local $ipPhyStart

# Configurar la interface tunnel con la ip correcta.
/sbin/ifconfig $name $ipVirtStart

# Agregamos ruta con ip virtual destino
/usr/sbin/ip route add $ipVirtEnd/32 dev $name



