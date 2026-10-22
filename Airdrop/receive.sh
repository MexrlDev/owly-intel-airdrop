#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Receiver
# Listens for incoming AirDrop connections and saves them into a dedicated folder.
# ==============================================================================

# Determine the directory where this script is located (usually ~/AirDrop/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
RECEIVE_DIR="$SCRIPT_DIR/AirDrop-Received"
RECOVER_SCRIPT="$SCRIPT_DIR/internet_recover.sh"

if [ ! -f "$RECOVER_SCRIPT" ]; then
    echo "Error: $RECOVER_SCRIPT not found. Please reinstall."
    exit 1
fi

# Ensure the receive directory exists
mkdir -p "$RECEIVE_DIR"

cleanup() {
    echo -e "\n============================================================"
    echo " CLEANING UP & FIXING PERMISSIONS..."
    echo "============================================================"
    # Since owly runs as root, any received files are owned by root.
    # We must change ownership back to the current user.
    if [ -d "$RECEIVE_DIR" ]; then
        sudo chown -R "$USER":"$USER" "$RECEIVE_DIR"
    fi
    
    # Restore the network
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

# Move into the receive directory so owly drops files there
cd "$RECEIVE_DIR" || { 
    echo "  [FAIL] Could not enter directory $RECEIVE_DIR"; 
    exit 1; 
}

# Run owly receive. This blocks until interrupted.
sudo owly receive

# The trap will trigger cleanup and restore the network when this exits.
