#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Receiver
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
echo "  >>> Press Ctrl+C to stop receiving and restore Wi-Fi <<<"
echo "============================================================"
echo -e "${RED}[!] CRITICAL WARNING FOR INTEL CARDS:"
echo -e "    After you type 'y' to accept a file, DO NOT press Ctrl+C!"
echo -e "    The Intel card needs 10-15 seconds to send the ACK back to"
echo -e "    the iPhone. If you hit Ctrl+C, the iPhone will show 'Declined'."
echo -e "    Wait until the file is fully saved.${NC}"
echo "============================================================"

cd "$RECEIVE_DIR" || exit 1

ATTEMPT=1
MAX_ATTEMPTS=5

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo -e "\n[Attempt $ATTEMPT/$MAX_ATTEMPTS] Listening..."
    
    # Increased timeout to 180s to give the ACK plenty of time to go through
    timeout 180s sudo owly receive
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 124 ]; then
        echo -e "\n  [WARN] Receiver timed out. Restarting..."
        ATTEMPT=$((ATTEMPT + 1))
    elif [ $EXIT_CODE -ne 0 ]; then
        echo -e "\n  [WARN] Receiver stopped (Code: $EXIT_CODE). Restarting..."
        ATTEMPT=$((ATTEMPT + 1))
        sleep 2
    else
        break
    fi
done

echo -e "\n  [DONE] Receiver stopped."
