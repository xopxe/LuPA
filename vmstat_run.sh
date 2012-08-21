
while true
do
	vnstat -i eth0 -tr 5 > /tmp/throughput_eth0.tmp
	mv  /tmp/throughput_eth0.tmp  /tmp/throughput_eth0.txt
	vnstat -i eth1 -tr 5 > /tmp/throughput_eth1.tmp
	mv  /tmp/throughput_eth1.tmp /tmp/throughput_eth1.txt
done

