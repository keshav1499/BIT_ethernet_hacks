#!/bin/bash
set -e

# Candidate gateways you gave me
CANDIDATES=(
172.16.8.1
172.16.8.6
172.16.8.72
172.16.8.179
172.16.8.204
172.16.9.22
172.16.9.112
172.16.9.120
172.16.9.124
172.16.9.163
172.16.10.6
172.16.10.7
172.16.10.8
172.16.10.9
172.16.10.10
172.16.10.11
172.16.10.12
172.16.10.13
172.16.10.14
172.16.10.15
172.16.10.16
172.16.10.17
172.16.10.18
172.16.10.19
172.16.10.20
172.16.10.21
172.16.10.39
172.16.10.40
172.16.10.41
172.16.10.114
172.16.10.147
172.16.10.254
172.16.11.82
172.16.11.122
172.16.11.143
172.16.11.150
172.16.11.154
172.16.11.167
172.16.11.178
172.16.11.200
)

CONN_NAME="static-ethernet"
DEV="enp5s0"

BEST_GATEWAY=""
BEST_LAT=999999

echo "🔎 Testing candidate gateways..."

for gw in "${CANDIDATES[@]}"; do
    echo -n "➡️  $gw ... "

    # Replace default route with candidate
    sudo ip route replace default via "$gw" dev "$DEV" 2>/dev/null || true

    # Step 1: Check if gateway responds
    LAT=$(ping -c1 -W1 "$gw" 2>/dev/null | awk -F'time=' '/time=/{print $2+0}' | head -n1)

    if [ -z "$LAT" ]; then
        echo "❌ no response"
        continue
    fi

    # Step 2: Check internet connectivity
    if ! ping -c1 -W1 218.248.112.193 >/dev/null 2>&1; then
        echo "⚠️  responds ($LAT ms) but no internet"
        continue
    fi

    # Step 3: Check DNS resolution
    if ! ping -c1 -W1 google.com >/dev/null 2>&1; then
        echo "⚠️  internet works ($LAT ms) but DNS broken"
        continue
    fi

    echo "✅ works ($LAT ms, internet + DNS OK)"

    # Track fastest
    if (( $(echo "$LAT < $BEST_LAT" | bc -l) )); then
        BEST_LAT=$LAT
        BEST_GATEWAY=$gw
    fi
done

if [ -n "$BEST_GATEWAY" ]; then
    echo ""
    echo "🎯 Best working gateway: $BEST_GATEWAY ($BEST_LAT ms)"
    echo "🔧 Applying to NetworkManager..."
    nmcli connection modify "$CONN_NAME" ipv4.gateway "$BEST_GATEWAY" ipv4.method manual
    nmcli connection up "$CONN_NAME"
else
    echo "❌ No suitable gateway found"
fi
