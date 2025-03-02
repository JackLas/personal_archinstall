#!/bin/bash
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

# ====== Constants =================================================================================
MIRRORS_COUNTRY="Ukraine,"
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
"reflector" # update available mirrors
)

ENVIRONMENT_PACKAGES=( # will be installed after system configuration
"terminator" # terminal
"sddm" # window manager
"xorg-xwayland" # X11-Wayland compatibility
"git" # to build AUR, also for developement
"base-devel" # to build AUR packages and more
"rust" # to build paru
"cups" # printers
"cups-pdf" # print to pdf
# --- selected plasma group packages (with a few additions):
"plasma-desktop" # KDE Plasma base package
"plasma-workspace" # core KDE Plasma 
"plasma-workspace-wallpapers" # wallpapers
"libplasma" # Plasma
"bluedevil" # Bluetooth integration
"breeze" # theme
"breeze-gtk" # same theme for gtk
"breeze-plymouth" # theme for theme?
"kde-gtk-config" # KDE settings for GTK
"kdecoration" # decorations
"kgamma" # adjust gamma
"kmenuedit" # edit menu
"kde-cli-tools" # utils
"kdeplasma-addons" # addons
"kglobalacceld " # shortcuts
"kinfocenter" # system info
"kpipewire" # pipewire for KDE
"kscreen" # screen management
"libkscreen" # screen management
"kscreenlocker" # lock screen
"ksystemstats" # system stats
"libksysguard" # system monitoring
"kwayland" # wayland
"kwin" # windows manager
"layer-shell-qt" # for wayland
"milou" # search
"plasma5support" # porting from KF5/Qt5 to KF6/Qt6
"plasma-browser-integration" # browser integration
"plasma-disks" # monitor disks, S.M.A.R.T.
"plasma-firewall" # firewall GUI
"firewalld" # firewall
"plasma-integration" # better integration
"plasma-nm" # network manager GUI
"plasma-pa" # audio GUI
"plasma-systemmonitor" # system monitoring GUI
"plymouth-kcm" # manage boot theme
"polkit-kde-agent" # authentication dialogs
"powerdevil" # power management
"print-manager" # printers
"system-config-printer" # printers GUI
"sddm-kcm" # sddm configuration
"spectacle" # screenshots
"systemsettings" # GUI
"xdg-desktop-portal-kde" # integration
"kdenetwork-filesharing" # file sharing GUI
# --- audio system:
"pipewire" # main audio package
"lib32-pipewire" 
"pipewire-pulse" # compatibility
"pipewire-alsa" # compatibility
"pipewire-jack" # compatibility
"qjackctl" # GUI
# --- graphical system:
"mesa"
"lib32-mesa"
"vulkan-radeon"
"lib32-vulkan-radeon"
"xf86-video-amdgpu"
# --- fonts:
"noto-fonts"
"noto-fonts-emoji"
"noto-fonts-extra"
"ttf-liberation"
"ttf-dejavu"
# --- dependencies:
"qt6-multimedia-ffmpeg"
"qt5-tools"
)

APPLICATION_PACKAGES=( # will be installed as a pre-last step
"fastfetch"
"ark"
"lzip"
"lzop"
"unarchiver"
"7zip"
"dolphin"
"filelight"
"gwenview"
"kcalc"
"kamoso"
"kate"
"okular"
"vlc"
"spotify-launcher"
"obs-studio"
"firefox"
"chromium"
"gimp"
"transmission-qt"
"qemu-full"
"git"
"meld"
"gcc"
"clang"
"make"
"cmake"
"python3"
"python-pip"
"speedtest-cli"
"jdk-openjdk"
"jre21-openjdk"
"jre17-openjdk"
"jre11-openjdk"
"jre8-openjdk"
"openssh"
"lutris"
"steam"
"prismlauncher"
"discord"
"reaper"
"musescore"
"solaar"
"alsa-scarlett-gui"
"wine"
"wine-gecko"
"wine-mono"
"yabridge"
)

AUR_PACKAGES=( # additional packages, will be installed as a last step
"rustdesk"
"vscodium"
"tuxguitar"
)

SERVICES=( # will be enabled on system level after all packages installed
"NetworkManager" # network
"grub-btrfsd" # update grub menu with new snapshots
"sddm" # window manager
"firewalld" # firewall
"cups.socket" # printers
) 

