My personal script to install Arch Linux

Start from arch live:
```
curl -sSL https://raw.githubusercontent.com/JackLas/personal_archinstall/refs/heads/master/install.sh -o install.sh
chmod +x ./install.sh
./install.sh
```

What does it do:
TBA

ToDo:
- Add BIOS/UEFI support (only UEFI at the moment) 
- Add SATA/NVME support (only NVME at the moment)
- Add Intel/AMD microcode support (only AMD at the moment)
- Add helper for WiFi connect