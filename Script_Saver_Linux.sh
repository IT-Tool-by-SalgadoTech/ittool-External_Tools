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
echo "  3. On the IT-Tool go to: ReadyUSB > Script_Saver"
echo "  4. Wait until screen shows 'Waiting...'"
echo "  5. Come back here and press ENTER"
echo ""
read -p "Press ENTER when IT-Tool shows 'Waiting...'"

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
#  Toggle DTR via Python to trigger ESP32 reset
#  (same as PS1 SerialPort.Open/Close with DtrEnable=false)
# ============================================================
echo -e "\e[33mIT-Tool reset, Please come back a second time to:\e[0m"
python3 - "$COM_PORT" << 'PYSCRIPT'
import sys, time
port = sys.argv[1]
try:
    import serial
    s = serial.Serial(port, 115200, dsrdtr=False, rtscts=False)
    s.dtr = False
    s.rts = False
    time.sleep(0.05)
    s.close()
    time.sleep(0.4)
except ImportError:
    # pyserial not available — fallback: open/close via file descriptor
    import os, termios, fcntl, tty
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    # Set 115200, 8N1
    attrs[4] = termios.B115200
    attrs[5] = termios.B115200
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    time.sleep(0.05)
    os.close(fd)
    time.sleep(0.4)
except Exception as e:
    print(f"Reset warning: {e}", file=sys.stderr)
PYSCRIPT
echo -e "\e[32mReadyUSB > Script_Saver.\e[0m"
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
#  STEP 4 — SYSTEM SELECTION
# ============================================================
echo ""
echo -e "\e[36mChoose system:\e[0m"
echo "  1. Windows"
echo "  2. Linux"
echo ""

SYSTEM=""
while [ -z "$SYSTEM" ]; do
    read -p "System number: " sc
    case "$sc" in
        1) SYSTEM="Windows" ;;
        2) SYSTEM="Linux" ;;
        *) echo -e "\e[33m  Invalid option.\e[0m" ;;
    esac
done
echo -e "\e[32mSystem: $SYSTEM\e[0m"
echo ""

# ============================================================
#  STEP 5 — DESTINATION FOLDER
# ============================================================
echo -e "\e[36mChoose destination folder:\e[0m"

TARGET_FOLDER=""

if [ "$SYSTEM" = "Windows" ]; then
    echo "  1. A.Admin_And_Security"
    echo "  2. B.Networks"
    echo "  3. C.Folder_and_Files"
    echo "  4. D.Storage"
    echo "  5. E. Monitoring"
    echo "  6. F.External_links_tools"
    echo "  7. G.Nmap"
    echo "  8. H.App_Downloader"
    echo "  0. Favorites"
    echo ""
    while [ -z "$TARGET_FOLDER" ]; do
        read -p "Folder number: " fc
        case "$fc" in
            1) TARGET_FOLDER="B.Windows/A.Admin_And_Security" ;;
            2) TARGET_FOLDER="B.Windows/B.Networks" ;;
            3) TARGET_FOLDER="B.Windows/C.Folder_and_Files" ;;
            4) TARGET_FOLDER="B.Windows/D.Storage" ;;
            5) TARGET_FOLDER="B.Windows/E. Monitoring" ;;
            6) TARGET_FOLDER="B.Windows/F.External_links_tools" ;;
            7) TARGET_FOLDER="B.Windows/G.Nmap" ;;
            8) TARGET_FOLDER="B.Windows/H.App_Downloader" ;;
            0) TARGET_FOLDER="Favorites" ;;
            *) echo -e "\e[33m  Invalid option.\e[0m" ;;
        esac
    done

elif [ "$SYSTEM" = "Linux" ]; then
    echo "  1. A.Admin_And_Security"
    echo "  2. B.Networks"
    echo "  3. C.Folders_and_Files"
    echo "  4. D.Storage"
    echo "  5. E.Monitoring"
    echo "  6. F.External_links_tools"
    echo "  7. G.Nmap"
    echo "  8. H.Kali_Linux"
    echo "  0. Favorites"
    echo ""
    while [ -z "$TARGET_FOLDER" ]; do
        read -p "Folder number: " fc
        case "$fc" in
            1) TARGET_FOLDER="C.Linux/A.Admin_And_Security" ;;
            2) TARGET_FOLDER="C.Linux/B.Networks" ;;
            3) TARGET_FOLDER="C.Linux/C.Folders_and_Files" ;;
            4) TARGET_FOLDER="C.Linux/D.Storage" ;;
            5) TARGET_FOLDER="C.Linux/E.Monitoring" ;;
            6) TARGET_FOLDER="C.Linux/F.External_links_tools" ;;
            7) TARGET_FOLDER="C.Linux/G.Nmap" ;;
            8) TARGET_FOLDER="C.Linux/H.Kali_Linux" ;;
            0) TARGET_FOLDER="Favorites" ;;
            *) echo -e "\e[33m  Invalid option.\e[0m" ;;
        esac
    done
