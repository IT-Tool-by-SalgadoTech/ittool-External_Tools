#!/usr/bin/env bash
NL="\n"
RESULTS=()

echo ""
echo "==============================="
echo "   IT-Tool - ReadyUSB Check    "
echo "==============================="
echo ""

# --- Check 1: Root / Sudo access ---
if sudo -n true 2>/dev/null; then
    ADMIN="YES"
    echo -e "\e[32m[OK]\e[0m Admin Rights: YES (sudo available)"
else
    ADMIN="NO"
    echo -e "\e[33m[!!]\e[0m Admin Rights: NO (sudo may require password)"
fi

# --- Check 2: Shell and version ---
SHELL_VER="$SHELL ($BASH_VERSION)"
echo -e "\e[32m[OK]\e[0m Shell: $SHELL_VER"

# --- Check 3: Network - GitHub RAW reachable ---
if curl -s --max-time 5 https://raw.githubusercontent.com -o /dev/null; then
    NET="Reachable"
    echo -e "\e[32m[OK]\e[0m GitHub RAW 443: Reachable"
else
    NET="Blocked"
    echo -e "\e[33m[!!]\e[0m GitHub RAW 443: Blocked or no internet"
fi

# --- Check 4: Firewall status ---
if command -v ufw &>/dev/null; then
    FW_STATUS=$(sudo ufw status 2>/dev/null | head -1)
    echo -e "\e[32m[OK]\e[0m Firewall (UFW): $FW_STATUS"
elif command -v iptables &>/dev/null; then
    RULES=$(sudo iptables -L 2>/dev/null | grep -c "Chain" || echo "N/A")
    echo -e "\e[32m[OK]\e[0m Firewall (iptables): $RULES chains detected"
else
    echo -e "\e[33m[!!]\e[0m Firewall: No UFW or iptables found"
fi

# --- Check 5: USB Storage status ---
if lsmod | grep -q usb_storage; then
    USB="Enabled"
    echo -e "\e[32m[OK]\e[0m USB Storage: Enabled (module loaded)"
else
    USB="Disabled"
    echo -e "\e[33m[!!]\e[0m USB Storage: Disabled (module not loaded)"
fi

# --- Check 6: Top listening ports ---
PORTS=$(ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | grep -oP ':\K\d+' | sort -n | uniq | head -5 | tr '\n' ' ')
echo -e "\e[32m[OK]\e[0m Top TCP listeners: $PORTS"

echo ""
echo -e "\e[36mSummary: Admin=$ADMIN | Shell=$BASH_VERSION | RAW443=$NET | USB=$USB\e[0m"
echo ""

# --- Download PDF Manual to Desktop ---
DESKTOP="$HOME/Desktop"
mkdir -p "$DESKTOP"
PDF_URL="https://raw.githubusercontent.com/IT-Tool-by-SalgadoTech/ittool-External_Tools/main/IT-Tool%20Manual.pdf"
PDF_PATH="$DESKTOP/IT-Tool_Manual.pdf"
LOGO_URL="https://raw.githubusercontent.com/IT-Tool-by-SalgadoTech/ittool-External_Tools/main/LOGO%20VIDEO%20black.png"
LOGO_PATH="/tmp/ittool_logo.png"

echo "Downloading IT-Tool Manual to Desktop..."
if curl -sL "$PDF_URL" -o "$PDF_PATH"; then
    echo -e "\e[32m[OK]\e[0m Manual saved: $PDF_PATH"
elif wget -q "$PDF_URL" -O "$PDF_PATH"; then
    echo -e "\e[32m[OK]\e[0m Manual saved: $PDF_PATH"
else
    echo -e "\e[31m[!!]\e[0m Could not download PDF. Check internet connection."
fi

# Download logo for popup
curl -sL "$LOGO_URL" -o "$LOGO_PATH" 2>/dev/null || wget -q "$LOGO_URL" -O "$LOGO_PATH" 2>/dev/null

# --- Welcome Popup ---
if command -v zenity &>/dev/null && [ -n "$DISPLAY$WAYLAND_DISPLAY" ]; then
    zenity --info \
        --title="IT-Tool - Welcome to ReadyUSB" \
        --text="✅ The environment is ready!\n\nThe ReadyUSB Manual is now on your Desktop.\n\n📄 IT-Tool_Manual.pdf" \
        --width=400 --height=160 --timeout=6 2>/dev/null &
elif command -v notify-send &>/dev/null; then
    notify-send "IT-Tool - Welcome to ReadyUSB" "✅ Environment ready!\nManual saved to Desktop." --expire-time=6000 2>/dev/null &
fi

# --- Open the PDF ---
echo ""
echo "Opening IT-Tool Manual..."
if [ -f "$PDF_PATH" ]; then
    xdg-open "$PDF_PATH" 2>/dev/null || \
    evince "$PDF_PATH" 2>/dev/null || \
    okular "$PDF_PATH" 2>/dev/null || \
    zathura "$PDF_PATH" 2>/dev/null || \
    echo "PDF saved to Desktop. Open manually: $PDF_PATH"
fi

echo ""
echo "==============================="
echo "  IT-Tool - Welcome to ReadyUSB"
echo "  The environment is ready!"
echo "  Manual is on the Desktop!!"
echo "==============================="
