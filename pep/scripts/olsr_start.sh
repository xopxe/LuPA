#!/bin/sh

echo Iniciando OLSR
pkill olsrd
olsrd -d 0 $1 &