fi

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

if [ "$SYSTEM" = "Windows" ]; then

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

    # Ducky launcher — finds the .sh in the hidden .sh_scripts folder on the SD
    # Works on Ubuntu (/media/$USER/LABEL/) and Kali (/media/root/LABEL/ or /mnt/)
    DUCK='DELAY 800
CTRL ALT T
DELAY 2500
STRING for _d in /media/$USER/*/ReadyUSB/.sh_scripts/'"${TARGET_FOLDER}"' /media/root/*/ReadyUSB/.sh_scripts/'"${TARGET_FOLDER}"' /mnt/*/ReadyUSB/.sh_scripts/'"${TARGET_FOLDER}"'; do _f=$(ls "$_d"/*'"${FILE_NAME}"'*.sh 2>/dev/null | head -1); [ -f "$_f" ] && bash "$_f" && break; done
ENTER'

    PACKET="FOLDER:${TARGET_FOLDER}
NAME:${FILE_NAME}
TYPE:LINUX_SH
DATA:
${DUCK}
SHDATA:
${USER_TEXT}
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
import sys, time, os

port   = sys.argv[1]
packet = sys.argv[2]
data   = packet.encode('utf-8')
total  = len(data)
chunk  = 128

try:
    import serial

    # Open WITHOUT triggering ESP32 reset:
    # exclusive=False + set dtr/rts BEFORE open via constructor flags
    s = serial.Serial()
    s.port        = port
    s.baudrate    = 115200
    s.bytesize    = serial.EIGHTBITS
    s.parity      = serial.PARITY_NONE
    s.stopbits    = serial.STOPBITS_ONE
    s.timeout     = 3
    s.write_timeout = 5
    s.xonxoff     = False
    s.rtscts      = False
    s.dsrdtr      = False   # do NOT toggle DTR on open → no ESP32 reset
    s.open()
    # Explicitly hold DTR/RTS low after open (same as PS1 DtrEnable=$false)
    s.dtr = False
    s.rts = False
    time.sleep(0.3)  # give IT-Tool time to be ready after its own boot

    offset = 0
    while offset < total:
        end = min(offset + chunk, total)
        s.write(data[offset:end])
        s.flush()
        offset = end
        pct = int(offset * 100 / total)
        print(f"  Sent {offset} / {total} bytes ({pct}%)")
        time.sleep(0.08)

    time.sleep(1.5)
    s.close()
    print("Transfer complete.")

except ImportError:
    # pyserial not installed — use stty + raw write (no DTR toggle)
    import subprocess, termios
    subprocess.run(['stty','-F', port,'115200','cs8','-cstopb','-parenb',
                    '-crtscts','-ixon','-ixoff','raw','-hupcl'],
                   capture_output=True)
    # -hupcl = do NOT drop DTR on close/open → no ESP32 reset
    time.sleep(0.3)
    offset = 0
    with open(port, 'wb', buffering=0) as f:
        while offset < total:
            end = min(offset + chunk, total)
            f.write(data[offset:end])
            f.flush()
            offset = end
            pct = int(offset * 100 / total)
            print(f"  Sent {offset} / {total} bytes ({pct}%)")
            time.sleep(0.08)
    time.sleep(1.5)
    print("Transfer complete (fallback).")

except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYSEND

echo ""
echo -e "\e[32mDone! Script '$FILE_NAME' sent to ReadyUSB > $TARGET_FOLDER\e[0m"
if [ "$SYSTEM" = "Linux" ]; then
    echo -e "\e[36m  .txt launcher  → ReadyUSB/${TARGET_FOLDER}/\e[0m"
    echo -e "\e[36m  .sh content    → ReadyUSB/.sh_scripts/${TARGET_FOLDER}/ (hidden in IT-Tool)\e[0m"
fi
echo ""
read -p "Press ENTER to close"
