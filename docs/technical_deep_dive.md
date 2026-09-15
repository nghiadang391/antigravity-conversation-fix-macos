# Antigravity Architecture & Technical Deep Dive

This document details the underlying data structures, database schemas, protobuf serializations, process concurrency behavior, and title/workspace resolution algorithms used by Antigravity IDE and this repair tool.

---

## 1. Storage Architecture

Antigravity persists state across two distinct layers on disk:

### A. Raw Conversation & Brain History
Located in the user profile:
- **Windows**: `%USERPROFILE%\.gemini\antigravity-ide\` (or `antigravity\`)
- **macOS / Linux**: `~/.gemini/antigravity-ide/` (or `antigravity/`)

Contains:
1. **`conversations/`**:
   - **Legacy Format (`*.pb`)**: Protocol Buffers encoded binary dumps representing conversation checkpoints.
   - **Modern Format (`*.db`)**: SQLite 3 database files per conversation, storing granular turn-by-turn history in step tables (with `step_type=14` storing prompt metadata).
2. **`brain/`**:
   - Organized by conversation UUID (e.g. `~/.gemini/antigravity-ide/brain/<uuid>/`).
   - Stores markdown artifacts (`implementation_plan.md`, `walkthrough.md`, `research_notes.md`) and conversation execution logs/transcripts (`transcript.jsonl`).

### B. Workspace & Global SQLite Index (`state.vscdb`)
Located in application data:
- **Windows**: `%APPDATA%\Antigravity IDE\User\`
- **macOS**: `~/Library/Application Support/Antigravity IDE/User/`
- **Linux**: `~/.config/Antigravity IDE/User/`

Contains:
1. **`globalStorage/state.vscdb`**:
   - The primary SQLite database containing `ItemTable`.
   - Key: `antigravityUnifiedStateSync.trajectorySummaries`.
   - Value: Base64-encoded protobuf binary stream containing the full list of all known trajectories/conversations, their display titles, timestamps, and workspace mappings.
2. **`workspaceStorage/<workspace_id>/state.vscdb`**:
   - Workspace-scoped SQLite databases mapping specific workspace configurations (`workspace.json`).

---

## 2. Protobuf Wire Specification

The `antigravityUnifiedStateSync.trajectorySummaries` database key stores a base64-encoded outer protobuf message that repeatedly packs individual trajectory summaries.

### Outer Envelope
Repeated length-delimited field `1`:
```protobuf
message TrajectorySummariesList {
  repeated TrajectorySummaryEntry entries = 1;
}

message TrajectorySummaryEntry {
  string conversation_id = 1;      // UUID or legacy ID
  TrajectoryInnerWrapper info = 2; // Length-delimited container
}

message TrajectoryInnerWrapper {
  string base64_payload = 1;       // String holding base64-encoded bytes of CascadeTrajectorySummary
}
```

### Inner Payload (`CascadeTrajectorySummary`)
Decoded from `base64_payload`:
- **Field 1 (`string`)**: Conversation title displayed in the IDE sidebar.
- **Field 2 (`varint`)**: Step count.
- **Field 3 (`Timestamp`)**: Updated at (`seconds` as int64, `nanos` as int32).
- **Field 4 (`string`)**: Trajectory ID / UUID.
- **Field 5 (`varint`)**: Status enum (e.g. active, completed).
- **Field 7 (`Timestamp`)**: Created at (`seconds`, `nanos`).
- **Field 9 (`CortexWorkspaceMetadata`)**: Workspace scoping message:
  - **Sub-field 1 (`string`)**: `workspaceFolderAbsoluteUri` (e.g. `file:///Users/username/Project` or `vscode-remote://...`).
  - **Sub-field 2 (`string`)**: `gitRootAbsoluteUri`.
- **Field 10 (`Timestamp`)**: Client timestamp.
- **Field 17 (`TrajectoryMetadata`)**:
  - **Sub-field 3 (`string`)**: Cascade ID.
  - **Sub-field 6 (`string`)**: Trajectory ID.
- **Field 22 (`varint`)**: Trajectory type enum.

---

## 3. Title Resolution Strategy

When the index is rebuilt or missing conversations are re-indexed, titles are derived deterministically using the following hierarchy:

1. **Existing Database Titles (`[~]`)**: Canonical titles already saved in `state.vscdb` are preserved across runs to prevent overwriting user edits.
2. **Brain Artifact Headings (`[+]`)**: If unindexed, parses markdown headers (`# <Title>`) in the conversation's `brain/` directory (e.g., from `implementation_plan.md` or `task.md`).
3. **First Valid User Prompt (`[=]`)**:
   - For `.db` conversations: Extracts the first ordered `step_payload` with `step_type=14`, decoding the raw user prompt.
   - For `.pb` conversations: Extracts the first `USER_EXPLICIT` or `USER_INPUT` entry from the conversation transcript.
   - Normalizes text: strips markdown headers, simplifies links to domains, extracts the first concise sentence (up to 60 characters / 10 words).
4. **Fallback Placeholder (`[?]`)**: `Conversation (Month Day) <short-id>`.

---

## 4. Workspace Mapping & Inference

Antigravity IDE filters conversation history based on the active workspace using internal filtering logic:
```javascript
// From workbench internal agent:
function isWorkspaceMatch(trajectory, currentWorkspace) {
    return trajectory.workspaceUri === currentWorkspace.uri;
}
```

When rebuilding:
1. The tool loads all registered workspace roots from `workspaceStorage/*/workspace.json`.
2. For unmapped conversations, it scans brain artifact markdown files for referenced `file:///` and `vscode-remote://` paths.
3. It determines the best matching workspace root (longest prefix match) and encodes it into Field 9 (`CortexWorkspaceMetadata`).
4. On macOS and Linux, the tool supports both local paths and remote container/SSH/WSL URI schemes (`vscode-remote://`).

---

## 5. Concurrency & SQLite State Locking

### The Process Conflict
Antigravity IDE (built on Electron) maintains SQLite connections with Write-Ahead Logging (`WAL`) and in-memory caches. If a script updates `state.vscdb` while Antigravity IDE is running:
1. SQLite locks or file contention can cause write collisions.
2. More critically, when Antigravity IDE exits or reloads, it writes its in-memory snapshot back to `state.vscdb`, immediately overwriting any external changes.

### Process Detection
To guarantee safe repairs, the tool checks whether Antigravity processes are active before touching the database:
- **Windows**: Checks `tasklist` for `antigravity.exe` and `antigravity ide.exe`.
- **WSL**: Checks both Windows host tasks and Linux processes.
- **macOS**: Checks `pgrep -x` across binary and helper variants (`Antigravity IDE`, `Antigravity IDE Helper`, `antigravity`, etc.).
