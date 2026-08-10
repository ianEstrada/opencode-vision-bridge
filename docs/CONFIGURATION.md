# Configuration Reference

Vision Agent needs two changes in your OpenCode configuration. The one-line
installer performs both automatically (with a backup); this page is the
reference for manual setups.

## 1. Allow delegation to the `vision` sub-agent

Inside your orchestrator agent's `permission.task`, add:

```json
"permission": {
  "task": {
    "vision": "allow"
  }
}
```

The installer adds this to **every** agent that has a `permission.task`
block, so pasting an image works from any agent (orchestrator, plan, build,
etc.). Agents without a `permission.task` block are left untouched.

## 2. Image Vision Handoff rule

Add this section to your orchestrator agent's prompt:

```
### Image Vision Handoff (MANDATORY)

When the user attaches or pastes an image in a message (image file part, screenshot, or image in chat) and you cannot see its content:
1. If the message contains the placeholder `[Image attached - Vision Agent by Lightning Solutions (see analysis). Image path: <path>]`, ALWAYS delegate to the `vision` sub-agent (multimodal MiMo-V2.5): pass the `Image path: <path>` value from the placeholder as the file path in the delegation prompt, ask for a detailed description in the user's language, and use its report as your understanding of the image. This is the PRIMARY path - do not skip it.
2. If a FULL text description was injected instead (part starting with `[Image attached - described by vision model]:` followed by a real description), use that description directly and do NOT delegate.
3. Never claim to have seen an image you have not seen.
```

## 3. `/vision-config` command (optional)

Copy `command/vision-config.md` to `~/.config/opencode/command/` (or
`.opencode/command/` in your project). After restarting, run `/vision-config`
in the chat to:

- Check the installation state (plugin, sub-agent, permission, rule)
- Choose the vision model (MiMo-V2.5 or Groq)
- Fix anything missing and get a final diagnostic report

## 4. Groq provider (only if using Groq as the vision model)

```json
"provider": {
  "groq": {
    "models": {
      "qwen/qwen3.6-27b": {
        "attachment": true
      }
    }
  }
}
```

## Important

- Configuration is loaded once at startup — restart OpenCode after changes.
- The installer backs up your config as `opencode.json.vision-backup` before
  editing and restores it automatically if the edit produces invalid JSON.
