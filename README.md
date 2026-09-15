# Antigravity Conversation Fix (macOS & Cross-Platform)

[![Tests](https://github.com/nghiadang391/antigravity-conversation-fix-macos/actions/workflows/ci.yml/badge.svg)](https://github.com/nghiadang391/antigravity-conversation-fix-macos/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Did your Antigravity conversation history disappear? Are conversations showing out of order, missing titles, or lost from your workspace?

This tool reconstructs the conversation index directly from your local `~/.gemini/` storage and repairs Antigravity's internal SQLite database (`state.vscdb`), fully restoring your conversations sorted by date with proper workspace mappings.

---

## ⚡ Quick Start

### 🍏 macOS / 🐧 Linux

1. **Quit Antigravity completely** (`Cmd + Q`).
2. Clone this repo and run:
   ```bash
   git clone git@github.com:nghiadang391/antigravity-conversation-fix-macos.git
   cd antigravity-conversation-fix-macos
   ./run.sh
   ```
   *(Or run directly: `python3 rebuild_conversations.py`)*
3. When prompted:
   - Press **Enter** (or `1`) to auto-assign workspaces based on conversation project artifacts.
   - Or press `2` to manually assign any unmapped conversations.
4. Launch Antigravity — your conversation history is back!

---

### 🪟 Windows / WSL

- **Windows**: Close Antigravity and double-click `run.bat` or run `python rebuild_conversations.py`.
- **WSL**: Close Antigravity on Windows, then run `python3 rebuild_conversations.py` directly inside your WSL terminal (auto-resolves Windows `%APPDATA%`).

---

## ✨ Features

- **macOS & Linux Native Support**: Full process lifecycle detection and path resolution (`~/Library/Application Support/Antigravity IDE`).
- **Dual Format Support**: Supports both legacy protobuf (`.pb`) and modern SQLite (`.db`) conversation files.
- **Smart Workspace Mapping**: Injects `CortexWorkspaceMetadata` (`field 9`) so conversations appear in the correct workspace sidebar.
- **Deterministic Title Recovery**:
  1. Preserves existing canonical titles from SQLite (`state.vscdb`).
  2. Extracts titles from markdown artifact headers in `brain/`.
  3. Derives concise titles from the first user request in `.db` / `.pb` history.
- **Multi-Database & Multi-Folder Merge**: Automatically merges and deduplicates conversations across `antigravity`, `antigravity-ide`, and backup directories.
- **Safe & Reversible**: Saves an automatic timestamped backup (`trajectorySummaries_backup_*.txt`) before applying any modifications.

---

## 📖 Deep Dive & Documentation

For detailed analysis of Antigravity's SQLite storage architecture, protobuf message wire schemas, process concurrency locks, and workspace filtering logic, see:

👉 **[Technical Architecture & Deep Dive](docs/technical_deep_dive.md)**

---

## ❓ FAQ

**Q: Do I need to quit Antigravity before running this?**  
**A:** Yes. Antigravity buffers chat history in memory and will overwrite the SQLite database when closed. Always quit Antigravity completely (`Cmd + Q` on macOS) before running the tool.

**Q: Can I undo the changes?**  
**A:** Yes. The tool creates a timestamped backup before writing. You can restore your original state from the backup file if needed.

**Q: Does this modify my actual conversation transcripts?**  
**A:** No. Your conversation files in `~/.gemini/antigravity-ide/conversations/` and `brain/` are strictly read-only. Only the sidebar index in `state.vscdb` is reconstructed.

---

## 📄 License

MIT License. Free to use, modify, and distribute.