# ====== Logging ===================================================================================
LOGFILE="install.log.txt"
rm -f $LOGFILE # clear last log, just in cases
exec 3>&1 # redirect printf and echo into stdout stream
exec > $LOGFILE 2>&1 # redirect every output into LOGFILE
function log_impl { printf "$@\n" | tee /dev/tty ; } # tee to LOGFILE and terminal
function log { log_impl "$@"; }
function log_attention { log "[--] $@"; }
function log_ok { log "[OK] $@"; }
function log_error { log "[ER] $@"; }

# ====== Helpers ===================================================================================
function interactively {
    $"$@" >/dev/tty 2>&1
}

function assert_success() {
    if [ $? -ne 0 ]; then
        log_error "$@"; 
        exit 1
    fi
}

function for_system() {
    arch-chroot /mnt bash -c "$@"
}

function with_retry() {
    MAX_RETRIES=3 
    attempt=0
    while (( attempt < MAX_RETRIES )); do
        "$@"
        if [[ $? -eq 0 ]]; then
            break
        fi
        ((attempt++))
        if (( attempt < MAX_RETRIES )); then
            log "Error occured. One more try (${attempt}/${MAX_RETRIES})";  
        else
            log_error "No more retries. Abort"; exit 1
        fi
    done
}

function is_uefi_boot_mode() {
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
        log_error "$PART is missing!"
        return 1
    fi

    # Check if the partition is formatted with the correct filesystem
    FS_TYPE=$(blkid -o value -s TYPE "$PART")
    if [ "$FS_TYPE" != "$TYPE" ]; then
        log_error "$PART is NOT formatted as $TYPE (found: $FS_TYPE)"
        return 1
    fi

    return 0
}

function is_asus_laptop() {
    local manufacturer chassis_type
    manufacturer=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
    chassis_type=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)

    if [[ "$manufacturer" == *"ASUS"* || "$manufacturer" == *"Asus"* ]] && \
       [[ "$chassis_type" =~ ^(8|9|10)$ ]]; then
        return 0
    else
        return 1
    fi
}

# 1) === Prepare environment =======================================================================
log "Checking environment..."
if is_uefi_boot_mode; then
    log_ok "Detected UEFI boot mode"
else
    log_error "Detected unsupported BIOS boot mode"; exit 1
fi
log "Checking internet connection..."
ping -c 4 google.com > /dev/null 2>&1
assert_success "No internet connection"
log_ok "Internet connection is established"
log

interactively read -p "[--] Set hostname: " HOSTNAME
assert_success "Failed to read hostname"
interactively read -p "[--] Enter your username: " USERNAME
assert_success "Failed to read username"

# 2) === Partition the disks =======================================================================
# 2.1) --- Select a disk ---------------------------------------------------------------------------
log_attention "Select a disk to install to:"
interactively lsblk -pdno NAME,SIZE,TYPE
interactively read -p "Enter the disk to use (e.g., /dev/sda): " DESTINATION_DISK 

if [ -z $DESTINATION_DISK ]; then
    log_error "'$DESTINATION_DISK' doesn't exist"; exit 1
fi

ls $DESTINATION_DISK > /dev/null 2>&1
assert_success "'$DESTINATION_DISK' doesn't exist"

# todo: SATA support, current implementation will work only with nvme
PARTITION_BOOT="${DESTINATION_DISK}p1"
PARTITION_SWAP="${DESTINATION_DISK}p2"
PARTITION_ROOT="${DESTINATION_DISK}p3"

log_ok "Arch Linux will be installed to $DESTINATION_DISK"
log

# 2.2) --- Partition -------------------------------------------------------------------------------
log "Preparing disk partitions..."

# Wipe
wipefs --all --force "$DESTINATION_DISK"
sgdisk --zap-all "$DESTINATION_DISK"

# Create a new GPT partition table
parted -s "$DESTINATION_DISK" mklabel gpt

# /boot partition (1GB, FAT32 for UEFI)
parted -s "$DESTINATION_DISK" mkpart primary fat32 1MiB 1GiB
parted -s "$DESTINATION_DISK" set 1 esp on

# Swap partition (8GB)
parted -s "$DESTINATION_DISK" mkpart primary linux-swap 1GiB 9GiB

# Root (/) partition (Btrfs, using remaining space)
parted -s "$DESTINATION_DISK" mkpart primary btrfs 9GiB 100%

# 2.3) --- Format ----------------------------------------------------------------------------------
# Format boot
mkfs.fat -F32 "${PARTITION_BOOT}"
if ! check_partition "${PARTITION_BOOT}" "vfat"; then
    log_error "Failed to create boot partition"; exit 1
