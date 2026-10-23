#!/usr/bin/env bash
# ==============================================================================
# Owly AirDrop Sender
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
RECOVER_SCRIPT="$SCRIPT_DIR/internet_recover.sh"

if [ ! -f "$RECOVER_SCRIPT" ]; then
    echo "Error: $RECOVER_SCRIPT not found. Please reinstall."
    exit 1
fi

CLEANUP_DONE=0
cleanup() {
    if [ "$CLEANUP_DONE" -eq 1 ]; then return; fi
    CLEANUP_DONE=1
    "$RECOVER_SCRIPT"
}
trap cleanup EXIT INT TERM

echo "============================================================"
echo " 1. Starting Owly Radio..."
echo "============================================================"
sudo -v
sudo systemctl stop NetworkManager
sudo airmon-ng check kill >/dev/null 2>&1 || true

sudo systemctl start owlyd
sleep 2
sudo owly radio up > /tmp/owly_radio.log 2>&1 &
sleep 4

if ! ip link show awdl0 >/dev/null 2>&1; then
    echo "  [FAIL] awdl0 interface did not come up."
    cat /tmp/owly_radio.log
    exit 1
fi
echo "  [SUCCESS] awdl0 is up."

echo "============================================================"
echo " 2. Scanning for Apple Devices (Up to 5 Attempts)..."
echo "============================================================"
echo "  >>> Ensure target devices are UNLOCKED and AirDrop is on 'Everyone' <<<"

DEVICES=""
ATTEMPT=1
MAX_ATTEMPTS=5

while [ -z "$DEVICES" ] && [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "  Scanning for 10 seconds (Attempt $ATTEMPT/$MAX_ATTEMPTS)..."
    timeout 10s owly browse > /tmp/owly_browse.log 2>&1
    
    DEVICES=$(grep -oE '^[0-9a-f]+.*"[^"]+"' /tmp/owly_browse.log | awk '!seen[$1]++')
    
    if [ -z "$DEVICES" ]; then
        echo "  [WARN] No devices found. Retrying..."
        sleep 1
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

if [ -z "$DEVICES" ]; then
    echo "  [FAIL] Could not find any Apple devices after $MAX_ATTEMPTS attempts."
    echo "  Please make sure your iPhone/Mac screen is ON and unlocked."
    exit 1
fi

echo -e "\nAvailable Devices:"
echo "------------------------------------------------------------"
i=1
declare -a DEV_IDS
declare -a DEV_NAMES

while IFS= read -r line; do
    id=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk -F'"' '{print $2}')
    DEV_IDS+=("$id")
    DEV_NAMES+=("$name")
    printf "  [%d] %s\n" "$i" "$name"
    ((i++))
done <<< "$DEVICES"
echo "------------------------------------------------------------"

read -p "Enter device number(s) [e.g., 1 or 1,3 or 'all'] < " SELECTION

TARGET_IDS=()
if [[ "$SELECTION" == "all" || "$SELECTION" == "ALL" ]]; then
    TARGET_IDS=("${DEV_IDS[@]}")
else
    IFS=',' read -ra CHOICES <<< "$SELECTION"
    for choice in "${CHOICES[@]}"; do
        choice=$(echo "$choice" | xargs) # Trim whitespace
        idx=$((choice - 1))
        if [[ "$idx" -ge 0 && "$idx" -lt "${#DEV_IDS[@]}" ]]; then
            TARGET_IDS+=("${DEV_IDS[$idx]}")
        else
            echo "  [WARNING] Invalid selection: $choice. Skipping."
        fi
    done
fi

if [ ${#TARGET_IDS[@]} -eq 0 ]; then
    echo "  [FAIL] No valid devices selected."
    exit 1
fi

echo "============================================================"
echo " 3. Choose Payload Type"
echo "============================================================"
echo "  [1] Send Text (creates a temporary .txt file)"
echo "  [2] Send a Single File"
echo "  [3] Send a Folder (sends all files inside)"
echo "------------------------------------------------------------"
read -p "Select option [1-3] < " PAYLOAD_TYPE

FILES_TO_SEND=()
TEMP_TEXT_FILE=""

case "$PAYLOAD_TYPE" in
    1)
        read -p "Enter the text you want to send < " TEXT_MSG
        TEMP_TEXT_FILE="/tmp/owly_text_$$.txt"
        echo "$TEXT_MSG" > "$TEMP_TEXT_FILE"
        FILES_TO_SEND+=("$TEMP_TEXT_FILE")
        ;;
    2)
        read -p "Enter the full path to the file < " FILE_PATH
        FILE_PATH=$(realpath "$FILE_PATH" 2>/dev/null)
        if [ ! -f "$FILE_PATH" ]; then
            echo "  [FAIL] File not found: $FILE_PATH"
            exit 1
        fi
        FILES_TO_SEND+=("$FILE_PATH")
        ;;
    3)
        read -p "Enter the full path to the folder < " FOLDER_PATH
        FOLDER_PATH=$(realpath "$FOLDER_PATH" 2>/dev/null)
        if [ ! -d "$FOLDER_PATH" ]; then
            echo "  [FAIL] Folder not found: $FOLDER_PATH"
            exit 1
        fi
        echo "  Scanning folder for files..."
        while IFS= read -r -d '' f; do
            FILES_TO_SEND+=("$f")
        done < <(find "$FOLDER_PATH" -maxdepth 1 -type f -print0)
        
        if [ ${#FILES_TO_SEND[@]} -eq 0 ]; then
            echo "  [FAIL] No files found in folder."
            exit 1
        fi
        ;;
    *)
        echo "  [FAIL] Invalid option."
        exit 1
        ;;
esac

echo "============================================================"
echo " 4. Sending Payload (Up to 5 Attempts per file)..."
echo "============================================================"

for target in "${TARGET_IDS[@]}"; do
    echo ">>> Sending to Device ID: $target"
    for file in "${FILES_TO_SEND[@]}"; do
        echo "  Sending: $(basename "$file") ..."
        
        SEND_SUCCESS=0
        for send_try in $(seq 1 5); do
            if sudo owly send "$file" --to "$target"; then
                SEND_SUCCESS=1
                break
            else
                echo "    [WARN] Handshake failed. Retrying ($send_try/5)..."
                sleep 1
            fi
        done
        
        if [ "$SEND_SUCCESS" -eq 1 ]; then
            echo "    [SUCCESS] Sent."
        else
            echo "    [FAIL] Failed to send after 5 attempts."
        fi
        sleep 1
    done
done

if [ -n "$TEMP_TEXT_FILE" ] && [ -f "$TEMP_TEXT_FILE" ]; then
    echo "  Deleting temporary text file..."
    rm -f "$TEMP_TEXT_FILE"
fi

echo -e "\n  >>> CHECK YOUR APPLE DEVICE(S) TO ACCEPT THE FILES! <<<"
echo "  (Returning to menu in 3 seconds...)"
sleep 3
