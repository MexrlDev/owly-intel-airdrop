#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Installer for Linux (Intel Wireless Cards)
#
# This script installs dependencies, builds Owly, and sets up the local
# ~/AirDrop/ directory. It automatically fetches missing utility scripts
# from the repository if they are not found locally.
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
AIRDROP_DIR="$HOME/AirDrop"
OWLY_BUILD_DIR="/tmp/owly-build"
TEMP_CLONE_DIR="/tmp/owly-repo-clone"

# Repository URL (UPDATE THIS with your actual GitHub repository)
REPO_URL="https://github.com/YOUR_USERNAME/owly-intel-airdrop.git"

# Get the directory where install.sh is currently located
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

# ==============================================================================
# 1. Hardware Check
# ==============================================================================
echo -e "\n${YELLOW}[*] Verifying hardware...${NC}"
WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2}' | head -n 1)
if [ -z "$WIFI_IFACE" ]; then
    echo -e "${RED}[!] Error: No wireless interface found.${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Detected wireless interface: $WIFI_IFACE${NC}"

# ==============================================================================
# 2. Install Dependencies
# ==============================================================================
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

# ==============================================================================
# 3. Build and Install Owly
# ==============================================================================
echo -e "\n${YELLOW}[*] Cloning and compiling Owly...${NC}"
rm -rf "$OWLY_BUILD_DIR"
git clone https://github.com/t4t5/owly.git "$OWLY_BUILD_DIR" > /dev/null
cd "$OWLY_BUILD_DIR"

echo -e "${YELLOW}[*] Compiling (This takes 5-15 minutes depending on CPU)...${NC}"
source "$HOME/.cargo/env" 2>/dev/null || true
cargo build --release --locked -p owlyd -p owly-cli > /dev/null

echo -e "${YELLOW}[*] Installing system files (D-Bus and systemd)...${NC}"
sudo packaging/install.sh owly > /dev/null
sudo systemctl daemon-reload

# ==============================================================================
# 4. Setup ~/AirDrop/ Directory & Fetch Scripts
# ==============================================================================
echo -e "\n${YELLOW}[*] Setting up ~/AirDrop directory...${NC}"
mkdir -p "$AIRDROP_DIR"

# Check if the utility scripts are available locally
if [ -f "$REPO_DIR/airdrop.sh" ] && [ -f "$REPO_DIR/internet_recover.sh" ] && [ -f "$REPO_DIR/uninstall.sh" ]; then
    echo -e "${GREEN}[✓] Found local scripts. Copying to $AIRDROP_DIR...${NC}"
    cp "$REPO_DIR/airdrop.sh" "$AIRDROP_DIR/"
    cp "$REPO_DIR/internet_recover.sh" "$AIRDROP_DIR/"
    cp "$REPO_DIR/uninstall.sh" "$AIRDROP_DIR/"
else
    echo -e "${YELLOW}[*] Local scripts not found. Fetching from repository...${NC}"
    rm -rf "$TEMP_CLONE_DIR"
    git clone "$REPO_URL" "$TEMP_CLONE_DIR" > /dev/null
    
    # Assuming the scripts are inside the AirDrop/ folder in the repository
    if [ -f "$TEMP_CLONE_DIR/AirDrop/airdrop.sh" ]; then
        cp "$TEMP_CLONE_DIR/AirDrop/airdrop.sh" "$AIRDROP_DIR/"
        cp "$TEMP_CLONE_DIR/AirDrop/internet_recover.sh" "$AIRDROP_DIR/"
        cp "$TEMP_CLONE_DIR/AirDrop/uninstall.sh" "$AIRDROP_DIR/"
    else
        # Fallback if they are in the root of the repo
        cp "$TEMP_CLONE_DIR/airdrop.sh" "$AIRDROP_DIR/" 2>/dev/null || true
        cp "$TEMP_CLONE_DIR/internet_recover.sh" "$AIRDROP_DIR/" 2>/dev/null || true
        cp "$TEMP_CLONE_DIR/uninstall.sh" "$AIRDROP_DIR/" 2>/dev/null || true
    fi
    rm -rf "$TEMP_CLONE_DIR"
fi

# Verify files were successfully placed
if [ ! -f "$AIRDROP_DIR/airdrop.sh" ]; then
    echo -e "${RED}[!] Error: Failed to retrieve utility scripts.${NC}"
    exit 1
fi

# Make scripts executable
chmod +x "$AIRDROP_DIR/airdrop.sh"
chmod +x "$AIRDROP_DIR/internet_recover.sh"
chmod +x "$AIRDROP_DIR/uninstall.sh"

# Clean up build directory
rm -rf "$OWLY_BUILD_DIR"

# ==============================================================================
# 5. Completion
# ==============================================================================
echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN} INSTALLATION COMPLETE${NC}"
echo -e "${GREEN}============================================================${NC}"
echo "You can now send files using: $AIRDROP_DIR/airdrop.sh <file>"
echo "To restore internet manually: $AIRDROP_DIR/internet_recover.sh"
echo "To uninstall: $AIRDROP_DIR/uninstall.sh"
echo ""

read -p "Do you want to run it now? (y/N): " RUN_NOW
if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
    read -p "Enter the full path of the file to send: " FILE_PATH
    "$AIRDROP_DIR/airdrop.sh" "$FILE_PATH"
fi
