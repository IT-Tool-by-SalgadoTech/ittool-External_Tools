#!/usr/bin/env bash
[[ "$EUID" -ne 0 ]] && SUDO="sudo" || SUDO=""

echo ""
echo "======================================"
echo "   IT-Tool - ReadyUSB New Folder"
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
# ============================================================
echo -e "\e[33mIT-Tool reset, Please come to:\e[0m"
python3 - "$COM_PORT" << 'PYSCRIPT'
import sys, time, os, termios

port = sys.argv[1]
try:
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    import tty
    tty.setraw(fd)
    attrs = termios.tcgetattr(fd)
    attrs[4] = termios.B115200
    attrs[5] = termios.B115200
    attrs[2] |= termios.HUPCL
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    time.sleep(0.1)
    os.close(fd)
    time.sleep(0.5)
except Exception as e:
    print(f"Reset warning: {e}", file=sys.stderr)
PYSCRIPT
echo -e "\e[32mReadyUSB > Script_Saver.\e[0m"
echo ""
read -p "Press ENTER when IT-Tool shows 'Waiting...'"
echo ""

# ============================================================
#  STEP 3 — FOLDER NAME
# ============================================================
FOLDER_NAME=""
while [ -z "$FOLDER_NAME" ]; do
    read -p "New folder name: " FOLDER_NAME
    FOLDER_NAME="${FOLDER_NAME// /_}"
done

# ============================================================
#  STEP 4 — GROUP
# ============================================================
echo ""
echo -e "\e[36mChoose group:\e[0m"
echo "  1. Windows"
echo "  2. Linux"
echo ""

GROUP_PATH=""
while [ -z "$GROUP_PATH" ]; do
    read -p "Group: " mg
    case "$mg" in
        1) GROUP_PATH="B.OS_System/A.Windows" ;;
        2) GROUP_PATH="B.OS_System/B.Linux"   ;;
        *) echo -e "\e[33m  Invalid option.\e[0m" ;;
    esac
done

TARGET_FOLDER="${GROUP_PATH}/${FOLDER_NAME}"
echo ""
echo -e "\e[33mCreating: $TARGET_FOLDER\e[0m"

# ============================================================
#  STEP 5 — BUILD PACKET (same format as Script_Saver)
# ============================================================
PACKET="FOLDER:${TARGET_FOLDER}
NAME:.keep
DATA:
DELAY 1
END_SCRIPT_SAVER
"

BYTE_COUNT=${#PACKET}
echo ""
echo -e "\e[36mPacket size: $BYTE_COUNT bytes\e[0m"

# ============================================================
#  STEP 6 — SEND
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
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    tty.setraw(fd)
    attrs = termios.tcgetattr(fd)
    attrs[4] = termios.B115200
    attrs[5] = termios.B115200
    attrs[2] &= ~termios.HUPCL
    attrs[2] &= ~termios.CRTSCTS if hasattr(termios, 'CRTSCTS') else attrs[2]
    attrs[0] &= ~(termios.IXON | termios.IXOFF)
    termios.tcsetattr(fd, termios.TCSANOW, attrs)

    time.sleep(0.3)

    offset = 0
    while offset < total:
        end = min(offset + chunk, total)
        os.write(fd, data[offset:end])
        offset = end
        pct = int(offset * 100 / total)
        print(f"  Sent {offset} / {total} bytes ({pct}%)")
        time.sleep(0.08)

    time.sleep(1.5)
    os.close(fd)
    print("Transfer complete.")

except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYSEND

echo ""
echo -e "\e[32mDone! Folder '$FOLDER_NAME' created in $GROUP_PATH\e[0m"
echo ""
read -p "Press ENTER to close"