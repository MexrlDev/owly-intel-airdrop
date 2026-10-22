#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Installer for Linux (Intel Wireless Cards)
# ==============================================================================

# DO NOT use 'set -e' here, we want to handle errors gracefully.
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
AIRDROP_DIR="$HOME/AirDrop"
OWLY_BUILD_DIR="/tmp/owly-build"
TEMP_CLONE_DIR="/tmp/owly-repo-clone"

# Repository URL (REPLACE THIS WITH YOUR ACTUAL GITHUB URL)
REPO_URL="https://github.com/MexrlDev/owly-intel-airdrop.git"

# Check if the user forgot to change the REPO_URL
if [[ "$REPO_URL" == *"YOUR_USERNAME"* ]]; then
    echo -e "${RED}[!] ERROR: You need to edit install.sh and change REPO_URL to your GitHub repository.${NC}"
    exit 1
fi

# Get the directory where install.sh is currently located
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

if [ -f "$AIRDROP_DIR/airdrop.sh" ]; then
    echo -e "${GREEN}[✓] Owly AirDrop is already installed at $AIRDROP_DIR${NC}"
    read -p "Do you want to run it now? (y/N): " RUN_NOW
    if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
        # REMOVED 'exec' here. If we use exec, the terminal closes when airdrop.sh finishes.
        "$AIRDROP_DIR/airdrop.sh"
    else
        echo "Exiting. You can run it anytime using: $AIRDROP_DIR/airdrop.sh"
    fi
    exit 0
fi

echo -e "${YELLOW}[*] Starting Owly AirDrop installation...${NC}"

# ==============================================================================
# 1. Hardware & Environment Check
# ==============================================================================
# Ensure we have a terminal
if [ ! -t 1 ]; then
    echo -e "${RED}[!] Error: This script must be run from an interactive terminal.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[*] Verifying hardware...${NC}"
WIFI_IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -n 1)
if [ -z "$WIFI_IFACE" ]; then
    echo -e "${RED}[!] Error: No wireless interface found.${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Detected wireless interface: $WIFI_IFACE${NC}"

# Cache sudo upfront
sudo -v
if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Error: Sudo access is required.${NC}"
    exit 1
fi

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
if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Error: Failed to clone Owly repository.${NC}"
    exit 1
fi

cd "$OWLY_BUILD_DIR"

echo -e "${YELLOW}[*] Compiling (This takes 5-15 minutes. Output is hidden to prevent terminal crashes)...${NC}"
source "$HOME/.cargo/env" 2>/dev/null || true

# Redirect cargo output to a log file. If it fails, show the log.
cargo build --release --locked -p owlyd -p owly-cli > /tmp/cargo_build.log 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Error: Compilation failed. See log below:${NC}"
    tail -n 20 /tmp/cargo_build.log
    exit 1
fi

echo -e "${YELLOW}[*] Installing system files (D-Bus and systemd)...${NC}"
sudo packaging/install.sh owly > /dev/null
sudo systemctl daemon-reload

# ==============================================================================
# 4. Setup ~/AirDrop/ Directory & Fetch Scripts
# ==============================================================================
echo -e "\n${YELLOW}[*] Setting up ~/AirDrop directory...${NC}"
mkdir -p "$AIRDROP_DIR"
mkdir -p "$AIRDROP_DIR/AirDrop-Received"

# Check if the utility scripts are available locally
if [ -f "$REPO_DIR/airdrop.sh" ] && [ -f "$REPO_DIR/receive.sh" ] && [ -f "$REPO_DIR/internet_recover.sh" ] && [ -f "$REPO_DIR/uninstall.sh" ]; then
    echo -e "${GREEN}[✓] Found local scripts. Copying to $AIRDROP_DIR...${NC}"
    cp "$REPO_DIR/airdrop.sh" "$AIRDROP_DIR/"
    cp "$REPO_DIR/receive.sh" "$AIRDROP_DIR/"
    cp "$REPO_DIR/internet_recover.sh" "$AIRDROP_DIR/"
    cp "$REPO_DIR/uninstall.sh" "$AIRDROP_DIR/"
else
    echo -e "${YELLOW}[*] Local scripts not found. Fetching from repository...${NC}"
    rm -rf "$TEMP_CLONE_DIR"
    git clone "$REPO_URL" "$TEMP_CLONE_DIR" > /dev/null
    
    if [ -f "$TEMP_CLONE_DIR/AirDrop/airdrop.sh" ]; then
        cp "$TEMP_CLONE_DIR/AirDrop/airdrop.sh" "$AIRDROP_DIR/"
        cp "$TEMP_CLONE_DIR/AirDrop/receive.sh" "$AIRDROP_DIR/"
        cp "$TEMP_CLONE_DIR/AirDrop/internet_recover.sh" "$AIRDROP_DIR/"
        cp "$TEMP_CLONE_DIR/AirDrop/uninstall.sh" "$AIRDROP_DIR/"
    else
        cp "$TEMP_CLONE_DIR/airdrop.sh" "$AIRDROP_DIR/" 2>/dev/null
        cp "$TEMP_CLONE_DIR/receive.sh" "$AIRDROP_DIR/" 2>/dev/null
        cp "$TEMP_CLONE_DIR/internet_recover.sh" "$AIRDROP_DIR/" 2>/dev/null
        cp "$TEMP_CLONE_DIR/uninstall.sh" "$AIRDROP_DIR/" 2>/dev/null
    fi
    rm -rf "$TEMP_CLONE_DIR"
fi

# Verify files were successfully placed
if [ ! -f "$AIRDROP_DIR/airdrop.sh" ] || [ ! -f "$AIRDROP_DIR/receive.sh" ]; then
    echo -e "${RED}[!] Error: Failed to retrieve utility scripts.${NC}"
    exit 1
fi

# Make scripts executable
chmod +x "$AIRDROP_DIR/airdrop.sh"
chmod +x "$AIRDROP_DIR/receive.sh"
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
echo "You can now send files using:    $AIRDROP_DIR/airdrop.sh"
echo "You can now receive files using: $AIRDROP_DIR/receive.sh"
echo "To restore internet manually:    $AIRDROP_DIR/internet_recover.sh"
echo "To uninstall:                    $AIRDROP_DIR/uninstall.sh"
echo ""

read -p "Do you want to run the sender now? (y/N): " RUN_NOW
if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
    "$AIRDROP_DIR/airdrop.sh"
fi
