My personal script to install Arch Linux

Start from arch live:
curl -sSL https://raw.githubusercontent.com/JackLas/personal_archinstall/refs/heads/master/install.sh -o install.sh && chmod +x ./install.sh && ./install.sh

What does it do:
- Detects UEFI/BIOS boot mode and adapts accordingly
- Creates /boot partition for 1GiB (1MiB -> 1GiB): FAT32 for UEFI with GPT, ext4 for BIOS with MBR
- Creates swap partition fir 8GiB (1Gib -> 9GiB)
- Creates / parition for rest of space (9GiB -> rest-of-space): BTRFS
