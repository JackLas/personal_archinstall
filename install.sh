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
LOCALES="en_US.UTF-8 uk_UA.UTF-8 ru_RU.UTF-8"
LOCALE_LANG="en_US.UTF-8"

BASE_PACKAGES=( # will be installed with pacstrap before system configuration
"base" # essential package group for Arch Linux
"linux" # the latest stable kernel
"linux-firmware" # drivers
"efibootmgr" # EFI Boot Manager
"btrfs-progs" #  BTRFS utils
"grub" # boot boot-loader
"timeshift" # create system snapshots
"grub-btrfs" # add snapshots to the grub loader
"inotify-tools" # dependency for grub-btrfsd.service
"networkmanager" # network manager
"sudo" # root permissions
)

DESKTOP_ENV_PACKAGES=( # will be installed after system configuration
)

APPLICATION_PACKAGES=( # will be installed as a last step
)

# ====== Helpers ===============================================================
function last_command_failed() {
    if [ $? -eq 0 ]; then
        return 1
    else
        return 0
    fi
}

function assert_success() {
    if last_command_failed; then
        echo "$1"; exit 1
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


# 0) === Check if boot mode is correct =========================================
if is_uefi_boot_mode; then
    echo "[OK] Detected UEFI boot mode"
else
    echo "[OK] Detected unsupported BIOS boot mode -> abort"; exit 1
fi

# 1) === Check Internet connection =============================================
echo "[--] Checking internet connection..."
# ping -c 4 google.com > /dev/null 2>&1
assert_success "[ER] No internet connection -> abort"

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
assert_success "[ER] '$DESTINATION_DISK' doesn't exist"

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

# 2.4) --- Create root BTRFS subvolumes ----------------------------------------
mount $PARTITION_ROOT /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@snapshots
umount /mnt

# 2.5) --- Mount ---------------------------------------------------------------
BTRFS_MOUNT_OPTIONS="noatime,compress-force=zstd:2,space_cache=v2"
mount -o $BTRFS_MOUNT_OPTIONS,subvol=@ $PARTITION_ROOT /mnt
mkdir -p /mnt/{boot,home,var/log,var/cache,.snapshots} 
mount -o $BTRFS_MOUNT_OPTIONS,subvol=@home $PARTITION_ROOT /mnt/home
mount -o $BTRFS_MOUNT_OPTIONS,subvol=@log $PARTITION_ROOT /mnt/var/log
mount -o $BTRFS_MOUNT_OPTIONS,subvol=@cache $PARTITION_ROOT /mnt/var/cache
mount -o $BTRFS_MOUNT_OPTIONS,subvol=@snapshots $PARTITION_ROOT /mnt/.snapshots
mount $PARTITION_BOOT /mnt/boot
assert_success "[ER] '$PARTITION_BOOT' failed to mount"

echo "[OK] Disk partitions have been created and mounted"
echo

# 3) === Update mirrors ========================================================
echo "[--] Updating mirrors..."
reflector >> /dev/null
echo "[OK] Mirrors have been updated"
echo

# 4) === Install kernel ========================================================
echo "[--] Installing base packages kernel..."
pacstrap -K /mnt ${BASE_PACKAGES[@]}
assert_success "[ER] Failed to install base packages -> abort"
echo "[OK] Base packages have been installed"
echo

# 5) === System configuring ====================================================
# 5.1) --- fstab ---------------------------------------------------------------
echo "[--] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
assert_success "[ER] Failed to generate fstab"
echo "[OK] fstab has been generated"
echo

# 5.2) --- time ----------------------------------------------------------------
echo "[--] Setting up time..."
ln -sf /mnt/usr/share/zoneinfo/${TIME_ZONE_REGION} /mnt/etc/localtime
assert_success "[ER] Failed to set time zone"

arch-chroot /mnt bash -c "hwclock --systohc" >> /dev/null
assert_success "[ER] Failed to sync clock"

echo "[OK] Time has been set"

# 5.3) --- localization --------------------------------------------------------
echo "[--] Setting up localization..."
for i in $LOCALES; do
    sed -i "s/#${i}/${i}/g" /mnt/etc/locale.gen
done

arch-chroot /mnt bash -c "locale-gen" >> /dev/null
assert_success "[ER] Failed to sync clock"

for i in $LOCALES; do
    to_check=${i}
    to_check=${to_check/UTF-8/utf8}
    if ! arch-chroot /mnt bash -c "locale -a" | grep -q "^${to_check}$"; then
        echo "[ER] ${i} is not generated"; exit 1
    fi
done

echo "LANG=${LOCALE_LANG}" >> "/mnt/etc/locale.conf"

# todo: add keyboard layouts after installing KDE

echo "[OK] Localization has been set"

# 5.4) --- grub boot loader with timeshift support -----------------------------
echo "[--] Configuring grub with timeshift support..."
GRUB_CONFIG="/mnt/etc/default/grub"
if ! grep -q "GRUB_DISABLE_OS_PROBER" "$GRUB_CONFIG"; then
    echo "GRUB_DISABLE_OS_PROBER=false" >> "$GRUB_CONFIG"
else
    sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$GRUB_CONFIG"
fi

if ! grep -q "GRUB_BTRFS_SUBVOLUME" "$GRUB_CONFIG"; then
    echo 'GRUB_BTRFS_SUBVOLUME="/@"' >> "$GRUB_CONFIG"
else
    sed -i 's|^GRUB_BTRFS_SUBVOLUME=.*|GRUB_BTRFS_SUBVOLUME="/@"|' "$GRUB_CONFIG"
fi

arch-chroot /mnt bash -c "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
assert_success "[ER] Failed to install grub"

arch-chroot /mnt bash -c "timeshift --create --comments "Initial snapshot" --tags D"
assert_success "[ER] Failed to create initial timeshift snapshot"

arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
assert_success "[ER] Failed to make grub config"

arch-chroot /mnt bash -c "systemctl enable grub-btrfsd.service"
assert_success "[ER] Failed to enable grub-btrfsd.service"

echo "[OK] Grub with timeshift support has been configured"

# 5.5) --- hostname ------------------------------------------------------------
read -p "[--] Set hostname: " HOSTNAME
echo "${HOSTNAME}" >> /mnt/etc/hostname
assert_success "[ER] Failed to set hostname"
echo "[OK] Hostname has been set"

# 5.6) --- root passwd ---------------------------------------------------------
echo "[--] Set root password"
arch-chroot /mnt bash -c "passwd"
assert_success "[ER] Failed to set root password"
echo "[OK] root password has been set"

# 5.7) --- create user with sudo permissions -----------------------------------
read -p "[--] Enter your username: " USERNAME
arch-chroot /mnt bash -c "useradd -m -G wheel -s /bin/bash ${USERNAME}"
assert_success "[ER] Failed to create a user"

arch-chroot /mnt bash -c "passwd ${USERNAME}"
assert_success "[ER] Failed to set ${USERNAME} password"

# allow sudo for created user
sed -i -E "s/^ *# *%wheel ALL=\(ALL:ALL\) ALL/%wheel ALL=\(ALL:ALL\) ALL/g" /mnt/etc/sudoers
if ! grep -q "^%wheel ALL=(ALL:ALL) ALL$" "/mnt/etc/sudoers"; then
    echo "[ER] Failed to add sudo permissions to ${USERNAME}"; exit 1
fi

echo "[OK] User has been created"

# todo: move
# enable internet
arch-chroot /mnt bash -c "systemctl enable NetworkManager.service"

# exit cleanup
umount /mnt/boot
umount /mnt/.snapshots
umount /mnt/var/cache
umount /mnt/var/log
umount /mnt/home
umount /mnt

printf "\n\nReboot!!!\n\n"
