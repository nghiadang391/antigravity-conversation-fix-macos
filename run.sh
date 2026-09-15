#!/usr/bin/env bash
set -e

# Change directory to the folder where run.sh is located
cd "$(dirname "$0")"

echo ""
echo " ╔══════════════════════════════════════════════════════════╗"
echo " ║         Antigravity Conversation Fix (macOS/Linux)       ║"
echo " ║         Fixes missing/unordered conversation history     ║"
echo " ╚══════════════════════════════════════════════════════════╝"
echo ""
echo " IMPORTANT: Make sure Antigravity is FULLY CLOSED (Cmd + Q) before continuing!"
echo ""
read -p " Press [Enter] when Antigravity is closed to start..." _unused
echo ""

if command -v python3 &> /dev/null; then
    python3 rebuild_conversations.py
elif command -v python &> /dev/null; then
    python rebuild_conversations.py
else
    echo " Error: Python 3 was not found. Please install Python 3.7+ and try again."
    exit 1
fi

echo ""
echo " ────────────────────────────────────────────────────────────"
echo ""
echo " ★ If this tool helped you, please star the GitHub repo"
echo "   so other users can find it too!"
echo ""
echo " ────────────────────────────────────────────────────────────"
echo ""
