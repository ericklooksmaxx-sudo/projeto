#!/bin/bash
# Hollow Logger Stop Script
cd "$(dirname "$0")"

PID_FILE="bot.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "[*] Stopping Hollow Logger (PID $PID)..."
        kill -9 "$PID"
        rm -f "$PID_FILE"
        echo "[+] Hollow Logger stopped."
        exit 0
    else
        rm -f "$PID_FILE"
    fi
fi

# Fallback check
PID=$(pgrep -f "python3 run.py")
if [ -n "$PID" ]; then
    echo "[*] Killing remaining process (PID $PID)..."
    kill -9 $PID
    echo "[+] Done."
else
    echo "[-] Hollow Logger is not running."
fi
