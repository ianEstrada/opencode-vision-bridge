---
description: Diagnose and configure the Vision Agent (image handling for non-multimodal models). Shows installation state, lets you pick the vision model, and runs a self-check.
agent: gentle-orchestrator
---

# Vision Agent Configuration

Run a complete diagnosis and configuration of the Vision Agent setup. Work through these steps:

## 1. Diagnostic

Check the following and report the state of each:

- **Plugin**: does `~/.config/opencode/plugins/vision-bridge.ts` exist? (or `.opencode/plugins/` in the project)
- **Sub-agent**: does `~/.config/opencode/agent/vision.md` exist? (or `.opencode/agent/`)
- **Permission**: does the orchestrator's `permission.task` include `"vision": "allow"`?
- **Orchestrator rule**: does the orchestrator prompt contain the "Image Vision Handoff" section?
- **Available models**: list what vision-capable models are available (check `opencode models` output for `mimo`, `qwen`, etc.)

Report each item as OK / MISSING / FAIL.

## 2. Choose the vision model

Ask the user which vision model they want for the sub-agent:

| Option | Model | Notes |
|---|---|---|
| 1 | `opencode-go/mimo-v2.5` | Recommended if they have the opencode-go package — 30,100 req/5h |
| 2 | `opencode/mimo-v2.5-free` | OpenCode Zen — free, 200K context / 32K output, multimodal |
| 3 | `groq/qwen/qwen3.6-27b` | Requires Groq API key, free tier ~8K tokens/min |

Update `~/.config/opencode/agent/vision.md` (the `model:` line in the frontmatter) to the selected model. Confirm the change with the user before editing.

## 3. Fix anything broken

- If the plugin or sub-agent files are missing, tell the user to run the installer (`install.ps1` on Windows, `install.sh` on macOS/Linux) from the `opencode-vision-bridge` folder, or copy the files manually.
- If the permission or orchestrator rule are missing, show the user the exact JSON/prompt snippet to add (from `config/opencode.json.md`).
- Remind the user: configuration requires an OpenCode restart to take effect.

## 4. Final report

Summarize: what is working, what was changed, and the single next action the user must take (usually: restart OpenCode, then paste an image to test).
