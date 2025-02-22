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

# ====== Helpers ===============================================================

function last_command_failed() {
    if [ $? -ne 0 ]; then
        return 0
    else
        return 1
    fi
}

# ==============================================================================

# 0) todo: automate image verification before install - is it possible?

# 1) Check Internet connection
echo "[--] Checking internet connection..."
ping -c 4 google.com > /dev/null 2>&1
if last_command_failed; then
    echo "[ER] No internet connection -> abort"
    exit 1
else
    echo "[OK] Internet connection is established"
fi
