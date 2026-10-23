#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Receiver
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
RECEIVE_DIR="$SCRIPT_DIR/AirDrop-Received"
RECOVER_SCRIPT="$SCRIPT_DIR/internet_recover.sh"

if [ ! -f "$RECOVER_SCRIPT" ]; then
    echo "Error: $RECOVER_SCRIPT not found. Please reinstall."
    exit 1
fi

mkdir -p "$RECEIVE_DIR"

# Flag to prevent double cleanup
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
echo " 1. Starting Owly Radio..."
echo "============================================================"
sudo -v
sudo systemctl stop NetworkManager
sudo airmon-ng check kill >/dev/null 2>&1 || true

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
echo " 2. Ready to Receive"
echo "============================================================"
echo "  >>> GO TO YOUR IPHONE/MAC AND SHARE A FILE VIA AIRDROP <<<"
echo "  >>> YOUR LINUX MACHINE SHOULD APPEAR AS: $(hostname) <<<"
echo "  >>> Files will be saved to: $RECEIVE_DIR <<<"
echo "  >>> Press Ctrl+C to stop receiving and restore Wi-Fi <<<"
echo "============================================================"
echo -e "${RED}[!] WARNING: Intel Wi-Fi cards struggle to ACK incoming connections."
echo -e "    If your iPhone shows 'Declined' or 'Waiting' forever, the"
echo -e "    hardware dropped the ACK frame. Retrying or sending FROM Linux"
echo -e "    (Option 1) is much more reliable.${NC}"
echo "============================================================"

cd "$RECEIVE_DIR" || { 
    echo "  [FAIL] Could not enter directory $RECEIVE_DIR"; 
    exit 1; 
}

# Run owly receive. This blocks until interrupted.
sudo owly receive