fi
# Format swap
mkswap "${PARTITION_SWAP}"
swapon "${PARTITION_SWAP}"
if ! check_partition "${PARTITION_SWAP}" "swap"; then
    log_error "Failed to create swap partition"; exit 1
fi
# Format root (Btrfs)
mkfs.btrfs -f "${PARTITION_ROOT}"
if ! check_partition "${PARTITION_ROOT}" "btrfs"; then
    log_error "Failed to create root partition"; exit 1
fi

# 2.4) --- Create BTRFS subvolumes -----------------------------------------------------------------
mount $PARTITION_ROOT /mnt

btrfs subvolume create /mnt/@
assert_success "Failed to create subvolume /mnt/@"

btrfs subvolume create /mnt/@home
assert_success "Failed to create subvolume /mnt/@home"

btrfs subvolume create /mnt/@log
assert_success "Failed to create subvolume /mnt/@log"

btrfs subvolume create /mnt/@cache
assert_success "Failed to create subvolume /mnt/@cache"

umount /mnt

# 2.5) --- Mount -----------------------------------------------------------------------------------
BTRFS_MOUNT_OPTIONS="noatime,compress-force=zstd:3,space_cache=v2"
mount -o $BTRFS_MOUNT_OPTIONS,subvol=@ $PARTITION_ROOT /mnt
assert_success "'$PARTITION_BOOT' failed to mount subvolume @"

mkdir -p /mnt/{boot,home,var/log,var/cache} 

mount -o $BTRFS_MOUNT_OPTIONS,subvol=@home $PARTITION_ROOT /mnt/home
assert_success "'$PARTITION_BOOT' failed to mount subvolume @home"

mount -o $BTRFS_MOUNT_OPTIONS,subvol=@log $PARTITION_ROOT /mnt/var/log
assert_success "'$PARTITION_BOOT' failed to mount subvolume @log"

mount -o $BTRFS_MOUNT_OPTIONS,subvol=@cache $PARTITION_ROOT /mnt/var/cache
assert_success "'$PARTITION_BOOT' failed to mount subvolume @cache"

mount $PARTITION_BOOT /mnt/boot
assert_success "'$PARTITION_BOOT' failed to mount"

log_ok "Disk partitions have been created and mounted"
log

# 3) === Prepare to fetch packages =================================================================
log "Preparing to fetch packages..."

# enable multilib for pacman
PACMAN_CONFIG="/etc/pacman.conf"
sed -zi "s|\s*#*\s*\(\[multilib\]\)\n\s*#*\s*\(Include = \/etc\/pacman.d\/mirrorlist\)|\n\n\1\n\2|" "$PACMAN_CONFIG"
if ! grep -Pzq "\n\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist" "$PACMAN_CONFIG"; then
    log_error "Failed to enable multilib"
fi
log_ok "Multilib has been enabled"

MIRROR_LIST="/etc/pacman.d/mirrorlist"
reflector --save $MIRROR_LIST --country $MIRRORS_COUNTRY --protocol https
assert_success "Failed to get mirrors"

log_ok "Mirrors have been updated"
log

# 4) === Install kernel ============================================================================
log "Installing base packages..."
pacstrap -K /mnt ${BASE_PACKAGES[@]}
assert_success "Failed to install base packages"
log_ok "Base packages have been installed"

cp $PACMAN_CONFIG /mnt/$PACMAN_CONFIG
assert_success "Failed to persist pacman config"

cp $MIRROR_LIST /mnt/$MIRROR_LIST
assert_success "Failed to persist mirror list"

log_ok "Pacman configuration has been persisted"
log

# 5) === System configuring ========================================================================
# 5.1) --- fstab -----------------------------------------------------------------------------------
log "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
assert_success "Failed to generate fstab"
log_ok "fstab has been generated"
log

# 5.2) --- time ------------------------------------------------------------------------------------
log "Setting up time..."
ln -sf /mnt/usr/share/zoneinfo/${TIME_ZONE_REGION} /mnt/etc/localtime
assert_success "Failed to set time zone"

for_system "hwclock --systohc"
assert_success "Failed to sync clock"

log_ok "Time has been set"
log

# 5.3) --- localization ----------------------------------------------------------------------------
log "Setting up localization..."
for i in $LOCALES; do
    sed -i "s/#${i}/${i}/g" /mnt/etc/locale.gen
