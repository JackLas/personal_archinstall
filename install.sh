#!/usr/bin/bash
# Copyright (c) 2025 Yevhenii Kryvyi
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# ====== Constants =============================================================
TIME_ZONE_REGION="Europe/Kyiv"
LOCALES=(
"en_US.UTF-8"
"uk_UA.UTF-8"
"ru_RU.UTF-8")
LOCALE_LANG="uk_UA.UTF-8"
LOCALE_LC_MESSAGES="en_US.UTF-8"

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

function check_partition() {
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

# 0) === todo: automate image verification before install - is it possible? ====

if is_uefi_boot_mode; then
    echo "[OK] Detected UEFI boot mode"
else
    echo "[OK] Detected unsupported BIOS boot mode -> abort"; exit 1
fi

# 1) === Check Internet connection =============================================
echo "[--] Checking internet connection..."
# ping -c 4 google.com > /dev/null 2>&1
if last_command_failed; then
    echo "[ER] No internet connection -> abort"; exit 1
fi

echo "[OK] Internet connection is established"
echo

# 2) === Partition the disks ===================================================
# 2.1) --- Select a disk -------------------------------------------------------
echo "[--] Select a disk to install to:"
lsblk -pdno NAME,SIZE,TYPE | grep 'disk'
read -p "[--] Enter the disk to use (e.g., /dev/sda): " DESTINATION_DISK 

if [ -z $DESTINATION_DISK ]; then
    echo "[ER] '$DESTINATION_DISK' doesn't exist"; exit 1
fi

ls $DESTINATION_DISK > /dev/null 2>&1
if last_command_failed; then
    echo "[ER] '$DESTINATION_DISK' doesn't exist"; exit 1
fi

PARTITION_BOOT="${DESTINATION_DISK}1"
PARTITION_SWAP="${DESTINATION_DISK}2"
PARTITION_ROOT="${DESTINATION_DISK}3"

echo "[OK] Arch Linux will be installed to $DESTINATION_DISK"
echo

# 2.2) --- Partition -----------------------------------------------------------
echo "[--] Preparing disk partitions..."

# Wipe
wipefs --all --force "$DESTINATION_DISK" >> /dev/null
sgdisk --zap-all "$DESTINATION_DISK" >> /dev/null

# Create a new GPT partition table
parted -s "$DESTINATION_DISK" mklabel gpt >> /dev/null

# /boot partition (1GB, FAT32 for UEFI)
parted -s "$DESTINATION_DISK" mkpart primary fat32 1MiB 1GiB >> /dev/null
parted -s "$DESTINATION_DISK" set 1 esp on >> /dev/null

# Swap partition (8GB)
parted -s "$DESTINATION_DISK" mkpart primary linux-swap 1GiB 9GiB >> /dev/null

# Root (/) partition (Btrfs, using remaining space)
parted -s "$DESTINATION_DISK" mkpart primary btrfs 9GiB 100% >> /dev/null

# 2.3) --- Format --------------------------------------------------------------
# Format boot
mkfs.fat -F32 "${PARTITION_BOOT}" >> /dev/null
if ! check_partition "${PARTITION_BOOT}" "vfat"; then
    echo "[ER] Failed to create boot partition"; exit 1
fi
# Format swap
mkswap "${PARTITION_SWAP}" >> /dev/null
swapon "${PARTITION_SWAP}" >> /dev/null
if ! check_partition "${PARTITION_SWAP}" "swap"; then
    echo "[ER] Failed to create swap partition"; exit 1
fi
# Format root (Btrfs)
mkfs.btrfs -f "${PARTITION_ROOT}" >> /dev/null
if ! check_partition "${PARTITION_ROOT}" "btrfs"; then
    echo "[ER] Failed to create root partition"; exit 1
fi

# 2.4) --- Mount ---------------------------------------------------------------
mount -o noatime,compress-force=zstd:2,space_cache=v2 $PARTITION_ROOT /mnt >> /dev/null
if last_command_failed; then
    echo "[ER] '$PARTITION_ROOT' failed to mount"; exit 1
fi

mount --mkdir $PARTITION_BOOT /mnt/boot >> /dev/null
if last_command_failed; then
    echo "[ER] '$PARTITION_BOOT' failed to mount"; exit 1
fi

echo "[OK] Disk partitions have been created and mounted"
echo

# 3) === Update mirrors ========================================================
echo "[--] Updating mirrors..."
reflector >> /dev/null
echo "[OK] Mirrors have been updated"
echo

# 4) === Install kernel ========================================================
echo "[--] Installing kernel..."
pacstrap -K /mnt base linux linux-firmware >> /dev/null
if last_command_failed; then
    echo "[ER] Failed to install Linux kernel -> abort"; exit 1
fi
echo "[OK] Stable kernel has been installed"
echo

# 5) === System configuring ====================================================
# 5.1) --- fstab ---------------------------------------------------------------
echo "[--] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
if last_command_failed; then
    echo "[ER] Failed to generate fstab"; exit 1
fi
echo "[OK] fstab has been generated"
echo

# 5.2) --- time ----------------------------------------------------------------
echo "[--] Setting up time..."
ln -sf /mnt/usr/share/zoneinfo/${TIME_ZONE_REGION} /mnt/etc/localtime
if last_command_failed; then
    echo "[ER] Failed to set time zone"; exit 1
fi
arch-chroot /mnt bash -c "hwclock --systohc" >> /dev/null
if last_command_failed; then
    echo "[ER] Failed to set time zone"; exit 1
fi
echo "[OK] Time has been set"

# 5.3) --- localization --------------------------------------------------------
echo "[--] Setting up localization..."
for i in "${LOCALES[@]}"; do
    sed -i "s/#${i}/${i}/g" /mnt/etc/locale.gen
done

arch-chroot /mnt bash -c "locale-gen" >> /dev/null

for i in "${LOCALES[@]}"; do
    to_check=${i}
    to_check=${to_check/UTF-8/utf8}
    if ! arch-chroot /mnt bash -c "locale -a" | grep -q "^${to_check}$"; then
        echo "[ER] ${i} is not generated"; exit 1
    fi
done

echo "LANG=${LOCALE_LANG}" >> "/mnt/etc/locale.conf"
echo "LC_MESSAGES=${LOCALE_LC_MESSAGES}" >> "/mnt/etc/locale.conf"

# todo: add keyboard layouts after installing KDE

echo "[OK] Localization has been set"

# 5.4) --- hostname ------------------------------------------------------------
read -p "[--] Set hostname: " HOSTNAME
echo "${HOSTNAME}" >> /mnt/etc/hostname
if last_command_failed; then
    echo "[ER] Failed to set hostname"; exit 1
fi
echo "[OK] Hostname has been set"

# 5.4) --- passwd --------------------------------------------------------------
echo "[--] Set root password"
arch-chroot /mnt bash -c "passwd"
if last_command_failed; then
    echo "[ER] Failed to set root password"; exit 1
fi
echo "[OK] root password has been set"

# 5.5) --- grub boot loader with timeshift support -----------------------------
echo "[--] Installing grub with timeshift support..."
arch-chroot /mnt bash -c "pacman -S --noconfirm grub efibootmgr grub-btrfs timeshift"
if last_command_failed; then
    echo "[ER] Failed to install grub and timeshift"; exit 1
fi

arch-chroot /mnt bash -c "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
if last_command_failed; then
    echo "[ER] Failed to install grub"; exit 1
fi


arch-chroot /mnt bash -c "timeshift --create --comments "Initial snapshot" --tags D"
if last_command_failed; then
    echo "[ER] Failed to create initial timeshift snapshot"; exit 1
fi
echo "GRUB_ENABLE_BTRFS=\"true\"" >> /mnt/etc/default/grub
sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet btrfs.root=$(blkid -o value -s PARTUUID ${PARTITION_ROOT})\"/" /mnt/etc/default/grub

arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
if last_command_failed; then
    echo "[ER] Failed to make grub config"; exit 1
fi

echo "[OK] Grub with timeshift support has been installed"

# exit cleanup
umount /mnt/boot
umount /mnt

printf "\n\nReboot!!!\n\n"
