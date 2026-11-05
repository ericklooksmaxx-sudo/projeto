#!/bin/bash
# Hollow Logger Daemon Launcher
cd "$(dirname "$0")"

# Ensure bundled binaries are in PATH and executable
export PATH="$(pwd)/tools:$(pwd):$PATH"
chmod +x tools/* 2>/dev/null || true

PID_FILE="bot.pid"
LOG_FILE="bot.log"

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "[*] Hollow Logger is already running with PID $OLD_PID"
        exit 0
    else
        rm -f "$PID_FILE"
    fi
fi

echo "[*] Launching Hollow Logger daemon..."
nohup python3 run.py > "$LOG_FILE" 2>&1 &
NEW_PID=$!
echo "$NEW_PID" > "$PID_FILE"
echo "[+] Hollow Logger started successfully with PID $NEW_PID"
echo "[+] Output logged to $LOG_FILE"