done

for_system "locale-gen"
assert_success "Failed to generated locale"

for i in $LOCALES; do
    to_check=${i}
    to_check=${to_check/UTF-8/utf8}
    if ! for_system "locale -a" | grep -q "^${to_check}$"; then
        log_error "${i} is not generated"; exit 1
    fi
done

echo "LANG=${LOCALE_LANG}" >> "/mnt/etc/locale.conf"
assert_success "Failed to set locale.conf: LANG"
log_ok "Localization has been set"
log

# 5.4) --- grub boot loader with timeshift support -------------------------------------------------
log "Configuring grub with timeshift support..."
GRUB_CONFIG="/mnt/etc/default/grub"
# disable os-prober in grub config
if ! grep -q "GRUB_DISABLE_OS_PROBER" "$GRUB_CONFIG"; then
    echo "GRUB_DISABLE_OS_PROBER=true" >> "$GRUB_CONFIG"
else
    sed -ir 's/^\s*#*\s*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=true/' "$GRUB_CONFIG"
fi
if ! grep -q "^GRUB_DISABLE_OS_PROBER=true$" "$GRUB_CONFIG"; then
    log_error "Failed to disable os-prober in grub"; exit 1
fi

# enable GRUB_SAVEDEFAULT in grub config
if ! grep -q "GRUB_SAVEDEFAULT" "$GRUB_CONFIG"; then
    echo "GRUB_SAVEDEFAULT=true" >> "$GRUB_CONFIG"
else
    sed -ir 's/^\s*#*\s*GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=true/' "$GRUB_CONFIG"
fi
if ! grep -q "^GRUB_SAVEDEFAULT=true$" "$GRUB_CONFIG"; then
    log_error "Failed to enable GRUB_SAVEDEFAULT in grub"; exit 1
fi

# set GRUB_DEFAULT to saved in grub config
if ! grep -q "GRUB_DEFAULT" "$GRUB_CONFIG"; then
    echo "GRUB_DEFAULT=saved" >> "$GRUB_CONFIG"
else
    sed -ir 's/^\s*#*\s*GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' "$GRUB_CONFIG"
fi
if ! grep -q "^GRUB_DEFAULT=saved$" "$GRUB_CONFIG"; then
    log_error "Failed to set GRUB_DEFAULT to saved in grub"; exit 1
fi

# disable submenus in grub in grub config
if ! grep -q "GRUB_DISABLE_SUBMENU" "$GRUB_CONFIG"; then
    echo "GRUB_DISABLE_SUBMENU=y" >> "$GRUB_CONFIG"
else
    sed -ir 's/^\s*#*\s*GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=y/' "$GRUB_CONFIG"
fi
if ! grep -q "^GRUB_DISABLE_SUBMENU=y$" "$GRUB_CONFIG"; then
    log_error "Failed to disable submenu in grub"; exit 1
fi

for_system "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
assert_success "Failed to install grub"

for_system "timeshift --snapshot-device ${PARTITION_ROOT} --btrfs"
assert_success "Failed to initialize timeshift"

# update grub-btrfsd.service to support timeshift snapshots
GRUB_BTRFSD_SERVICE_FILE=/mnt/usr/lib/systemd/system/grub-btrfsd.service
sed -ir 's|^\(ExecStart=/usr/bin/grub-btrfsd\).*$|\1 --syslog --timeshift-auto|' "$GRUB_BTRFSD_SERVICE_FILE"
if ! grep -q "^ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto$" "$GRUB_BTRFSD_SERVICE_FILE"; then
    log_error "Failed to update grub-btrfsd.service"; exit 1
fi

for_system "grub-mkconfig -o /boot/grub/grub.cfg"
assert_success "Failed to make grub config"

log_ok "Grub with timeshift support has been configured"
log

# 5.5) --- hostname --------------------------------------------------------------------------------
echo "${HOSTNAME}" >> /mnt/etc/hostname
assert_success "Failed to set hostname"
log_ok "Hostname has been set"
log

# 5.6) --- create user with sudo permissions -------------------------------------------------------
# create user and add to group wheel (for sudo permissions)
for_system "useradd -m -G wheel -s /bin/bash ${USERNAME}"
assert_success "Failed to create a user"

# allow sudo for wheel group 
SUDOERS=/mnt/etc/sudoers
sed -ir "s|^\s*#\s*%wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|" "$SUDOERS"
if ! grep -q "^%wheel ALL=(ALL:ALL) ALL$" "$SUDOERS"; then
    log_error "Failed to add sudo permissions to ${USERNAME}"; exit 1
