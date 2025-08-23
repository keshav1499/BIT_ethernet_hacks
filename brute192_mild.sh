#!/bin/bash
set -e

DEV="enp5s0"
CONN_NAME="static-ethernet"

scan_subnet() {
    SUBNET=$1
    echo "🔎 Scanning $SUBNET.0/24 ..."

    # Fast sweep with fping for alive hosts
    CANDIDATES=($(fping -a -q -g $SUBNET.0 $SUBNET.255 2>/dev/null))
    echo "📌 Found ${#CANDIDATES[@]} alive hosts"

    BEST_GATEWAY=""
    BEST_LAT=999999

    for gw in "${CANDIDATES[@]}"; do
        echo -n "➡️  $gw ... "

        # Replace default route
        sudo ip route replace default via "$gw" dev "$DEV" 2>/dev/null || true

        # Latency check
        LAT=$(ping -c1 -W1 "$gw" 2>/dev/null | awk -F'time=' '/time=/{print $2+0}' | head -n1)
        if [ -z "$LAT" ]; then
            echo "❌ no response"
            continue
        fi

        # Internet check
        if ! ping -c1 -W1 8.8.8.8 >/dev/null 2>&1; then
            echo "⚠️  responds ($LAT ms) but no internet"
            continue
        fi

        # DNS check
        if ! ping -c1 -W1 google.com >/dev/null 2>&1; then
            echo "⚠️  internet works ($LAT ms) but DNS broken"
            continue
        fi

        echo "✅ works ($LAT ms, internet + DNS OK)"
        if (( $(echo "$LAT < $BEST_LAT" | bc -l) )); then
            BEST_LAT=$LAT
            BEST_GATEWAY=$gw
        fi
    done

    if [ -n "$BEST_GATEWAY" ]; then
        echo ""
        echo "🎯 Best gateway in $SUBNET.0/24: $BEST_GATEWAY ($BEST_LAT ms)"
        nmcli connection modify "$CONN_NAME" ipv4.gateway "$BEST_GATEWAY" ipv4.method manual
        nmcli connection up "$CONN_NAME"
        return 0
    else
        echo "❌ No working gateway in $SUBNET.0/24"
        return 1
    fi
}

# --- Run across subnets ---
for i in {0..255}; do
    scan_subnet "192.168.$i"
    if [ $? -eq 0 ]; then
        break
    fi
done
