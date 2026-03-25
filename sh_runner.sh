#!/usr/bin/env bash
# IT-Tool sh_runner.sh
# Requests a .sh file from IT-Tool over Serial and executes it.
# Usage: bash sh_runner.sh "NNN.ScriptName.sh"

SH_FILENAME="$1"

if [ -z "$SH_FILENAME" ]; then
    echo "ERROR: No filename provided."
    exit 1
fi

# Find the IT-Tool serial port
PORTS=($(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null))
if [ ${#PORTS[@]} -eq 0 ]; then
    echo "ERROR: IT-Tool not detected on serial port."
    exit 1
fi
COM_PORT="${PORTS[0]}"

# Request and receive the .sh content via Serial
SH_CONTENT=$(python3 - "$COM_PORT" "$SH_FILENAME" << 'PYEOF'
import sys, time, os, termios, tty

port     = sys.argv[1]
filename = sys.argv[2]

try:
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    tty.setraw(fd)
    attrs = termios.tcgetattr(fd)
    attrs[4] = termios.B115200
    attrs[5] = termios.B115200
    attrs[2] &= ~termios.HUPCL
    attrs[0] &= ~(termios.IXON | termios.IXOFF)
    termios.tcsetattr(fd, termios.TCSANOW, attrs)

    time.sleep(0.3)

    # Send GET request
    req = ("GET:" + filename + "\n").encode('utf-8')
    os.write(fd, req)

    # Read response until SH_END:
    buf = b""
    deadline = time.time() + 5.0
    while time.time() < deadline:
        try:
            chunk = os.read(fd, 256)
            if chunk:
                buf += chunk
                if b"SH_END:" in buf:
                    break
        except BlockingIOError:
            time.sleep(0.05)

    os.close(fd)

    # Extract content between SH_START: and SH_END:
    text = buf.decode('utf-8', errors='replace')
    start = text.find("SH_START:\n")
    end   = text.find("\nSH_END:")
    if start >= 0 and end > start:
        print(text[start + len("SH_START:\n"):end], end='')
    else:
        print("ERROR: Invalid response from IT-Tool", file=sys.stderr)
        sys.exit(1)

except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
)

if [ -z "$SH_CONTENT" ]; then
    echo "ERROR: No content received from IT-Tool."
    exit 1
fi

# Execute the received script
echo "$SH_CONTENT" | bash