fi

# temporary enable passwordless sudo for create user, should be deleted on cleanup stage
PASSWORDLESS_SUDO="/mnt/etc/sudoers.d/$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > $PASSWORDLESS_SUDO

log_ok "User has been created"
log

# 6) === Installing environment ==================================================================== 
# 6.1) --- KDE Plasma with additions ---------------------------------------------------------------
log "Installing environment packages..."
PACKAGES="${ENVIRONMENT_PACKAGES[@]}"
for_system "pacman -Syu --noconfirm --needed $PACKAGES"
assert_success "Failed to install environment packages"
log_ok "KDE Plasma has been installed"
log

# 6.2) --- Paru for AUR packages -------------------------------------------------------------------
log "Installing paru..."
PARU_TMP_REPO="/home/$USERNAME/tmp_paru"
for_system "su - $USERNAME -c 'git clone https://aur.archlinux.org/paru.git $PARU_TMP_REPO'"
for_system "su - $USERNAME -c 'makepkg -si --noconfirm -D $PARU_TMP_REPO'"
rm -rf "$PARU_TMP_REPO"
for_system "paru --version"
assert_success "Failed to install paru"
log_ok "Paru has been installed"
log

# 7) === Installing applications ===================================================================
log "Installing application packages..."
PACKAGES="${APPLICATION_PACKAGES[@]}"
for_system "pacman -Syu --noconfirm --needed $PACKAGES"
assert_success "Failed to install environment packages"
log_ok "Applications have been installed"
log

# 8) === Installing AUR applications ===============================================================
log "Installing AUR packages..."
PACKAGES="${APPLICATION_PACKAGES[@]}"
for_system "paru -S --noconfirm --needed $PACKAGES"
assert_success "Failed to install environment packages"
log_ok "AUR packages have been installed"
log

# 9) === Enable services ===========================================================================
log "Enabling system services..."
for service in "${SERVICES[@]}"; do
    for_system "systemctl enable $service"
    assert_success "Failed to enable $service"
done
log_ok "Services have been enabled"
log

if is_asus_laptop; then
    # according to https://asus-linux.org/guides/arch-guide/ (02.03.2025)
    
    log "Detected ASUS laptop, patching the installation..."

    # add specific pacman repo
    for_system "pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35"
    assert_success "[ASUS] Failed to pacman-key --recv-keys"

    for_system "pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35"
    assert_success "[ASUS] Failed to pacman-key --finger"

    for_system "pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35"
    assert_success "[ASUS] Failed to pacman-key --lsign-key"
    
    for_system "pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35"
    assert_success "[ASUS] Failed to pacman-key --finger"

    echo "[g14]" >> /mnt/etc/pacman.conf
    assert_success "[ASUS] Failed to update pacman.conf"

    echo "Server = https://arch.asus-linux.org" >> /mnt/etc/pacman.conf
    assert_success "[ASUS] Failed to update pacman.conf"

    # install ASUS specific packages and kernel
    PACKAGES="asusctl power-profiles-daemon rog-control-center linux-g14 linux-g14-headers"
    for_system "pacman -Syu --noconfirm ${PACKAGES}"
    assert_success "[ASUS] Failed to install packages"
    for_system "systemctl enable power-profiles-daemon.service"
    assert_success "[ASUS] Failed to enable services"

    # update grub to include new kernel
    for_system "grub-mkconfig -o /boot/grub/grub.cfg"
    assert_success "[ASUS] Failed to reconfigure grub"
fi

# 10) === set passwd ===============================================================================
# set root password
log "Set password for user 'root'"
with_retry interactively for_system "passwd"
assert_success "Failed to set root password"
log_ok "Password has been set"

# set user password
log "Set password for user '${USERNAME}'"
with_retry interactively for_system "passwd ${USERNAME}"
assert_success "Failed to set ${USERNAME} password"
log_ok "Password has been set"

# Create final snapshot
for_system "timeshift --create --comments 'Initial snapshot'"
for_system "grub-mkconfig -o /boot/grub/grub.cfg"

# exit cleanup
rm -rf "$PASSWORDLESS_SUDO"
umount /mnt/boot
umount /mnt/var/cache
umount /mnt/var/log
umount /mnt/home
umount /mnt

log
log "Done"
log "Ready for reboot"
log
