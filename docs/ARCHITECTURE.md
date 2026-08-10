# Architecture

## Motivation

In an orchestrated workflow (a harness like Gentle-AI, SDD phases, or any
setup where an orchestrator delegates to sub-agents), every agent shares the
same model. If that model cannot see images, pasting a screenshot becomes a
showstopper: you either switch models mid-workflow (breaking context and
automation) or describe images by hand before pasting (tedious and slow).

Vision Agent removes that decision. The orchestrator keeps its model; any
agent that can delegate gets image handling automatically. Automation is the
whole point of a harness — image handling should not be the exception that
requires a human.

## Why this design

Vision Agent uses a two-piece architecture: a **gatekeeper plugin** and a
**delegated vision sub-agent**. This design was not the first attempt — it is
the result of production testing that eliminated more complex alternatives.

## What was tried and failed

| Attempt | Failure |
|---|---|
| Call Groq from the plugin | Free-tier rate limits (HTTP 429) |
| Call MiMo via the SDK from the plugin | `session.create` does not connect in production |
| `experimental.chat.messages.transform` hook | Never injected the description in production |
| Resizing the image before sending | Degraded fine text; the model hallucinated details |

## The lesson

The most failure-resistant architecture has the fewest moving parts and uses
OpenCode-native mechanisms (sub-agents), not experimental hooks or external
API calls from the plugin.

## Design rules

- **NEVER resize images** — full quality wins; resizing causes the vision
  model to hallucinate text that does not exist (it invents typos and
  characters).
- **NEVER call vision APIs from the plugin** — rate limits and silent
  failures.
- **ALWAYS delegate to the vision sub-agent** — a native, proven mechanism
  that works across agents and sessions.

## Data flow

```
User pastes image
  -> vision-bridge plugin (gatekeeper, ~1ms):
       detects the image, persists clipboard pastes to a temp file,
       replaces the image with a placeholder carrying the file path
  -> orchestrator (any agent with permission.task):
       sees the placeholder and ALWAYS delegates to the vision sub-agent
  -> vision sub-agent (multimodal MiMo-V2.5):
       reads the image from the placeholder path, describes it in detail
  -> user receives the full analysis
```

## Failure resistance

| Failure point | Mitigation |
|---|---|
| TUI rejects images for non-multimodal models | The plugin replaces the image with a text placeholder before the client validates it |
| Clipboard pastes have no file path | The plugin persists data URIs to a temp file |
| Vision API down / rate limited | Delegation uses the native sub-agent machinery; no plugin-side API calls |
| Orchestrator misses the image | The placeholder carries the path; the Image Vision Handoff rule makes delegation mandatory |
