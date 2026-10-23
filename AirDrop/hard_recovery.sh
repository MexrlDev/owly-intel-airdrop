#!/usr/bin/env bash
# ==============================================================================
# Hard Network Recovery Utility
# Aggressively kills stuck processes and rebuilds the network connection.
# ==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

WIFI_IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -n 1)
if [ -z "$WIFI_IFACE" ]; then
    WIFI_IFACE="wlp3s0"
fi

echo -e "${RED}[!] INITIATING HARD NETWORK RECOVERY...${NC}"
echo -e "${YELLOW}[*] 1. Killing all stuck network and Owly processes...${NC}"
sudo pkill -9 dhclient 2>/dev/null || true
sudo pkill -9 wpa_supplicant 2>/dev/null || true
sudo pkill -9 -f owlyd 2>/dev/null || true
sudo pkill -9 -f "owly receive" 2>/dev/null || true
sudo pkill -9 -f "owly radio" 2>/dev/null || true

echo -e "${YELLOW}[*] 2. Tearing down Owly interfaces gracefully...${NC}"
sudo owly radio down 2>/dev/null || true
sudo owly recover 2>/dev/null || true
sudo ip link set awdl0 down 2>/dev/null || true
sudo iw dev awdl0 del 2>/dev/null || true

echo -e "${YELLOW}[*] 3. Resetting $WIFI_IFACE...${NC}"
sudo ip link set "$WIFI_IFACE" down 2>/dev/null || true
sleep 2
sudo ip link set "$WIFI_IFACE" up 2>/dev/null || true
sudo rfkill unblock all 2>/dev/null || true

echo -e "${YELLOW}[*] 4. Restarting NetworkManager...${NC}"
sudo systemctl restart NetworkManager
sleep 3

echo -e "${YELLOW}[*] 5. Rebuilding Wi-Fi connection...${NC}"
# Try to auto-connect to the known network
sudo nmcli connection up "Net-Router" 2>/dev/null || sudo nmcli device connect "$WIFI_IFACE" 2>/dev/null || true

echo -e "\n${GREEN}[✓] HARD RECOVERY COMPLETE.${NC}"
echo -e "Check your internet. If it's still dead, a full reboot is required."
sleep 2
