#!/bin/bash

# Subnet: 172.16.8.0/22 => 172.16.8.0 - 172.16.11.255
subnets=(172.16.8 172.16.9 172.16.10 172.16.11)

best_gw=""
best_time=9999

echo "Scanning for responsive gateways in 172.16.8.0/22 ..."

for subnet in "${subnets[@]}"; do
    for host in {1..254}; do
        gw="${subnet}.${host}"
        echo -n "Testing $gw ... "

        # ping 1 packet, 1s timeout
        avg_time=$(ping -c 1 -W 1 $gw 2>/dev/null | awk -F'/' 'END{if ($5!="") print $5; else print 9999}')

        if [[ $avg_time != 9999 ]]; then
            echo "responded (${avg_time}ms)"
            if (( $(echo "$avg_time < $best_time" | bc -l) )); then
                best_time=$avg_time
                best_gw=$gw
            fi
        else
            echo "no response"
        fi
    done
done

if [[ -n "$best_gw" ]]; then
    echo
    echo "✅ Best gateway: $best_gw (${best_time}ms)"
    echo "Updating NM connection 'static-ethernet'..."
    nmcli connection modify static-ethernet ipv4.gateway $best_gw
    nmcli connection up static-ethernet
else
    echo "❌ No working gateways found."
fi

