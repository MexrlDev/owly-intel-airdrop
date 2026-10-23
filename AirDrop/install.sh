#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Installer for Linux (Intel Wireless Cards)
# ==============================================================================

trap 'echo -e "\n\n[!] Installation cancelled by user."; exit 130' INT

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

AIRDROP_DIR="$HOME/AirDrop"
OWLY_BUILD_DIR="/tmp/owly-build"
TEMP_CLONE_DIR="/tmp/owly-repo-clone"
REPO_URL="https://github.com/MexrlDev/owly-intel-airdrop.git"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

if [ -f "$AIRDROP_DIR/launcher.sh" ]; then
    echo -e "${GREEN}[✓] Owly AirDrop is already installed at $AIRDROP_DIR${NC}"
    read -p "Do you want to launch the main menu? (y/N): " RUN_NOW
    if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
        "$AIRDROP_DIR/launcher.sh"
    fi
    exit 0
fi

echo -e "${YELLOW}[*] Starting Owly AirDrop installation...${NC}"

if [ ! -t 1 ]; then
    echo -e "${RED}[!] Error: This script must be run from an interactive terminal.${NC}"
    exit 1
fi

WIFI_IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -n 1)
if [ -z "$WIFI_IFACE" ]; then
    echo -e "${RED}[!] Error: No wireless interface found.${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Detected wireless interface: $WIFI_IFACE${NC}"

sudo -v

echo -e "\n${YELLOW}[*] Installing build dependencies...${NC}"
sudo apt-get update -qq
sudo apt-get install -y build-essential cmake pkg-config libssl-dev libpcap-dev libev-dev libnl-3-dev libnl-genl-3-dev libnl-route-3-dev curl git network-manager aircrack-ng > /dev/null

if ! command -v rustc >/dev/null 2>&1; then
    echo -e "\n${YELLOW}[*] Installing Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null
    source "$HOME/.cargo/env"
else
    echo -e "${GREEN}[✓] Rust is already installed.${NC}"
fi

echo -e "\n${YELLOW}[*] Cloning and compiling Owly...${NC}"
rm -rf "$OWLY_BUILD_DIR"
git clone https://github.com/t4t5/owly.git "$OWLY_BUILD_DIR" > /dev/null
cd "$OWLY_BUILD_DIR"
source "$HOME/.cargo/env" 2>/dev/null || true

echo -e "${YELLOW}[*] Compiling (This takes 5-15 minutes)...${NC}"
cargo build --release --locked -p owlyd -p owly-cli > /tmp/cargo_build.log 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Error: Compilation failed. See log below:${NC}"
    tail -n 20 /tmp/cargo_build.log
    exit 1
fi

echo -e "${YELLOW}[*] Installing system files...${NC}"
sudo packaging/install.sh owly > /dev/null
sudo systemctl daemon-reload

echo -e "\n${YELLOW}[*] Setting up ~/AirDrop directory...${NC}"
mkdir -p "$AIRDROP_DIR"
mkdir -p "$AIRDROP_DIR/AirDrop-Received"

# DYNAMIC FILE COPYING
if [ -f "$REPO_DIR/launcher.sh" ]; then
    # Copy EVERYTHING in the local AirDrop folder
    cp -r "$REPO_DIR/"* "$AIRDROP_DIR/"
    # Try to grab README from parent dir (repo root) or local dir
    cp "$REPO_DIR/../README.md" "$AIRDROP_DIR/" 2>/dev/null || cp "$REPO_DIR/README.md" "$AIRDROP_DIR/" 2>/dev/null || true
else
    # Clone repo to get all files
    rm -rf "$TEMP_CLONE_DIR"
    git clone "$REPO_URL" "$TEMP_CLONE_DIR" > /dev/null
    cp -r "$TEMP_CLONE_DIR/AirDrop/"* "$AIRDROP_DIR/"
    # Try to grab README from repo root or AirDrop folder
    cp "$TEMP_CLONE_DIR/README.md" "$AIRDROP_DIR/" 2>/dev/null || cp "$TEMP_CLONE_DIR/AirDrop/README.md" "$AIRDROP_DIR/" 2>/dev/null || true
    rm -rf "$TEMP_CLONE_DIR"
fi

# Ensure ALL .sh files are executable
find "$AIRDROP_DIR" -name "*.sh" -exec chmod +x {} \;

rm -rf "$OWLY_BUILD_DIR"

echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN} INSTALLATION COMPLETE${NC}"
echo -e "${GREEN}============================================================${NC}"

echo "What would you like to do now?"
echo "  [1] Send a File (airdrop.sh)"
echo "  [2] Receive a File (receive.sh)"
echo "  [3] Launch Main Menu (launcher.sh)"
echo "  [4] Exit"
read -p "Select option [1-4] < " POST_INSTALL

case "$POST_INSTALL" in
    1) "$AIRDROP_DIR/airdrop.sh" ;;
    2) "$AIRDROP_DIR/receive.sh" ;;
    3) "$AIRDROP_DIR/launcher.sh" ;;
    *) echo "Exiting. Run ~/AirDrop/launcher.sh anytime." ;;
esac
