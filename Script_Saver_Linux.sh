#!/usr/bin/env bash
[[ "$EUID" -ne 0 ]] && SUDO="sudo" || SUDO=""

echo ""
echo "======================================"
echo "   IT-Tool - ReadyUSB Script Saver"
echo "======================================"
echo ""

# ============================================================
#  STEP 0 — CONNECT IT-TOOL
# ============================================================
echo -e "\e[33mBefore continuing:\e[0m"
echo "  1. Unplug the IT-Tool USB cable"
echo "  2. Plug it back in"
echo ""
read -p "Come back here and press ENTER"

# ============================================================
#  STEP 1 — DETECT COM PORT
# ============================================================
echo ""
PORTS=($(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null))

if [ ${#PORTS[@]} -eq 0 ]; then
    echo -e "\e[31mNo serial ports detected. Check IT-Tool USB connection.\e[0m"
    read -p "Press ENTER to close"
    exit 1
fi

echo -e "\e[36mAvailable serial ports:\e[0m"
for i in "${!PORTS[@]}"; do
    echo "  $((i+1)). ${PORTS[$i]}"
done
echo ""

COM_PORT=""
while [ -z "$COM_PORT" ]; do
    read -p "Select port number: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#PORTS[@]}" ]; then
        COM_PORT="${PORTS[$((choice-1))]}"
    else
        echo -e "\e[33m  Invalid option.\e[0m"
    fi
done
echo -e "\e[32mUsing $COM_PORT\e[0m"
echo ""

# ============================================================
#  STEP 2 — CONTROLLED RESET
#  Disable hupcl first, then re-enable it momentarily to
#  trigger ESP32 reset — same effect as PS1 Open/Close
# ============================================================
echo -e "\e[33mIT-Tool reset, Please come to:\e[0m"
python3 - "$COM_PORT" << 'PYSCRIPT'
import sys, time, os, termios

port = sys.argv[1]
try:
    # Open the port raw — this alone may trigger reset on some chips
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    # Set 115200 baud, 8N1
    import tty
    tty.setraw(fd)
    attrs = termios.tcgetattr(fd)
    attrs[4] = termios.B115200  # ispeed
    attrs[5] = termios.B115200  # ospeed
    # Enable HUPCL so closing the fd drops DTR → triggers ESP32 reset
    attrs[2] |= termios.HUPCL
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    time.sleep(0.1)
    os.close(fd)   # closing with HUPCL active drops DTR → ESP32 resets
    time.sleep(0.5)
except Exception as e:
    print(f"Reset warning: {e}", file=sys.stderr)
PYSCRIPT
echo -e "\e[32mReadyUSB > Script_Saver.\e[0m"
echo ""
read -p "Press ENTER when IT-Tool shows 'Waiting...'"
echo ""

# ============================================================
#  STEP 3 — FILE NAME
# ============================================================
FILE_NAME=""
while [ -z "$FILE_NAME" ]; do
    read -p "Enter file name (without extension): " FILE_NAME
    FILE_NAME="${FILE_NAME// /_}"
done

# ============================================================
#  STEP 4 — SCRIPT TYPE (controls transmission method)
# ============================================================
echo ""
echo -e "\e[36mWhat type of script are you saving?\e[0m"
echo "  1. Windows"
echo "  2. Linux"
echo ""

SCRIPT_TYPE=""
while [ -z "$SCRIPT_TYPE" ]; do
    read -p "Script type: " st
    case "$st" in
        1) SCRIPT_TYPE="Windows" ;;
        2) SCRIPT_TYPE="Linux" ;;
        *) echo -e "\e[33m  Invalid option.\e[0m" ;;
    esac
done
echo -e "\e[32mScript type: $SCRIPT_TYPE\e[0m"
echo ""

# ============================================================
#  STEP 5 — DESTINATION FOLDER (independent of script type)
# ============================================================
echo -e "\e[36mChoose destination folder:\e[0m"
echo ""
echo "  Windows folders:"
echo "    1. B.Admin_And_Security"
echo "    2. C.Networks"
echo "    3. D.Folder_and_Files"
echo "    4. E.Storage"
echo "    5. F. Monitoring"
echo "    6. G.External_links_tools"
echo "    7. H.Nmap"
echo "    8. I.App_Downloader"
echo ""
echo "  Linux folders:"
echo "    11. A.Admin_And_Security"
echo "    12. B.Networks"
echo "    13. C.Folders_and_Files"
echo "    14. D.Storage"
echo "    15. E.Monitoring"
echo "    16. F.External_links_tools"
echo "    17. G.Nmap"
echo "    18. H.Kali_Linux"
echo ""
echo "   0. Favorites"
echo ""

