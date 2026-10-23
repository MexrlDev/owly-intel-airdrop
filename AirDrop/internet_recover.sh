#!/usr/bin/env bash
# ==============================================================================
# Internet Recovery Utility
# Stops Owly daemons and restores NetworkManager to its normal state.
# ==============================================================================

echo "============================================================"
echo " RESTORING NETWORK..."
echo "============================================================"

# 1. Kill Owly processes
sudo pkill -f owlyd 2>/dev/null || true
sudo pkill -f owly 2>/dev/null || true

# 2. Tear down the AWDL interface if it exists
sudo ip link set awdl0 down 2>/dev/null || true
sudo iw dev awdl0 del 2>/dev/null || true

# 3. Find the Wi-Fi interface and reset it to managed mode
IFACE=$(iw dev | awk '$1=="Interface"{print $2}' | head -n 1)
if [ -n "$IFACE" ]; then
    sudo ip link set "$IFACE" down 2>/dev/null || true
    sudo iw dev "$IFACE" set type managed 2>/dev/null || true
    sudo ip link set "$IFACE" up 2>/dev/null || true
fi

# 4. Unblock and restart NetworkManager
sudo rfkill unblock all 2>/dev/null || true
sudo systemctl start NetworkManager

echo "  [DONE] Network restored. If you still don't have internet, wait a few seconds."
echo "============================================================"

# Pause briefly so the user can read the success message before the launcher redraws
sleep 2
exit 0
