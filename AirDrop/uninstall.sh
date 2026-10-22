#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Uninstalled
# ==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

AIRDROP_DIR="$HOME/AirDrop"
RECEIVE_DIR="$AIRDROP_DIR/AirDrop-Received"

echo -e "${YELLOW}[*] Checking for Owly installation...${NC}"

# ==============================================================================
# 1. Check if anything is actually installed
# ==============================================================================
if ! command -v owly >/dev/null 2>&1 && [ ! -d "$AIRDROP_DIR" ]; then
    echo -e "${GREEN}[✓] Owly AirDrop does not appear to be installed. Nothing to do.${NC}"
    exit 0
fi

# Cache sudo upfront to prevent mid-script timeouts
sudo -v
if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Error: Sudo access is required to uninstall system services.${NC}"
    exit 1
fi

# ==============================================================================
# 2. Confirmation Prompt
# ==============================================================================
echo -e "${RED}[!] WARNING: This will remove Owly, its system services, and the $AIRDROP_DIR folder.${NC}"
read -p "Are you sure you want to uninstall? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 0
fi

# ==============================================================================
# 3. Backup Received Files (Safety First)
# ==============================================================================
if [ -d "$RECEIVE_DIR" ] && [ "$(ls -A "$RECEIVE_DIR")" ]; then
    echo -e "\n${YELLOW}[*] WARNING: You have received files in $RECEIVE_DIR${NC}"
    read -p "Do you want to move these files to your Downloads folder before uninstalling? (Y/n): " KEEP_FILES
    if [[ ! "$KEEP_FILES" =~ ^[Nn]$ ]]; then
        BACKUP_DIR="$HOME/Downloads/AirDrop-Received-Backup-$(date +%Y%m%d-%H%M%S)"
        mv "$RECEIVE_DIR" "$BACKUP_DIR"
        echo -e "${GREEN}[✓] Received files safely moved to: $BACKUP_DIR${NC}"
    fi
fi

# ==============================================================================
# 4. Stop and Remove System Services
# ==============================================================================
echo -e "\n${YELLOW}[*] Stopping and disabling services...${NC}"
sudo systemctl stop owlyd 2>/dev/null || true
sudo systemctl disable owlyd 2>/dev/null || true
sudo pkill -f owlyd 2>/dev/null || true
sudo pkill -f owly 2>/dev/null || true

echo -e "${YELLOW}[*] Removing system binaries and config files...${NC}"
# Remove binaries from common paths
sudo rm -f /usr/local/bin/owly /usr/local/bin/owlyd
sudo rm -f /usr/bin/owly /usr/bin/owlyd

# Remove systemd service and D-Bus policies
sudo rm -f /etc/systemd/system/owlyd.service
sudo rm -f /lib/systemd/system/owlyd.service
sudo rm -f /usr/share/dbus-1/system.d/io.github.t4t5.Owly.conf

echo -e "${YELLOW}[*] Reloading system daemon...${NC}"
sudo systemctl daemon-reload

# ==============================================================================
# 5. Restore NetworkManager
# ==============================================================================
echo -e "\n${YELLOW}[*] Restoring NetworkManager...${NC}"
sudo rfkill unblock all 2>/dev/null || true
sudo systemctl start NetworkManager

# ==============================================================================
# 6. Cleanup Local Directories and Temp Files
# ==============================================================================
echo -e "\n${YELLOW}[*] Removing ~/AirDrop directory...${NC}"
if [ -d "$AIRDROP_DIR" ]; then
    rm -rf "$AIRDROP_DIR"
    echo -e "${GREEN}[✓] Removed $AIRDROP_DIR${NC}"
else
    echo -e "${GREEN}[✓] $AIRDROP_DIR already removed.${NC}"
fi

echo -e "${YELLOW}[*] Cleaning up temporary build files...${NC}"
rm -rf /tmp/owly-build /tmp/owly-repo-clone /tmp/owly_radio.log /tmp/owly_browse.log /tmp/cargo_build.log

# ==============================================================================
# 7. Completion
# ==============================================================================
echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN} UNINSTALLATION COMPLETE${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "Owly and all related services have been removed."
echo -e "Your normal Wi-Fi connection has been restored."
echo -e "${GREEN}============================================================${NC}"
