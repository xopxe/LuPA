#!/bin/bash

HIGHER_AP=8
LOWER_AP=0

if [ -z $1 ]
then
    echo "Bad invocation."
    echo "Invocation : /bin/bash start_pricing_ap.sh [AP number]"
    echo "Terminating"
    exit 1
fi

if (( (($1 > $HIGHER_AP)) || (($1 < $LOWER_AP)) ))
then
    echo "Bad parameter."
    echo "AP number must be between" $LOWER_AP "and" $HIGHER_AP "." 
    echo "Terminating"
    exit 2
fi

LUPA_VE="examples/pricing/config_pricing_ap"$1"ve.txt"
LUPA="examples/pricing/config_pricing_ap"$1".txt"
LOCALSTATE="../pricing/ap/localStateManteiner.lua"

if ! [[ -e $LUPA_VE ]]
then
    echo "Bad argument."
    echo "LUPA's ValuesToEvents config file "$LUPA_VE" was not found." 
    echo "Terminating"
    exit 3
fi

if ! [[ -e $LUPA  ]]
then
    echo "Bad argument."
    echo "LUPA's config file "$LUPA_VE" was not found." 
    echo "Terminating"
    exit 4
fi

if ! [[ -e $LOCALSTATE  ]]
then
    echo "File not found."
    echo "Local State Manteiner "$LOCALSTATE" was not found." 
    echo "Terminating"
    exit 5
fi

localStateManteinerPort="909"$1

com_apve="lua init.lua "$LUPA_VE
com_ap="lua init.lua "$LUPA
com_localstate="lua "$LOCALSTATE" "$localStateManteinerPort

echo "Running:" $com_apve
$com_apve &
pid_apve=$!

echo "Running:" $com_ap
$com_ap &
pid_ap=$!

echo "Running:" $com_localstate
$com_localstate &

echo "Press ENTER to finish execution."
read pepe

kill $pid_apve
kill $pid_ap

echo SHUTDOWN | netcat -w 1 -u 127.0.0.1 $localStateManteinerPort 

echo "Execution OK. Finished."

exit 0



