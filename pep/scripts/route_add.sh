#!/bin/sh
#xop tocado para wrt

#$1: ip destino ("192.168.0.0")
#$2: numero de bits de mascara ("16")
#$3: gateway ("192.168.0.1")
#$4: interface ("eth0")

echo Route add $1 $2 $3 $4

/usr/sbin/ip r a $1/$2 via $3 dev $4

