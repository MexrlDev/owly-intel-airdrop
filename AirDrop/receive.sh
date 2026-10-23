#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Receiver (Intel 8265 Fix)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
RECEIVE_DIR="$SCRIPT_DIR/AirDrop-Received"
RECOVER_SCRIPT="$SCRIPT_DIR/internet_recover.sh"

if [ ! -f "$RECOVER_SCRIPT" ]; then
    echo "Error: $RECOVER_SCRIPT not found."
    exit 1
fi

mkdir -p "$RECEIVE_DIR"

CLEANUP_DONE=0
cleanup() {
    if [ "$CLEANUP_DONE" -eq 1 ]; then return; fi
    CLEANUP_DONE=1
    echo -e "\n============================================================"
    echo " CLEANING UP & FIXING PERMISSIONS..."
    echo "============================================================"
    if [ -d "$RECEIVE_DIR" ]; then
        sudo chown -R "$USER":"$USER" "$RECEIVE_DIR"
    fi
    "$RECOVER_SCRIPT"
}
trap cleanup EXIT INT TERM

echo "============================================================"
echo " 1. HARD RESETTING WI-FI STATE..."
echo "============================================================"
sudo pkill -9 -f owlyd 2>/dev/null || true
sudo pkill -9 -f wpa_supplicant 2>/dev/null || true
sudo ip link set awdl0 down 2>/dev/null || true
sudo iw dev awdl0 del 2>/dev/null || true
sudo systemctl stop NetworkManager
sleep 2

# Find the main Wi-Fi interface
WIFI_IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -n 1)

echo "============================================================"
echo " 2. DISABLING POWER SAVING & OFFLOADING (Crucial for Intel)..."
echo "============================================================"
if [ -n "$WIFI_IFACE" ]; then
    sudo iw dev "$WIFI_IFACE" set power_save off 2>/dev/null || true
    sudo ethtool -K "$WIFI_IFACE" tx off rx off tso off gso off gro off lro off 2>/dev/null || true
    echo "  [SUCCESS] Hardware offloading disabled on $WIFI_IFACE."
fi

echo "============================================================"
echo " 3. Starting Owly Radio..."
echo "============================================================"
sudo -v
sudo systemctl start owlyd
sleep 2
sudo owly radio up > /tmp/owly_radio.log 2>&1 &
sleep 4

if ! ip link show awdl0 >/dev/null 2>&1; then
    echo "  [FAIL] awdl0 interface did not come up."
    cat /tmp/owly_radio.log
    exit 1
fi
echo "  [SUCCESS] awdl0 is up."

echo "============================================================"
echo " 4. Ready to Receive"
echo "============================================================"
echo "  >>> GO TO YOUR IPHONE/MAC AND SHARE A FILE VIA AIRDROP <<<"
echo "  >>> YOUR LINUX MACHINE SHOULD APPEAR AS: $(hostname) <<<"
echo "============================================================"
echo -e "${RED}[!] CRITICAL WARNING:"
echo -e "    Press 'y' to accept. If it hangs, DO NOT PANIC."
echo -e "    The script now has a 60-second hardware watchdog."
echo -e "    It will automatically kill the stuck process and"
echo -e "    restore your network.${NC}"
echo "============================================================"

cd "$RECEIVE_DIR" || exit 1

ATTEMPT=1
MAX_ATTEMPTS=5

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo -e "\n[Attempt $ATTEMPT/$MAX_ATTEMPTS] Listening..."
    
    # The Watchdog: 60 second timeout. If it hangs, force kill it (-s KILL).
    timeout -s KILL 60s sudo owly receive
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 137 ]; then
        echo -e "\n  [HARDWARE TIMEOUT] The Intel card deadlocked and was killed."
        echo -e "  Check the folder anyway, the file might have made it!"
        ATTEMPT=$((ATTEMPT + 1))
        sleep 2
    elif [ $EXIT_CODE -ne 0 ]; then
        echo -e "\n  [WARN] Receiver stopped (Code: $EXIT_CODE). Restarting..."
        ATTEMPT=$((ATTEMPT + 1))
        sleep 2
    else
        break
    fi
done

echo -e "\n  [DONE] Receiver stopped."
