#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Receiver - Final Stable Version
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
echo " 1. Applying Kernel-Level Fix for Intel ACK Hangs..."
echo "============================================================"
# Disable ack_check to prevent the driver from hanging on ACKs
sudo modprobe -r iwlwifi 2>/dev/null || true
sudo modprobe iwlwifi ack_check=0 2>/dev/null || true
echo "  [SUCCESS] iwlwifi reloaded with ack_check=0."

echo "============================================================"
echo " 2. Starting Owly Radio..."
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
echo " 3. Ready to Receive"
echo "============================================================"
echo "  >>> GO TO YOUR IPHONE/MAC AND SHARE A FILE VIA AIRDROP <<<"
echo "  >>> YOUR LINUX MACHINE SHOULD APPEAR AS: $(hostname) <<<"
echo "  >>> Files will be saved to: $RECEIVE_DIR <<<"
echo "  >>> Press Ctrl+C to stop receiving and restore Wi-Fi <<<"
echo "============================================================"
echo -e "${RED}[!] CRITICAL WARNING:"
echo -e "    After you type 'y' to accept, DO NOT press Ctrl+C for at least"
echo -e "    30 seconds. The Intel card is slow. Let it finish. If the iPhone"
echo -e "    says 'Declined', check the folder anyway; the file is probably there.${NC}"
echo "============================================================"

cd "$RECEIVE_DIR" || { 
    echo "  [FAIL] Could not enter directory $RECEIVE_DIR"; 
    exit 1; 
}

# Run owly receive. This blocks until interrupted by the user.
# The trap will handle cleanup when you press Ctrl+C.
sudo owly receive
