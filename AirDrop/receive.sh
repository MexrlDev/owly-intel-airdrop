#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Receiver - Multi-File & Stale-Cleanup Edition
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
RECEIVE_DIR="$SCRIPT_DIR/AirDrop-Received"
RECOVER_SCRIPT="$SCRIPT_DIR/internet_recover.sh"

if [ ! -f "$RECOVER_SCRIPT" ]; then
    echo "Error: $RECOVER_SCRIPT not found. Please reinstall."
    exit 1
fi

mkdir -p "$RECEIVE_DIR"

# Lock to prevent double cleanup
CLEANUP_DONE=0
cleanup() {
    if [ "$CLEANUP_DONE" -eq 1 ]; then return; fi
    CLEANUP_DONE=1
    
    echo -e "\n============================================================"
    echo " CLEANING UP & FIXING PERMISSIONS..."
    echo "============================================================"
    
    # GRACEFUL TEARDOWN TO PREVENT GHOSTS
    sudo owly radio down 2>/dev/null || true
    sudo owly recover 2>/dev/null || true
    
    # FORCE KILL ANY LEFTOVERS
    sudo pkill -9 -f "owly receive" 2>/dev/null || true
    
    # Fix file ownership
    if [ -d "$RECEIVE_DIR" ]; then
        sudo chown -R "$USER":"$USER" "$RECEIVE_DIR"
    fi
    
    # Restore network
    "$RECOVER_SCRIPT"
    
    echo -e "\nReturning to Main Menu..."
    sleep 1
    exit 0
}
trap cleanup EXIT INT TERM

echo "============================================================"
echo " 1. Clearing stale AirDrop advertisements..."
echo "============================================================"
# Aggressively tear down any old awdl0 interface to clear stale mDNS records
sudo pkill -9 -f owlyd 2>/dev/null || true
sudo pkill -9 -f "owly radio" 2>/dev/null || true
sudo owly radio down 2>/dev/null || true
sudo owly recover 2>/dev/null || true
sudo ip link set awdl0 down 2>/dev/null || true
sudo iw dev awdl0 del 2>/dev/null || true
sudo systemctl stop NetworkManager
sleep 2
echo "  [SUCCESS] Stale interfaces cleared."

echo "============================================================"
echo " 2. Starting Owly Radio..."
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
echo " 3. Ready to Receive (Continuous Mode)"
echo "============================================================"
echo "  >>> GO TO YOUR IPHONE AND SHARE FILES VIA AIRDROP <<<"
echo "  >>> YOUR LINUX MACHINE SHOULD APPEAR AS: $(hostname) <<<"
echo "  >>> Press Ctrl+C AT ANY TIME to stop and restore Wi-Fi <<<"
echo "============================================================"

cd "$RECEIVE_DIR" || exit 1

# Count initial files to track new arrivals
INITIAL_COUNT=$(ls -1 | wc -l)

# Infinite loop to keep listening for multiple files
while true; do
    echo -e "\n[Listening...] Waiting for incoming files..."
    
    # Run owly receive. It will exit after a file is transferred or times out.
    sudo owly receive
    
    # Count files after the receive command finishes
    CURRENT_COUNT=$(ls -1 | wc -l)
    
    if [ "$CURRENT_COUNT" -gt "$INITIAL_COUNT" ]; then
        NEW_FILES=$((CURRENT_COUNT - INITIAL_COUNT))
        echo -e "\n  [SUCCESS] Received $NEW_FILES new file(s)!"
        echo "  Returning to listening mode for more files..."
        INITIAL_COUNT=$CURRENT_COUNT
        # Small delay to let the iPhone settle before re-advertising
        sleep 2
    else
        echo -e "\n  [WARN] No files received or transfer failed."
        echo "  Returning to listening mode..."
        sleep 2
    fi
done
