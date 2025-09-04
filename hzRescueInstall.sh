#!/bin/bash
#
# A script to setup a worker (transcoder/fetcher/uploader) on Hetzner Rescue System.
# Modified to dynamically detect all NVMe drives and set up RAID 1.
#

# Dependencies:
# - installimage (comes with Hetzner Rescue System)

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# Exit if not running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Exit if not running on Hetzner Rescue System
if ! command -v installimage &> /dev/null; then
  echo "This script is intended to be run on Hetzner Rescue System"
  exit 1
fi

# Detect all NVMe drives (e.g., /dev/nvme0n1, /dev/nvme1n1, etc.)
NVME_DISKS=$(ls /dev/nvme*n1 2>/dev/null | tr '\n' ',' | sed 's/,$//')

# Exit if no NVMe drives found or only one (RAID 1 requires at least two)
if [ -z "$NVME_DISKS" ] || [ $(echo "$NVME_DISKS" | grep -o ',' | wc -l) -lt 1 ]; then
  echo "At least two NVMe drives are required for RAID 1. Found: ${NVME_DISKS:-none}"
  exit 1
fi

# Exit if Ubuntu 24.04 image is not present (adjust path if needed, assuming current dir or /root/)
IMAGE_FILE="Ubuntu-2404-noble-amd64-base.tar.gz"
if [ ! -f "/root/images/$IMAGE_FILE" ]; then
  echo "Ubuntu 24.04 image '$IMAGE_FILE' not found. Please ensure it's available."
  exit 1
fi

# Run installimage with detected disks, RAID 1, and specified partitions
installimage -a -d "$NVME_DISKS" -r yes -l 1 -i "$IMAGE_FILE" -p /boot/efi:esp:256M,swap:swap:4G,/:ext4:20G,/home:ext4:all

echo "Installation completed. The system will reboot into Ubuntu 24.04."
reboot
