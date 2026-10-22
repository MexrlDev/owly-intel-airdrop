#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Uninstaller
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

AIRDROP_DIR="$HOME/AirDrop"

echo -e "${YELLOW}[*] Checking for Owly installation...${NC}"

# Check if anything is installed
if ! command -v owly >/dev/null 2>&1 && [ ! -d "$AIRDROP_DIR" ]; then
    echo -e "${GREEN}[✓] Owly AirDrop does not appear to be installed. Nothing to do.${NC}"
    exit 0
fi

echo -e "${RED}[!] WARNING: This will remove Owly, its system services, and $AIRDROP_DIR.${NC}"
read -p "Are you sure you want to uninstall? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 0
fi

echo -e "\n${YELLOW}[*] Stopping services...${NC}"
sudo systemctl stop owlyd 2>/dev/null || true
sudo systemctl disable owlyd 2>/dev/null || true

echo -e "\n${YELLOW}[*] Removing system files...${NC}"
sudo rm -f /usr/local/bin/owly /usr/local/bin/owlyd
sudo rm -f /etc/systemd/system/owlyd.service
sudo rm -f /usr/share/dbus-1/system.d/io.github.t4t5.Owly.conf
sudo systemctl daemon-reload

echo -e "\n${YELLOW}[*] Restoring NetworkManager...${NC}"
sudo systemctl start NetworkManager

echo -e "\n${YELLOW}[*] Removing ~/AirDrop directory...${NC}"
if [ -d "$AIRDROP_DIR" ]; then
    rm -rf "$AIRDROP_DIR"
    echo -e "${GREEN}[✓] Removed $AIRDROP_DIR${NC}"
fi

echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN} UNINSTALLATION COMPLETE${NC}"
echo -e "${GREEN}============================================================${NC}"
