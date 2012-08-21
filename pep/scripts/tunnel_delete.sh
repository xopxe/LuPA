#!/bin/sh
#xop tocado para wrt
# Borrar un tunnel

tunnelName=$1

# Bajar la interface tunel
/sbin/ifconfig $tunnelName down

# Borrar la interface tunnel
/usr/sbin/ip tunnel del $tunnelName

