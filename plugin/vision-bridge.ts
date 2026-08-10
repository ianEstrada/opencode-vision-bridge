/**
 * vision-bridge
 * Image gateway for non-multimodal models.
 *
 * PROBLEM: when the active model cannot see images (e.g. deepseek-flash),
 * pasting an image into the chat makes the TUI/client fail with
 * "Cannot read clipboard (this model does not support image input)".
 *
 * ROLE: this plugin is a GATEKEEPER, not a vision model.
 *   1. Detects image FileParts in user messages (hook: chat.message)
 *   2. Persists clipboard pastes (data URIs) to a temp file so a real
 *      filesystem path always exists
 *   3. Replaces the image with a short placeholder that carries that path
 *
 * The orchestrator's "Image Vision Handoff" rule then ALWAYS delegates to
 * the `vision` sub-agent (multimodal MiMo-V2.5) with that path — the most
 * failure-resistant design: native sub-agent machinery, no experimental
 * hooks, no external API calls from the plugin.
 *
 * Design principles:
 *   - NEVER downscale images: resizing degrades fine text and makes vision
 *     models hallucinate details. Full quality always wins.
 *   - NEVER call vision APIs from the plugin (they rate-limit, hang, and
 *     fail silently). Delegation is the resilient path.
 *   - Models known to support vision are left untouched via the
 *     MODELS_WITH_VISION allow-list.
 */

import type { Plugin } from "@opencode-ai/plugin"
import { existsSync, mkdirSync, writeFileSync } from "fs"
import { homedir, tmpdir } from "os"
import path from "path"

// Models that natively see images — leave their messages untouched.
const MODELS_WITH_VISION: Record<string, boolean> = {
  "groq/qwen/qwen3.6-27b": true,
  "opencode-go/mimo-v2.5": true,
  "opencode-go/mimo-v2.5-pro": true,
  "opencode/mimo-v2.5-free": true,
  "anthropic/*": true,
  "openai/gpt-4o*": true,
  "google/gemini-*": true,
  "openrouter/*": true,
}

function modelHasVision(providerID?: string, modelID?: string): boolean {
  if (!providerID || !modelID) return false
  if (MODELS_WITH_VISION[`${providerID}/${modelID}`]) return true
  if (MODELS_WITH_VISION[`${providerID}/*`]) return true
  for (const [key] of Object.entries(MODELS_WITH_VISION)) {
    const [p, m] = key.split("/", 2)
    if (p === providerID && m?.endsWith("*")) {
      const prefix = m.slice(0, -1)
      if (modelID.startsWith(prefix)) return true
    }
  }
  return false
}

function fileUrlToPath(url: string): string | undefined {
  if (!url) return undefined
  try {
    if (url.startsWith("file://")) {
      let p = decodeURIComponent(new URL(url).pathname)
      if (process.platform === "win32" && p.startsWith("/")) p = p.slice(1)
      return p
    }
    return url
  } catch {
    return url
  }
}

// Returns { path } or { dataBase64 } for data: URIs
function resolveImageSource(url: string): { path?: string; dataBase64?: string } | null {
  if (!url) return null
  if (url.startsWith("data:")) {
    const match = url.match(/^data:([^;,]+)?(;base64)?,(.+)$/)
    if (match) return { dataBase64: match[3] }
    return null
  }
  const p = fileUrlToPath(url)
  if (p && existsSync(p)) return { path: p }
  return null
}

// Persists a data: URI image to a temp file and returns its path. This
// guarantees the placeholder always carries a REAL file path the vision
// sub-agent can read (clipboard pastes arrive as data URIs, not files).
function persistImageForVision(source: { path?: string; dataBase64?: string }): string {
  if (source.path) return source.path
  if (!source.dataBase64) return ""
  try {
    const dir = path.join(tmpdir(), "opencode")
    mkdirSync(dir, { recursive: true })
    const filePath = path.join(dir, `vision_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.png`)
    writeFileSync(filePath, Buffer.from(source.dataBase64, "base64"))
    return filePath
  } catch (err) {
    console.error(`[vision-bridge] persist failed: ${err instanceof Error ? err.message : String(err)}`)
    return ""
  }
}

export const VisionBridgePlugin: Plugin = async () => {
  return {
    "chat.message": async (input, output) => {
      // Only process user messages
      if (output.message.role !== "user") return

      const parts = output.parts
      const imageIndexes = parts
        .map((p, i) => (p.type === "file" && (p as any).mime?.startsWith("image/") ? i : -1))
        .filter((i) => i >= 0)
      if (imageIndexes.length === 0) return

      // Skip only for KNOWN vision-capable models (allow-list, not provider metadata)
      if (modelHasVision(input.model?.providerID, input.model?.modelID)) return

      // Replace each image part with a placeholder carrying the image path.
      // The orchestrator's Image Vision Handoff rule delegates to the
      // `vision` sub-agent using this path.
      for (const idx of imageIndexes) {
        const original = parts[idx] as any
        const source = resolveImageSource(original.url ?? "")
        const imgPath = persistImageForVision(source ?? {}) || original.filename || "unknown"
        parts[idx] = {
          id: original.id,
          sessionID: original.sessionID,
          messageID: original.messageID,
          type: "text",
          text: `[🖼️ Image attached — Vision Agent by Lightning Solutions (see analysis). Image path: ${imgPath}]`,
        } as any
      }
      output.parts = parts
    },
  }
}

export default VisionBridgePlugin
