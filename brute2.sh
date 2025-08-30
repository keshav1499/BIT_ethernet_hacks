#!/bin/bash

# Dependencies: fping, bc
# Install on Fedora: sudo dnf install fping bc -y

# Subnet range for brute force
#RANGE="172.16.8.0/22"
RANGE="172.16.8.0/22"

echo "🔎 Scanning all possible gateways in $RANGE ..."

# Step 1: Use fping to find all live hosts (parallel, fast)
live_hosts=$(fping -a -q -g $RANGE 2>/dev/null)

if [[ -z "$live_hosts" ]]; then
    echo "❌ No responding hosts found in $RANGE"
    exit 1
fi

echo "✅ Live hosts detected:"
echo "$live_hosts"

best_gw=""
best_ping=9999

# Step 2: Test each live host as a possible gateway
for gw in $live_hosts; do
    echo -n "Testing $gw as gateway ... "

    # Quick latency check
    avg_time=$(ping -c 1 -W 1 $gw 2>/dev/null | awk -F'/' 'END{if ($5!="") print $5; else print 9999}')

    if [[ $avg_time == 9999 ]]; then
        echo "not responsive"
        continue
    fi

    # Step 3: Try internet reachability via this gateway
    ip route replace default via $gw dev enp5s0
    if ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
        echo "works (latency ${avg_time}ms, internet OK)"
        if (( $(echo "$avg_time < $best_ping" | bc -l) )); then
            best_ping=$avg_time
            best_gw=$gw
        fi
    else
        echo "responds locally but no internet"
    fi
done

# Step 4: Save best gateway if found
if [[ -n "$best_gw" ]]; then
    echo
    echo "🎯 Best working gateway: $best_gw (${best_ping}ms)"
    echo "Updating NM connection 'static-ethernet'..."
    nmcli connection modify static-ethernet ipv4.gateway $best_gw
    nmcli connection up static-ethernet
else
    echo "❌ No gateway with internet access found."
fi

#Need a method to attach all found gateways to the 3rd script
#Also need direct integration 

