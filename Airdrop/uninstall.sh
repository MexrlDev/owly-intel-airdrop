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
RECEIVE_DIR="$AIRDROP_DIR/AirDrop-Received"

echo -e "${YELLOW}[*] Checking for Owly installation...${NC}"

if ! command -v owly >/dev/null 2>&1 && [ ! -d "$AIRDROP_DIR" ]; then
    echo -e "${GREEN}[✓] Owly AirDrop does not appear to be installed. Nothing to do.${NC}"
    exit 0
fi

echo -e "${RED}[!] WARNING: This will remove Owly, its system services, and the $AIRDROP_DIR folder.${NC}"
read -p "Are you sure you want to uninstall? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 0
fi

# ==============================================================================
# Handle Received Files Safely
# ==============================================================================
if [ -d "$RECEIVE_DIR" ] && [ "$(ls -A "$RECEIVE_DIR")" ]; then
    echo -e "\n${YELLOW}[*] WARNING: You have received files in $RECEIVE_DIR${NC}"
    read -p "Do you want to move these files to your Downloads folder before uninstalling? (Y/n): " KEEP_FILES
    if [[ ! "$KEEP_FILES" =~ ^[Nn]$ ]]; then
        BACKUP_DIR="$HOME/Downloads/AirDrop-Received-Backup-$(date +%Y%m%d-%H%M%S)"
        mv "$RECEIVE_DIR" "$BACKUP_DIR"
        echo -e "${GREEN}[✓] Received files moved to: $BACKUP_DIR${NC}"
    fi
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
