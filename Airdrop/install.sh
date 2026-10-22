#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Installer for Linux (Intel Wireless Cards)
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

AIRDROP_DIR="$HOME/AirDrop"
OWLY_BUILD_DIR="/tmp/owly-build"
# Get the directory where install.sh is located
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

if [ -f "$AIRDROP_DIR/airdrop.sh" ]; then
    echo -e "${GREEN}[✓] Owly AirDrop is already installed at $AIRDROP_DIR${NC}"
    read -p "Do you want to run it now? (y/N): " RUN_NOW
    if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
        exec "$AIRDROP_DIR/airdrop.sh" "$@"
    else
        echo "Exiting. You can run it anytime using: $AIRDROP_DIR/airdrop.sh <file>"
        exit 0
    fi
fi

echo -e "${YELLOW}[*] Starting Owly AirDrop installation...${NC}"

echo -e "\n${YELLOW}[*] Verifying hardware...${NC}"
WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2}' | head -n 1)
if [ -z "$WIFI_IFACE" ]; then
    echo -e "${RED}[!] Error: No wireless interface found.${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Detected wireless interface: $WIFI_IFACE${NC}"

echo -e "\n${YELLOW}[*] Installing build dependencies...${NC}"
sudo apt-get update -qq
sudo apt-get install -y \
    build-essential cmake pkg-config libssl-dev libpcap-dev \
    libev-dev libnl-3-dev libnl-genl-3-dev libnl-route-3-dev \
    curl git network-manager aircrack-ng > /dev/null

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

echo -e "${YELLOW}[*] Compiling (This takes 5-15 minutes depending on CPU)...${NC}"
source "$HOME/.cargo/env" 2>/dev/null || true
cargo build --release --locked -p owlyd -p owly-cli > /dev/null

echo -e "${YELLOW}[*] Installing system files...${NC}"
sudo packaging/install.sh owly > /dev/null
sudo systemctl daemon-reload

echo -e "\n${YELLOW}[*] Setting up ~/AirDrop directory...${NC}"
mkdir -p "$AIRDROP_DIR"
cp "$REPO_DIR/airdrop.sh" "$AIRDROP_DIR/"
cp "$REPO_DIR/internet_recover.sh" "$AIRDROP_DIR/"
chmod +x "$AIRDROP_DIR/airdrop.sh"
chmod +x "$AIRDROP_DIR/internet_recover.sh"

rm -rf "$OWLY_BUILD_DIR"

echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN} INSTALLATION COMPLETE${NC}"
echo -e "${GREEN}============================================================${NC}"
echo "You can now send files using: $AIRDROP_DIR/airdrop.sh <file>"
echo ""

read -p "Do you want to run it now? (y/N): " RUN_NOW
if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
    read -p "Enter the full path of the file to send: " FILE_PATH
    "$AIRDROP_DIR/airdrop.sh" "$FILE_PATH"
fi
