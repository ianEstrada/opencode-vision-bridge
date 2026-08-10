<div align="center">

<img src="banner.png" alt="Vision Agent by Lightning Solutions" width="100%">

**Give eyes to OpenCode models that cannot see images.**

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue.svg)]()
[![OpenCode](https://img.shields.io/badge/OpenCode-1.18%2B-cyan.svg)]()

</div>

Vision Agent gives eyes to OpenCode models that cannot see images. When you paste
a screenshot into the chat with a non-multimodal model, OpenCode fails with:

```
ERROR: Cannot read "clipboard" (this model does not support image input)
```

Vision Agent solves this with a two-piece architecture designed for reliability:

| Piece | Role | Responsibility |
|---|---|---|
| `vision-bridge` plugin | Gatekeeper | Detects the pasted image, persists it to disk, replaces it with a placeholder carrying the file path. Executes in ~1ms. Makes no API calls, performs no image processing. |
| `vision` sub-agent | Brain | The orchestrator always delegates image description to this sub-agent. It runs a multimodal model (MiMo-V2.5 or Groq), reads the image from the placeholder path, and returns a detailed description. |

```
Paste image -> plugin persists to disk (1ms)
  -> placeholder with path: [Image attached - Vision Agent by Lightning Solutions (see analysis). Image path: ...]
  -> orchestrator delegates to the vision sub-agent
  -> sub-agent reads and describes -> you get the full analysis
```

---

## Requirements

- OpenCode v1.18 or newer (Windows, macOS, or Linux)
- A primary model without vision support (e.g. deepseek-flash), or the desire
  for deeper visual analysis
- One vision-capable model available to the sub-agent:
  - **MiMo-V2.5** via the `opencode-go` package (recommended: 30,100
    requests/5h, no rate-limit friction)
  - **Groq** `qwen/qwen3.6-27b` with an API key (free tier: ~8K tokens/min;
    may return HTTP 429 under load)
- A shell (PowerShell on Windows, bash on macOS/Linux) for the installer

---

## Installation

### One-line install (recommended)

Copy and paste ONE command into your terminal. It downloads everything,
installs it, edits your `opencode.json` automatically (with a backup), and
runs a self-check. No npm, no dependencies, no manual steps.

**Windows (PowerShell):**

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/ianEstrada/opencode-vision-bridge/master/install.ps1 | iex"
```

**macOS / Linux (bash):**

```bash
curl -fsSL https://raw.githubusercontent.com/ianEstrada/opencode-vision-bridge/master/install.sh | bash
```

What the installer does automatically:

1. Detects your OpenCode config directory
2. Downloads and installs `plugin/vision-bridge.ts`, `agent/vision.md`, and
   `command/vision-config.md`
3. Edits `opencode.json` (backup saved as `opencode.json.vision-backup`):
   - adds `"vision": "allow"` to your orchestrator agent's `permission.task`
   - appends the **Image Vision Handoff** rule to the orchestrator prompt
4. Validates the JSON (restores the backup if anything goes wrong)
5. Runs a self-check

Then: restart OpenCode and run `/vision-config` in the chat to choose your
vision model.

### Manual install

1. Copy `plugin/vision-bridge.ts` to `~/.config/opencode/plugins/`
2. Copy `agent/vision.md` to `~/.config/opencode/agent/`
3. Apply the configuration changes below
4. Restart OpenCode

### Configuration changes

Add to your `~/.config/opencode/opencode.json`:

**1. Allow the orchestrator to delegate to the `vision` sub-agent** (inside
your orchestrator agent's `permission.task`):

```json
"permission": {
  "task": {
    "vision": "allow"
  }
}
```

**2. Add the Image Vision Handoff rule to your orchestrator agent's prompt**:

```
### Image Vision Handoff (MANDATORY)

When the user attaches or pastes an image in a message (image file part, screenshot, or image in chat) and you cannot see its content:
1. If the message contains the placeholder `[Image attached - Vision Agent by Lightning Solutions (see analysis). Image path: <path>]`, ALWAYS delegate to the `vision` sub-agent (multimodal MiMo-V2.5): pass the `Image path: <path>` value from the placeholder as the file path in the delegation prompt, ask for a detailed description in the user's language, and use its report as your understanding of the image. This is the PRIMARY path - do not skip it.
2. If a FULL text description was injected instead (part starting with `[Image attached - described by vision model]:` followed by a real description), use that description directly and do NOT delegate.
3. Never claim to have seen an image you have not seen.
```

Full reference: `config/opencode.json.md`

### Post-install: configure the model

Inside OpenCode, run:

```
/vision-config
```

This command checks the installation state, lets you choose the vision model
(MiMo-V2.5 or Groq), and runs a self-diagnostic.

---

## Verification

1. Restart OpenCode (configuration does not hot-reload)
2. Paste an image (Ctrl+V or drag and drop)
3. Your message shows the placeholder with the image path (no clipboard error)
4. The orchestrator delegates to the vision sub-agent
5. You receive the full description or analysis of the image

The sub-agent does not only describe - you can ask it to evaluate (for example:
"evaluate this UI design" or "what does this error say?") and it returns
in-depth analysis.

---

## Conditions and limitations

- Configuration changes require an OpenCode restart to take effect.
- Pasted images are written to the system temp directory and are cleaned up
  by the OS.
- Images are NEVER resized or downscaled. Resizing degrades fine text and
  causes vision models to hallucinate details (they invent typos and characters
  that do not exist). Full resolution always wins.
- The `vision` sub-agent is read-only: it can read image files but cannot edit
  files or run commands.
- Descriptions are generated by third-party models (MiMo-V2.5, Groq). Review
  their terms of service for acceptable use of generated content.
- Vision API calls may be subject to rate limits depending on the provider
  and plan.

---

## Architecture rationale

We initially implemented automatic description inside the plugin (calling a
vision API directly). Production testing revealed multiple failure modes:

| Attempt | Failure |
|---|---|
| Call Groq from the plugin | Free-tier rate limits (HTTP 429) |
| Call MiMo via the SDK from the plugin | `session.create` does not connect in production |
| `experimental.chat.messages.transform` hook | Never injected the description in production |
| Resizing the image before sending | Degraded fine text; the model hallucinated details |

The lesson: the most failure-resistant architecture has the fewest moving
parts and uses OpenCode-native mechanisms (sub-agents), not experimental hooks
or external API calls from the plugin.

Design rules:

- NEVER resize images - full quality wins; resizing causes hallucinations
- NEVER call vision APIs from the plugin - rate limits and silent failures
- ALWAYS delegate to the vision sub-agent - a native, proven mechanism

---

## Repository structure

```
opencode-vision-bridge/
├── plugin/
│   └── vision-bridge.ts      Gatekeeper (3.3 KB, ~1ms)
├── agent/
│   └── vision.md             Brain (multimodal sub-agent)
├── command/
│   └── vision-config.md      /vision-config command for OpenCode
├── config/
│   └── opencode.json.md      Configuration reference
├── install.sh                macOS/Linux installer
├── install.ps1               Windows installer
└── README.md
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Cannot read "clipboard"` when pasting | Plugin not loaded (OpenCode not restarted) | Restart OpenCode |
| Placeholder says `Image path: unknown` | Image could not be persisted | Check write permissions on the temp directory |
| The `vision` sub-agent is not available | `agent/vision.md` missing or OpenCode not restarted | Run the installer, then restart |
| The orchestrator does not delegate | Image Vision Handoff rule missing from the prompt | Add the rule (see Configuration changes) |
| Groq returns HTTP 429 | Free-tier rate limit | Switch the sub-agent model to MiMo-V2.5 |
| The description invents text | Image was resized somewhere | Use this plugin unmodified (no resize path exists) |

---

## License

MIT - free to use, modify, and share.

---

**Vision Agent by Lightning Solutions**