TARGET_FOLDER=""
while [ -z "$TARGET_FOLDER" ]; do
    read -p "Folder number: " fc
    case "$fc" in
        1)  TARGET_FOLDER="B.OS_System/A.Windows/B.Admin_And_Security" ;;
        2)  TARGET_FOLDER="B.OS_System/A.Windows/C.Networks" ;;
        3)  TARGET_FOLDER="B.OS_System/A.Windows/D.Folder_and_Files" ;;
        4)  TARGET_FOLDER="B.OS_System/A.Windows/E.Storage" ;;
        5)  TARGET_FOLDER="B.OS_System/A.Windows/F. Monitoring" ;;
        6)  TARGET_FOLDER="B.OS_System/A.Windows/G.External_links_tools" ;;
        7)  TARGET_FOLDER="B.OS_System/A.Windows/H.Nmap" ;;
        8)  TARGET_FOLDER="B.OS_System/A.Windows/I.App_Downloader" ;;
        11) TARGET_FOLDER="B.OS_System/B.Linux/A.Admin_And_Security" ;;
        12) TARGET_FOLDER="B.OS_System/B.Linux/B.Networks" ;;
        13) TARGET_FOLDER="B.OS_System/B.Linux/C.Folders_and_Files" ;;
        14) TARGET_FOLDER="B.OS_System/B.Linux/D.Storage" ;;
        15) TARGET_FOLDER="B.OS_System/B.Linux/E.Monitoring" ;;
        16) TARGET_FOLDER="B.OS_System/B.Linux/F.External_links_tools" ;;
        17) TARGET_FOLDER="B.OS_System/B.Linux/G.Nmap" ;;
        18) TARGET_FOLDER="B.OS_System/B.Linux/H.Kali_Linux" ;;
        0)  TARGET_FOLDER="Favorites" ;;
        *)  echo -e "\e[33m  Invalid option.\e[0m" ;;
    esac
done

echo -e "\e[32mDestination: $TARGET_FOLDER\e[0m"
echo ""

# ============================================================
#  STEP 6 — PASTE YOUR SCRIPT
# ============================================================
echo -e "\e[36mPaste your script below.\e[0m"
echo -e "\e[33mWhen finished type exactly:  ITTOOL  and press Enter\e[0m"
echo ""

LINES=()
while IFS= read -r line; do
    [ "$line" = "ITTOOL" ] && break
    LINES+=("$line")
done

# Strip trailing empty lines
while [ ${#LINES[@]} -gt 0 ] && [ -z "${LINES[-1]}" ]; do
    unset 'LINES[-1]'
done

USER_TEXT=$(printf '%s\n' "${LINES[@]}")

if [ -z "$USER_TEXT" ]; then
    echo -e "\e[31mERROR: No content entered.\e[0m"
    read -p "Press ENTER to close"
    exit 1
fi

# ============================================================
#  STEP 7 — BUILD THE PACKET
#  Windows → classic STRINGLN Ducky packet (unchanged)
#  Linux   → TYPE:LINUX_SH packet:
#             DATA  = short Ducky .txt that finds and runs the .sh from SD
#             SHDATA = full bash content saved hidden as .sh on SD
# ============================================================

if [ "$SCRIPT_TYPE" = "Windows" ]; then

    DUCK="DELAY 1000
STRINGLN
${USER_TEXT}
END_STRINGLN"

    PACKET="FOLDER:${TARGET_FOLDER}
NAME:${FILE_NAME}
DATA:
${DUCK}
END_SCRIPT_SAVER
"

else

    # Linux: base64 encode script, inject as one STRING line, save to /tmp and execute
    # Saving first (> /tmp) gives bash a proper stdin for read -p and interactive commands
    B64=$(printf '%s' "${USER_TEXT}" | base64 -w 0)
    DUCK="DELAY 800
STRING echo ${B64} | base64 -d > $HOME/ittool_run.sh && sh $HOME/ittool_run.sh
ENTER"

    PACKET="FOLDER:${TARGET_FOLDER}
NAME:${FILE_NAME}
DATA:
${DUCK}
END_SCRIPT_SAVER
"

fi

BYTE_COUNT=${#PACKET}
echo ""
echo -e "\e[36mPacket size: $BYTE_COUNT bytes\e[0m"

# ============================================================
#  STEP 8 — SEND
# ============================================================
echo ""
echo -e "\e[33mSending to IT-Tool...\e[0m"

TOTAL=${#PACKET}
echo "Packet: $TOTAL bytes — sending via Serial..."

python3 - "$COM_PORT" "$PACKET" << 'PYSEND'
import sys, time, os, termios, tty

port   = sys.argv[1]
packet = sys.argv[2]
data   = packet.encode('utf-8')
total  = len(data)
chunk  = 128

try:
    # Open port and DISABLE HUPCL before anything else
    # HUPCL = drop DTR on close → causes ESP32 reset
    # We disable it so open/close never resets the device
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    tty.setraw(fd)
    attrs = termios.tcgetattr(fd)
    attrs[4] = termios.B115200   # ispeed
    attrs[5] = termios.B115200   # ospeed
    attrs[2] &= ~termios.HUPCL   # DISABLE HUPCL → no DTR drop → no ESP32 reset
    # Also disable flow control
    attrs[2] &= ~termios.CRTSCTS if hasattr(termios, 'CRTSCTS') else attrs[2]
    attrs[0] &= ~(termios.IXON | termios.IXOFF)
    termios.tcsetattr(fd, termios.TCSANOW, attrs)

    time.sleep(0.3)  # wait for IT-Tool to be ready in Script_Saver mode

    # Write in chunks
    offset = 0
    while offset < total:
        end   = min(offset + chunk, total)
        os.write(fd, data[offset:end])
        offset = end
        pct = int(offset * 100 / total)
        print(f"  Sent {offset} / {total} bytes ({pct}%)")
        time.sleep(0.08)

    time.sleep(1.5)
    # Close WITHOUT dropping DTR (HUPCL is disabled)
    os.close(fd)
    print("Transfer complete.")

except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYSEND

echo ""
echo -e "\e[32mDone! Script '$FILE_NAME' sent to ReadyUSB > $TARGET_FOLDER\e[0m"

echo ""
read -p "Press ENTER to close"
