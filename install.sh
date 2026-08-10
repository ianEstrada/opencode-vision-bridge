#!/usr/bin/env bash
# ============================================================
#  Vision Agent - one-line installer (macOS / Linux)
#  by Lightning Solutions
#
#  Usage (copy-paste into a terminal):
#    curl -fsSL https://raw.githubusercontent.com/ianEstrada/opencode-vision-bridge/master/install.sh | bash
#
#  What it does:
#    1. Downloads the plugin, sub-agent and command from the repo
#    2. Installs them into the OpenCode config directory
#    3. Automatically edits opencode.json (backup first):
#       - adds "vision": "allow" to the orchestrator's permission.task
#       - appends the Image Vision Handoff rule to the orchestrator prompt
#    4. Runs a self-check
# ============================================================

set -euo pipefail

REPO_BASE="https://raw.githubusercontent.com/ianEstrada/opencode-vision-bridge/master"
CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
PLUGINS_DIR="$CONFIG_DIR/plugins"
AGENTS_DIR="$CONFIG_DIR/agent"
COMMANDS_DIR="$CONFIG_DIR/command"
CONFIG_PATH="$CONFIG_DIR/opencode.json"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { printf "${GREEN}[ OK ]${NC} %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; }
info() { printf "${YELLOW}[INFO]${NC} %s\n" "$1"; }

echo ""
echo "======================================"
echo "  Vision Agent - by Lightning Solutions"
echo "======================================"
echo ""

# ---------- 1. install files ----------
mkdir -p "$PLUGINS_DIR" "$AGENTS_DIR" "$COMMANDS_DIR"

install_repo_file() {
  local remote="$1" dest="$2" label="$3"
  if [ -f "$dest" ]; then
    ok "$label already installed: $dest"
    return
  fi
  if curl -fsSL "$REPO_BASE/$remote" -o "$dest" 2>/dev/null; then
    ok "$label installed -> $dest"
  else
    fail "$label download failed: $REPO_BASE/$remote"
    exit 1
  fi
}

install_repo_file "plugin/vision-bridge.ts"  "$PLUGINS_DIR/vision-bridge.ts"  "Plugin"
install_repo_file "agent/vision.md"          "$AGENTS_DIR/vision.md"          "Sub-agent"
install_repo_file "command/vision-config.md" "$COMMANDS_DIR/vision-config.md" "Command"

# ---------- 2. edit opencode.json ----------
VISION_RULE=$(cat <<'EOF'

### Image Vision Handoff (MANDATORY)

When the user attaches or pastes an image in a message (image file part, screenshot, or image in chat) and you cannot see its content:
1. If the message contains the placeholder `[Image attached - Vision Agent by Lightning Solutions (see analysis). Image path: <path>]`, ALWAYS delegate to the `vision` sub-agent (multimodal MiMo-V2.5): pass the `Image path: <path>` value from the placeholder as the file path in the delegation prompt, ask for a detailed description in the user's language, and use its report as your understanding of the image. This is the PRIMARY path - do not skip it.
2. If a FULL text description was injected instead (part starting with `[Image attached - described by vision model]:` followed by a real description), use that description directly and do NOT delegate.
3. Never claim to have seen an image you have not seen.
EOF
)

EDITED=false

if [ -f "$CONFIG_PATH" ]; then
  BACKUP="$CONFIG_PATH.vision-backup"
  if [ ! -f "$BACKUP" ]; then
    cp "$CONFIG_PATH" "$BACKUP"
    info "Backup created: $BACKUP"
  fi

  # Use python3 (common on macOS/Linux) for safe JSON editing; fallback: jq
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$CONFIG_PATH" "$VISION_RULE" <<'PYEOF'
import json, sys

config_path, rule = sys.argv[1], sys.argv[2]
with open(config_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

edited = False
edited_agents = []
agents = cfg.get("agent", {})

# Edit EVERY agent that has a permission.task block (option C):
# any agent that can delegate (plan, build, gentle-orchestrator, ...)
# gets the vision permission and the Handoff rule, so pasting an
# image works regardless of which agent the user talks to.
for name, agent in agents.items():
    if not isinstance(agent, dict):
        continue
    perm = agent.get("permission", {})
    task = perm.get("task", {})
    if not isinstance(task, dict):
        print(f"[INFO] Skipping '{name}' (no permission.task)")
        continue
    # 2a. permission.task -> vision: allow
    if "vision" not in task:
        task["vision"] = "allow"
        perm["task"] = task
        agent["permission"] = perm
        edited = True
        print(f"[ OK ] Permission added: {name}.permission.task.vision = allow")
    else:
        print(f"[INFO] Permission vision already present in '{name}'")
    # 2b. append the vision rule to the prompt
    if isinstance(agent.get("prompt"), str):
        if "Image Vision Handoff" not in agent["prompt"]:
            agent["prompt"] = agent["prompt"].rstrip() + "\n\n" + rule.strip()
            edited = True
            print(f"[ OK ] Vision Handoff rule appended to '{name}' prompt")
        else:
            print(f"[INFO] Vision Handoff rule already present in '{name}'")
    edited_agents.append(name)

if not edited_agents:
    print("[WARN] No agent with permission.task found - add config manually (see config/opencode.json.md)")

if edited:
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    print("[ OK ] opencode.json updated")
else:
    print("[INFO] opencode.json already configured")
PYEOF
  elif command -v jq >/dev/null 2>&1; then
    info "python3 not found, using jq (permission edit only - rule must be added manually)"
    # add vision allow to EVERY permission.task present (option C)
    jq '.agent |= with_entries(.value.permission.task.vision = "allow")' "$CONFIG_PATH" > "$CONFIG_PATH.tmp" && mv "$CONFIG_PATH.tmp" "$CONFIG_PATH"
    ok "opencode.json updated (permission on all agents)"
  else
    info "Neither python3 nor jq found - opencode.json NOT edited automatically"
    info "See config/opencode.json.md for the manual changes"
  fi

  # validate
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$CONFIG_PATH" 2>/dev/null; then
      ok "opencode.json is valid JSON"
    else
      fail "opencode.json INVALID after edit - restoring backup"
      cp "$BACKUP" "$CONFIG_PATH"
      exit 1
    fi
  fi
else
  info "opencode.json not found at $CONFIG_PATH"
  info "Create it with the content from config/opencode.json.md in the repo."
fi

# ---------- 3. self-check ----------
echo ""
echo "Self-check:"
[ -f "$PLUGINS_DIR/vision-bridge.ts" ]  && ok "Plugin present"  || fail "Plugin missing"
[ -f "$AGENTS_DIR/vision.md" ]          && ok "Sub-agent present" || fail "Sub-agent missing"
[ -f "$COMMANDS_DIR/vision-config.md" ] && ok "Command present"  || fail "Command missing"

echo ""
echo "======================================"
echo "  INSTALLATION COMPLETE"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Restart OpenCode (config does not hot-reload)"
echo "  2. In the chat, run:  /vision-config"
echo "  3. Paste an image and enjoy the analysis"
echo ""
