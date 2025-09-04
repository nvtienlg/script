#!/bin/bash
#
# A script to setup a worker (transcoder/fetcher/uploader) on Hetzner Rescue System.
# Dynamically detects installimage path and sets up RAID 1 on all NVMe drives.
#

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# Exit if not running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Function to detect installimage path
get_installimage_path() {
  # Try to resolve installimage from alias
  local alias_path
  alias_path=$(alias installimage 2>/dev/null | sed -n "s/alias installimage='\(.*\)'/\1/p")
  if [ -n "$alias_path" ] && [ -x "$alias_path" ]; then
    echo "$alias_path"
    return
  fi

  # Fallback: check common locations
  local possible_paths=(
    "/root/.oldroot/nfs/install/installimage"
    "/usr/bin/installimage"
    "/sbin/installimage"
  )
  for path in "${possible_paths[@]}"; do
    if [ -x "$path" ]; then
      echo "$path"
      return
    fi
  done

  # If not found, exit with error
  echo "installimage not found. Ensure you're running on Hetzner Rescue System." >&2
  exit 1
}

# Get installimage path
INSTALLIMAGE=$(get_installimage_path)

# Detect all NVMe drives (e.g., /dev/nvme0n1, /dev/nvme1n1, etc.)
NVME_DISKS=$(ls /dev/nvme*n1 2>/dev/null | xargs -n1 basename | tr '\n' ',' | sed 's/,$//')

# Exit if no NVMe drives found or only one (RAID 1 requires at least two)
if [ -z "$NVME_DISKS" ] || [ $(echo "$NVME_DISKS" | grep -o ',' | wc -l) -lt 1 ]; then
  echo "At least two NVMe drives are required for RAID 1. Found: ${NVME_DISKS:-none}"
  exit 1
fi

# Exit if Ubuntu 24.04 image is not present
IMAGE_FILE="Ubuntu-2404-noble-amd64-base.tar.gz"
if [ ! -f "/root/images/$IMAGE_FILE" ]; then
  echo "Ubuntu 24.04 image '$IMAGE_FILE' not found. Please ensure it's available."
  exit 1
fi

# Run installimage with detected disks, RAID 1, and specified partitions
"$INSTALLIMAGE" -a -d "$NVME_DISKS" -r yes -l 1 -i "$IMAGE_FILE" -p /boot/efi:esp:256M,swap:swap:4G,/:ext4:20G,/home:ext4:all

echo "Installation completed. The system will reboot into Ubuntu 24.04."
reboot
