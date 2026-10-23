# Owly Intel AirDrop

<img width="400" alt="Owly Intel AirDrop" src="https://github.com/user-attachments/assets/0309fd62-5c90-4a75-b846-b7a5cc3e5fbc" />

A wrapper and automated installer for [Owly](https://github.com/t4t5/owly) designed specifically for Intel Wi-Fi cards on Linux. 

While Apple's AWDL (AirDrop) protocol is notoriously difficult to implement on non-Apple hardware, newer Intel cards (like the 8265, 9560, and AX200 series) lack "active monitor mode." Owly solves this by using "Exclusive Mode," but setting it up requires compiling Rust binaries, configuring D-Bus policies, and managing NetworkManager. 

This repository provides an automated installer, an advanced CLI sender, a receiver, an emergency network recovery tool, and a clean uninstaller.

## Repository Structure

All files are located in the `AirDrop/` directory of this repository:

- `AirDrop/install.sh`: The main installer. Checks dependencies, builds Owly, and sets up `~/AirDrop/`.
- `AirDrop/airdrop.sh`: The sender utility. Supports sending text, single files, or folders to one or multiple devices.
- `AirDrop/receive.sh`: The receiver utility. Listens for incoming AirDrops and saves them to `~/AirDrop/AirDrop-Received/`.
- `AirDrop/internet_recover.sh`: Emergency script to kill Owly processes and restore normal Wi-Fi.
- `AirDrop/uninstall.sh`: Cleanly removes Owly, system services, and the `~/AirDrop/` directory, while preserving received files.

## Prerequisites

- A Linux distribution (tested on Ubuntu 20.04 / Linux Lite 5.8).
- An Intel Wi-Fi card (Tested on Intel Dual Band Wireless-AC 8265).
- An active internet connection (for downloading dependencies and compiling).
- Rust and `cargo` will be installed automatically by the script if not present.

## Installation

### Method 1: Manual Clone (Recommended)
Copy and paste these commands into your terminal:

```bash
git clone https://github.com/MexrlDev/owly-intel-airdrop.git
cd owly-intel-airdrop/AirDrop
chmod +x launcher.sh
./launcher.sh
```

## The installer will:

1. Verify your wireless interface.
2. Install required C/C++ build tools and Rust.
3. Clone and compile owlyd and owly-cli.
4. Configure systemd and D-Bus policies.
5. Create a directory at ~/AirDrop/ containing all utility scripts.

## Usage

The scripts temporarily stop NetworkManager to free the Wi-Fi hardware. You will lose internet access during transfers. Both scripts trap Ctrl+C and exit signals to automatically call internet_recover.sh, restoring your connection when finished.

Sending Files

Run the sender utility:

```bash
~/AirDrop/airdrop.sh
```

Step-by-step execution:

1. The script scans for nearby Apple devices (ensure they are unlocked and set to "Everyone").
2. You are presented with a numbered list of devices. You can select one, multiple (e.g., 1,3), or all.
3. You choose the payload type:
   * Text: Prompts for text, creates a temporary .txt file, sends it, and deletes the temp file.
   * Single File: Prompts for the path to a file.
   * Folder: Prompts for a folder path and sends all files directly inside it.
4. The files are sent to the selected devices.

Receiving Files

Run the receiver utility:

```bash
~/AirDrop/receive.sh
```

Step-by-step execution;

1. The script brings up the awdl0 interface and listens for incoming connections.
2. Go to your iPhone/Mac and share a file via AirDrop. Your Linux machine will appear under the hostname.
3. Files are saved to ~/AirDrop/AirDrop-Received/.
4. Because Owly runs with sudo, the script automatically fixes file ownership back to your user account upon exit, ensuring you can edit or delete the received files.

Emergency Network Recovery

If a transfer fails catastrophically or your internet does not return, you can manually restore your connection at any time:

```bash
~/AirDrop/internet_recover.sh
```

Uninstallation

To completely remove Owly and its system services:

```bash
~/AirDrop/uninstall.sh
```

Note: The uninstaller will detect if you have files in ~/AirDrop/AirDrop-Received/. It will prompt you to move them to your Downloads folder before deleting the ~/AirDrop/ directory, so you never lose received files.

## Technical Limitations

* Intel Hardware: Intel cards operating in Exclusive Mode are restricted to a specific channel (usually Channel 6). Because of this, transfer speeds are slow (a 2MB photo may take 10-15 seconds). It is not recommended for large files (e.g., 1GB+).
* Network Downtime: The underlying radio is heavily utilized during the transfer. Normal internet access is paused while awdl0 is active.
* AWDL Hashing: Apple devices do not broadcast standard MAC addresses over AWDL. The scripts extract the dynamic AWDL hash to route the files correctly.

## Note

If something didn't work just give the .sh codes to ai it'll fix it and make it computable and working on your machine, might take some time but it'll work in the end since it's already done with the steps.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Credits

* MexrlDev - Creator and maintainer of the installer, sender, and receiver wrapper scripts.
* [t4t5/owly](https://github.com/t4t5/owly) - The Rust rewrite of OpenDrop/AWDL.
* [seemoo-lab/OpenDrop](https://github.com/seemoo-lab/opendrop) - The original reverse-engineering of the AWDL protocol.
