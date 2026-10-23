#!/usr/bin/env bash
# ==============================================================================
# Owly Intel AirDrop - Launcher
# ==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
# Bright Blue / Light Cyan for the artwork
ART_COLOR='\033[1;36m' 
NC='\033[0m'

AIRDROP_DIR="$HOME/AirDrop"
TEMP_CLONE_DIR="/tmp/owly-update-check"
REPO_URL="https://github.com/MexrlDev/owly-intel-airdrop.git"
WEB_URL="https://github.com/MexrlDev/owly-intel-airdrop"

show_art() {
    clear
    echo -e "${ART_COLOR}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║                   OWLY INTEL AIRDROP                       ║
║                                                            ║
║                       By MexrlDev                          ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Lock to prevent double cleanup on Ctrl+C
CLEANUP_DONE=0
cleanup() {
    if [ "$CLEANUP_DONE" -eq 1 ]; then return; fi
    CLEANUP_DONE=1
    echo -e "\n\n${YELLOW}[*] Exiting Launcher...${NC}"
    exit 0
}
trap cleanup INT TERM

# 1. Bootstrap (If not installed)
if [ ! -f "$AIRDROP_DIR/launcher.sh" ]; then
    show_art
    echo -e "${YELLOW}[!] Owly AirDrop is not installed.${NC}"
    read -p "Do you want to install it now? (y/N): " DO_INSTALL
    
    if [[ "$DO_INSTALL" =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}[*] Fetching files from GitHub...${NC}"
        rm -rf "$TEMP_CLONE_DIR"
        git clone "$REPO_URL" "$TEMP_CLONE_DIR" > /dev/null 2>&1
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}[!] Error: Failed to clone repository. Check internet.${NC}"
            exit 1
        fi
        
        mkdir -p "$AIRDROP_DIR"
        cp -r "$TEMP_CLONE_DIR/AirDrop/"* "$AIRDROP_DIR/"
        cp "$TEMP_CLONE_DIR/README.md" "$AIRDROP_DIR/" 2>/dev/null || cp "$TEMP_CLONE_DIR/AirDrop/README.md" "$AIRDROP_DIR/" 2>/dev/null || true
        
        find "$AIRDROP_DIR" -name "*.sh" -exec chmod +x {} \;
        rm -rf "$TEMP_CLONE_DIR"
        
        echo -e "${GREEN}[✓] Files downloaded to $AIRDROP_DIR${NC}"
        echo -e "${YELLOW}[*] Starting installer...${NC}\n"
        "$AIRDROP_DIR/install.sh"
        exit 0
    else
        echo "Exiting."
        exit 0
    fi
fi

# 2. Dynamic Update Checker
echo -e "\n${YELLOW}[*] Checking for updates...${NC}"
rm -rf "$TEMP_CLONE_DIR"

if git clone --depth 1 "$REPO_URL" "$TEMP_CLONE_DIR" > /dev/null 2>&1; then
    UPDATE_AVAILABLE=0
    for local_file in "$AIRDROP_DIR"/*; do
        filename=$(basename "$local_file")
        remote_file="$TEMP_CLONE_DIR/AirDrop/$filename"
        if [ -f "$remote_file" ]; then
            if ! diff -q "$remote_file" "$local_file" >/dev/null 2>&1; then
                UPDATE_AVAILABLE=1
                break
            fi
        fi
    done

    if [ "$UPDATE_AVAILABLE" -eq 1 ]; then
        echo -e "${CYAN}[!] New updates available on GitHub!${NC}"
        read -p "Do you want to update all scripts now? (y/N): " DO_UPDATE
        if [[ "$DO_UPDATE" =~ ^[Yy]$ ]]; then
            cp -r "$TEMP_CLONE_DIR/AirDrop/"* "$AIRDROP_DIR/"
            cp "$TEMP_CLONE_DIR/README.md" "$AIRDROP_DIR/" 2>/dev/null || cp "$TEMP_CLONE_DIR/AirDrop/README.md" "$AIRDROP_DIR/" 2>/dev/null || true
            find "$AIRDROP_DIR" -name "*.sh" -exec chmod +x {} \;
            
            echo -e "${GREEN}[✓] Scripts updated successfully!${NC}"
            echo -e "${YELLOW}[*] Restarting launcher to apply updates...${NC}"
            rm -rf "$TEMP_CLONE_DIR"
            sleep 2
            exec "$AIRDROP_DIR/launcher.sh"
        fi
    else
        echo -e "${GREEN}[✓] All scripts are up to date.${NC}"
    fi
    rm -rf "$TEMP_CLONE_DIR"
else
    echo -e "${RED}[!] Could not check for updates (No internet).${NC}"
fi

# 3. Main Menu
while true; do
    show_art
    echo -e "${CYAN}============================================================${NC}"
    echo -e "                     MAIN MENU"
    echo -e "${CYAN}============================================================${NC}"
    echo "  [1] Send File (AirDrop)"
    echo "  [2] Receive File"
    echo "  [3] Restore Internet (Emergency)"
    echo "  [4] Reinstall / Setup (install.sh)"
    echo "  [5] Uninstall"
    echo "  [6] Force Update Scripts"
    echo "  [7] View Source Code (GitHub)"
    echo "  [8] Exit"
    echo -e "${CYAN}============================================================${NC}"
    read -p "Select option [1-8] < " CHOICE

    case $CHOICE in
        1) "$AIRDROP_DIR/airdrop.sh" ;;
        2) "$AIRDROP_DIR/receive.sh" ;;
        3) "$AIRDROP_DIR/internet_recover.sh" ;;
        4) "$AIRDROP_DIR/install.sh" ;;
        5) "$AIRDROP_DIR/uninstall.sh"; exit 0 ;;
        6)
            echo -e "\n${YELLOW}[*] Forcing update from GitHub...${NC}"
            rm -rf "$TEMP_CLONE_DIR"
            git clone --depth 1 "$REPO_URL" "$TEMP_CLONE_DIR" > /dev/null 2>&1
            
            if [ $? -ne 0 ]; then
                echo -e "${RED}[!] Error: Failed to connect to GitHub. Check internet.${NC}"
                sleep 2
            else
                cp -r "$TEMP_CLONE_DIR/AirDrop/"* "$AIRDROP_DIR/"
                cp "$TEMP_CLONE_DIR/README.md" "$AIRDROP_DIR/" 2>/dev/null || cp "$TEMP_CLONE_DIR/AirDrop/README.md" "$AIRDROP_DIR/" 2>/dev/null || true
                find "$AIRDROP_DIR" -name "*.sh" -exec chmod +x {} \;
                rm -rf "$TEMP_CLONE_DIR"
                echo -e "${GREEN}[✓] All scripts have been forcibly updated!${NC}"
                echo -e "${YELLOW}[*] Restarting launcher to apply changes...${NC}"
                sleep 2
                exec "$AIRDROP_DIR/launcher.sh"
            fi
            ;;
        7)
            echo -e "\n${YELLOW}[*] Opening GitHub repository in your browser...${NC}"
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$WEB_URL" >/dev/null 2>&1 &
            elif command -v python3 >/dev/null 2>&1; then
                python3 -m webbrowser -t "$WEB_URL"
            else
                echo -e "${RED}[!] Could not find a tool to open the browser.${NC}"
                echo "Please visit: $WEB_URL"
            fi
            ;;
        8) echo -e "\n${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "\n${RED}[!] Invalid option.${NC}"; sleep 1 ;;
    esac
    
    echo -e "\nPress Enter to return to the menu..."
    read -r
done
