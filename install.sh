#!/usr/bin/bash
# Copyright (c) 2025 Yevhenii Kryvyi

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# ====== Constants =============================================================

# ====== Errors ================================================================
ERR_INTERNET=1
ERR_DISK=2
ERR_PARTITION=3
ERR_MOUNT=4

# ====== Variables =============================================================

PARTITION_BOOT=""
PARTITION_SWAP=""
PARTITION_ROOT=""

# ====== Helpers ===============================================================

function last_command_failed() {
    if [ $? -eq 0 ]; then
        return 1
    else
        return 0
    fi
}

function is_uefi_boot_mode() {
    # Check for UEFI by looking for /sys/firmware/efi
    if [ -d /sys/firmware/efi ]; then
        return 0  # UEFI mode
    else
        return 1  # BIOS mode
    fi
}

check_partition() {
    PART="$1"
    TYPE="$2"

    # Check if the partition exists
    if [ ! -b "$PART" ]; then
        echo "[ER] $PART is missing!"
        return 1
    fi

    # Check if the partition is formatted with the correct filesystem
    FS_TYPE=$(blkid -o value -s TYPE "$PART")
    if [ "$FS_TYPE" != "$TYPE" ]; then
        echo "[ER] $PART is NOT formatted as $TYPE (found: $FS_TYPE)"
        return 1
    fi

    return 0
}

function is_partition_successful() {
    EXPECTED_BOOT_FS="ext4"
    if is_uefi_boot_mode; then
        EXPECTED_BOOT_FS="vfat"
    fi

    if ! check_partition "${PARTITION_BOOT}" "$EXPECTED_BOOT_FS"; then
        echo "[ER] Failed to create boot partition"
        return 1
    fi
    
    if ! check_partition "${PARTITION_SWAP}" "swap"; then
        echo "[ER] Failed to create swap partition"
        return 1
    fi

    if ! check_partition "${PARTITION_ROOT}" "btrfs"; then
        echo "[ER] Failed to create root partition"
        return 1
    fi

    return 0
}



# ==============================================================================

# 0) todo: automate image verification before install - is it possible?

if is_uefi_boot_mode; then
    echo "[OK]" Detected UEFI boot mode
else
    echo "[OK]" Detected BIOS boot mode
fi

# 1) Check Internet connection
echo "[--] Checking internet connection..."
# ping -c 4 google.com > /dev/null 2>&1
if last_command_failed; then
    echo "[ER] No internet connection -> abort"
    exit $ERR_INTERNET
fi

echo "[OK] Internet connection is established"
echo



# 2) Partition the disks
# 2.1) Select a disk
echo "[--] Select a disk to install to:"
lsblk -pdno NAME,SIZE,TYPE | grep 'disk'
read -p "[--] Enter the disk to use (e.g., /dev/sda, /dev/nvme0n1): " DESTINATION_DISK 

if [ -z $DESTINATION_DISK ]; then
    echo "[ER] '$DESTINATION_DISK' doesn't exist"
    exit $ERR_DISK
fi

ls $DESTINATION_DISK > /dev/null 2>&1
if last_command_failed; then
    echo "[ER] '$DESTINATION_DISK' doesn't exist"
    exit $ERR_DISK
fi

echo "[OK] Arch Linux will be installed to $DESTINATION_DISK"
echo

# 2.2) Partition
echo "[--] Preparing disk partitions..."
# Wipe
wipefs --all --force "$DESTINATION_DISK" >> /dev/null
sgdisk --zap-all "$DESTINATION_DISK" >> /dev/null

if is_uefi_boot_mode; then
    # Create a new GPT partition table
    parted -s "$DESTINATION_DISK" mklabel gpt >> /dev/null
    # /boot partition (1GB, FAT32 for UEFI)
    parted -s "$DESTINATION_DISK" mkpart primary fat32 1MiB 1GiB >> /dev/null
    parted -s "$DESTINATION_DISK" set 1 esp on >> /dev/null # Mark as EFI system partition
else
    # Create MBR partition table (instead of GPT)
    parted -s "$DESTINATION_DISK" mklabel msdos >> /dev/null >> /dev/null
    # /boot partition (1GB, EXT4 for BIOS)
    parted -s "$DESTINATION_DISK" mkpart primary ext4 1MiB 1GiB >> /dev/null
fi

# Swap partition (8GB)
parted -s "$DESTINATION_DISK" mkpart primary linux-swap 1GiB 9GiB >> /dev/null
# Root (/) partition (Btrfs, using remaining space)
parted -s "$DESTINATION_DISK" mkpart primary btrfs 9GiB 100% >> /dev/null

# 2.3) Formating
# Format /boot (UEFI: FAT32)
PARTITION_BOOT="${DESTINATION_DISK}1"
if is_uefi_boot_mode; then
    mkfs.fat -F32 "${PARTITION_BOOT}"  >> /dev/null
else
    mkfs.ext4 -F "${PARTITION_BOOT}" >> /dev/null
fi
# Format swap
PARTITION_SWAP="${DESTINATION_DISK}2"
mkswap "${PARTITION_SWAP}"  >> /dev/null
swapon "${PARTITION_SWAP}"  >> /dev/null
# Format root (Btrfs)
PARTITION_ROOT="${DESTINATION_DISK}3"
mkfs.btrfs -f "${PARTITION_ROOT}"  >> /dev/null

if ! is_partition_successful; then
    echo "[ER] Abort"
    exit $ERR_PARTITION
fi

# 2.4) Mount
mount $PARTITION_ROOT /mnt >> /dev/null
if last_command_failed; then
    echo "[ER] '$DESTINATION_DISK' doesn't exist"
    exit $ERR_MOUNT
fi

mount --mkdir $PARTITION_BOOT /mnt/boot >> /dev/null
if last_command_failed; then
    echo "[ER] '$DESTINATION_DISK' doesn't exist"
    exit $ERR_MOUNT
fi

echo "[OK] Disk partitions are created and mounted"
echo