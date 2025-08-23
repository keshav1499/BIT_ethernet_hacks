#!/bin/bash
set -e

DEV="enp5s0"
CONN_NAME="static-ethernet"
TMP_FILE=$(mktemp)

echo "🔎 Scanning 192.168.0.0/16 for possible gateways (this may take a while)..."

# Step 1: Fast sweep with fping (only shows alive hosts)
fping -a -q -g 192.168.0.0 192.168.255.255 2>/dev/null > "$TMP_FILE"

CANDIDATES=($(cat "$TMP_FILE"))
rm "$TMP_FILE"

echo "📌 Found ${#CANDIDATES[@]} alive hosts to test."

BEST_GATEWAY=""
BEST_LAT=999999

# Step 2: Test each candidate
for gw in "${CANDIDATES[@]}"; do
    echo -n "➡️  $gw ... "

    # Replace default route with candidate
    sudo ip route replace default via "$gw" dev "$DEV" 2>/dev/null || true

    # Check latency
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
    echo "🎯 Best working gateway: $BEST_GATEWAY ($BEST_LAT ms)"
    nmcli connection modify "$CONN_NAME" ipv4.gateway "$BEST_GATEWAY" ipv4.method manual
    nmcli connection up "$CONN_NAME"
else
    echo "❌ No working gateway found in 192.168.x.x"
fi
