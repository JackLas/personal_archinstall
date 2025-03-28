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
        read -rp "$prompt (yes/no): " answer
        case "$answer" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

function sudo_update_config() {
    CONFIG_FILE=$1
    FIRST_HALF_VALUE=$2
    SECOND_HALD_VALUE=$3

    if ! grep -q "${FIRST_HALF_VALUE}" "${CONFIG_FILE}"; then
        sudo sh -c "echo \"${FIRST_HALF_VALUE}${SECOND_HALD_VALUE}\" >> \"${CONFIG_FILE}\""
    else
        sudo sed -ir "s/^\s*#*\s*${FIRST_HALF_VALUE}.*/${FIRST_HALF_VALUE}${SECOND_HALD_VALUE}/" "${CONFIG_FILE}"
    fi
    if ! grep -q "^${FIRST_HALF_VALUE}${SECOND_HALD_VALUE}$" "${CONFIG_FILE}"; then
        return 1 # fail
    fi
    return 0 # success
}

# ==================================================================================================

# check if we are not in Arch Live
if [[ -f /run/archiso ]] || findmnt -n -o FSTYPE / | grep -q overlay; then
    echo "Should not be run in Arch Live environement -> abort";
    exit 1
fi

# echo "Checking internet connection..."
# ping -c 4 google.com > /dev/null 2>&1
# if [ $? -ne 0 ]; then
#     echo "Please establish internet connection"
#     exit 1
# fi

if ask_user "Configure firewall?"; then # ----------------------------------------------------------
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw enable
fi

# not clear if upnp is even needed for anything
# if ask_user "Configre UPNP?"; then # ---------------------------------------------------------------
#     sudo pacman -S miniupnpd

#     ACTIVE_CONNECTION_IFNAME=$(ip route get 1.1.1.1 | awk '{print $5}')

#     sudo ufw allow 1900/udp
#     sudo ufw allow 5000/tcp
#     sudo ufw allow 5000/udp 

#     MINIUPNPD_CONF="/etc/miniupnpd/miniupnpd.conf"
#     sudo cp -p "$MINIUPNPD_CONF" "${MINIUPNPD_CONF}.backup_$(date +'%Y-%m-%d_%H-%M-%S')"

#     sudo_update_config "$MINIUPNPD_CONF" "ext_ifname=" "${ACTIVE_CONNECTION_IFNAME}"
#     sudo_update_config "$MINIUPNPD_CONF" "enable_pcp_pmp=" "yes"
#     sudo_update_config "$MINIUPNPD_CONF" "enable_upnp=" "yes"
#     sudo_update_config "$MINIUPNPD_CONF" "uuid=" "$(uuidgen)"

#     # not possible to use sed becaue of multiple "listening_ip", so append to the end
#     sudo sh -c "echo \"listening_ip=${ACTIVE_CONNECTION_IFNAME}\" >> $MINIUPNPD_CONF"

#     sudo systemctl enable --now miniupnpd.service
# fi

