#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Uninstaller
# ==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

AIRDROP_DIR="$HOME/AirDrop"
RECEIVE_DIR="$AIRDROP_DIR/AirDrop-Received"

echo -e "${YELLOW}[*] Checking for Owly installation...${NC}"

if ! command -v owly >/dev/null 2>&1 && [ ! -d "$AIRDROP_DIR" ]; then
    echo -e "${GREEN}[✓] Owly AirDrop does not appear to be installed.${NC}"
    exit 0
fi

sudo -v

echo -e "${RED}[!] WARNING: This will completely remove Owly from your system.${NC}"
read -p "Are you sure you want to uninstall? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 0
fi

# Backup Received Files
if [ -d "$RECEIVE_DIR" ] && [ "$(ls -A "$RECEIVE_DIR")" ]; then
    echo -e "\n${YELLOW}[*] You have received files in $RECEIVE_DIR${NC}"
    read -p "Move them to ~/Downloads before uninstalling? (Y/n): " KEEP_FILES
    if [[ ! "$KEEP_FILES" =~ ^[Nn]$ ]]; then
        BACKUP_DIR="$HOME/Downloads/AirDrop-Received-Backup-$(date +%Y%m%d-%H%M%S)"
        mv "$RECEIVE_DIR" "$BACKUP_DIR"
        echo -e "${GREEN}[✓] Files moved to: $BACKUP_DIR${NC}"
    fi
fi

echo -e "\n${YELLOW}[*] Stopping and disabling services...${NC}"
sudo systemctl stop owlyd 2>/dev/null || true
sudo systemctl disable owlyd 2>/dev/null || true
sudo pkill -f owlyd 2>/dev/null || true
sudo pkill -f owly 2>/dev/null || true

echo -e "${YELLOW}[*] Hunting down system binaries and configs...${NC}"
# Binaries
sudo rm -f /usr/local/bin/owly /usr/local/bin/owlyd
sudo rm -f /usr/bin/owly /usr/bin/owlyd
sudo rm -f /usr/sbin/owly /usr/sbin/owlyd
sudo rm -f /bin/owly /bin/owlyd

# Systemd
sudo rm -f /etc/systemd/system/owlyd.service
sudo rm -f /lib/systemd/system/owlyd.service
sudo rm -f /usr/lib/systemd/system/owlyd.service

# D-Bus Policies
sudo rm -f /usr/share/dbus-1/system.d/io.github.t4t5.Owly.conf
sudo rm -f /etc/dbus-1/system.d/io.github.t4t5.Owly.conf

echo -e "${YELLOW}[*] Reloading system daemon...${NC}"
sudo systemctl daemon-reload

echo -e "\n${YELLOW}[*] Restoring NetworkManager...${NC}"
sudo rfkill unblock all 2>/dev/null || true
sudo systemctl start NetworkManager

echo -e "\n${YELLOW}[*] Cleaning up local directories and caches...${NC}"
# User directories
rm -rf "$AIRDROP_DIR"
# Caches/Configs
rm -rf "$HOME/.cache/owly" "$HOME/.cache/owlyd" "$HOME/.config/owly" "$HOME/.local/share/owly"
# Temp files
rm -rf /tmp/owly* /tmp/owly-build /tmp/owly-repo-clone /tmp/cargo_build.log

echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN} UNINSTALLATION COMPLETE${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "Owly and all related files have been completely removed."
echo -e "${GREEN}============================================================${NC}"
