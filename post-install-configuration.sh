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

# === Helpers ======================================================================================
function ask_user() {
    local prompt="$1"
    while true; do
        interactively read -rp "$prompt (yes/no): " answer
        case "$answer" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# ==================================================================================================

# check if we are not in Arch Live
if [[ -f /run/archiso ]] || findmnt -n -o FSTYPE / | grep -q overlay; then
    echo "Should not be run in Arch Live environement -> abort";
    exit 1
fi

if ask_user "Configure firewall?"; then # ----------------------------------------------------------
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw enable
fi

if ask_user "Configre UPNP?"; then # ---------------------------------------------------------------
    # todo: adjust miniupnpd config

    sudo ufw allow 1900/udp
    sudo ufw allow 5000/tcp
    sudo ufw allow 5000/udp 

    sudo systemctl enable miniupnpd.serivce
fi

