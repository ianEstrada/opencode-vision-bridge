#!/usr/bin/env bash
#
# Vision Agent installer - macOS / Linux
# by Lightning Solutions
#
# Usage:
#   bash install.sh
#
# Copies the vision-bridge plugin and the vision sub-agent into the
# OpenCode config directory, then prints the configuration steps and
# runs a self-check.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
PLUGINS_DIR="$CONFIG_DIR/plugins"
AGENTS_DIR="$CONFIG_DIR/agent"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_ok()   { printf "${GREEN}[ OK ]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_err()  { printf "${RED}[FAIL]${NC} %s\n" "$1"; }

echo "Vision Agent - by Lightning Solutions"
echo "-------------------------------------"

# 1. Locate the OpenCode config directory
if [ ! -d "$CONFIG_DIR" ]; then
  log_warn "OpenCode config directory not found at $CONFIG_DIR"
  if command -v opencode >/dev/null 2>&1; then
    log_ok "opencode CLI found - creating config directory"
    mkdir -p "$CONFIG_DIR"
  else
    log_err "opencode CLI not found. Install OpenCode first."
    exit 1
  fi
fi

# 2. Create the plugin and agent directories
mkdir -p "$PLUGINS_DIR" "$AGENTS_DIR"

# 3. Copy the plugin
if [ -f "$SCRIPT_DIR/plugin/vision-bridge.ts" ]; then
  cp "$SCRIPT_DIR/plugin/vision-bridge.ts" "$PLUGINS_DIR/vision-bridge.ts"
  log_ok "plugin installed -> $PLUGINS_DIR/vision-bridge.ts"
else
  log_err "plugin/vision-bridge.ts not found next to this script"
  exit 1
fi

# 4. Copy the sub-agent
if [ -f "$SCRIPT_DIR/agent/vision.md" ]; then
  cp "$SCRIPT_DIR/agent/vision.md" "$AGENTS_DIR/vision.md"
  log_ok "sub-agent installed -> $AGENTS_DIR/vision.md"
else
  log_err "agent/vision.md not found next to this script"
  exit 1
fi

# 5. Configuration instructions
echo ""
echo "Configuration (add to $CONFIG_DIR/opencode.json):"
echo " 1. Inside your orchestrator agent's permission.task, add:"
echo "       \"vision\": \"allow\""
echo " 2. Add the Image Vision Handoff rule to your orchestrator agent's prompt."
echo "    Full reference: config/opencode.json.md in this repository."
echo ""

# 6. Self-check
echo "Self-check:"
if [ -f "$PLUGINS_DIR/vision-bridge.ts" ]; then
  log_ok "plugin present"
else
  log_err "plugin missing"
fi
if [ -f "$AGENTS_DIR/vision.md" ]; then
  log_ok "sub-agent present"
else
  log_err "sub-agent missing"
fi
if command -v opencode >/dev/null 2>&1; then
  log_ok "opencode CLI available"
else
  log_warn "opencode CLI not on PATH (desktop app users can ignore this)"
fi

echo ""
log_ok "Installation complete. Restart OpenCode, then run /vision-config inside the chat."
