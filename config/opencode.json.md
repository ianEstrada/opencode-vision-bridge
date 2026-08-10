# opencode.json — cambios necesarios

Agregá estas piezas a tu `~/.config/opencode/opencode.json` (o `opencode.json` del proyecto).

## 1. Permiso de task — permitir que el orquestador delegue al sub-agente vision

Dentro del agente que hace de orquestador (ej: `gentle-orchestrator`), en `permission.task`:

```json
"permission": {
  "task": {
    "vision": "allow"
  }
}
```

## 2. Regla de delegación en el prompt del orquestador

Agregá esta sección al prompt del agente orquestador (es la que activa el flujo):

```
### Image Vision Handoff (MANDATORY)

When the user attaches or pastes an image in a message (image file part, screenshot, or image in chat) and you cannot see its content:
1. If the message contains the placeholder `[🖼️ Image attached — Vision Agent by Lightning Solutions (see analysis). Image path: <path>]`, ALWAYS delegate to the `vision` sub-agent (multimodal MiMo-V2.5): pass the `Image path: <path>` value from the placeholder as the file path in the delegation prompt, ask for a detailed description in the user's language, and use its report as your understanding of the image. This is the PRIMARY path — do not skip it.
2. If a FULL text description was injected instead (part starting with `[Image attached — described by vision model]:` followed by a real description), use that description directly and do NOT delegate.
3. Never claim to have seen an image you have not seen.
```

## 3. (Opcional) Provider Groq — solo si querés que el sub-agente vision use Groq en vez de MiMo

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

> **Importante**: la config NO se recarga en caliente — hay que reiniciar OpenCode después de cambiar estos archivos.

## Arquitectura (por qué así)

- **vision-bridge.ts (plugin)** = PORTERO: detecta la imagen, la persiste a disco (los pastes del portapapeles son data URIs sin ruta) y la reemplaza por un placeholder con la ruta. No llama APIs, no redimensiona, tarda ~1ms.
- **vision.md (sub-agente)** = CEREBRO: el orquestador SIEMPRE delega la descripción a este sub-agente (modelo multimodal), que lee la imagen desde la ruta del placeholder.
- Este diseño es el más resistente a fallos: sin hooks experimentales, sin rate limits de APIs externas, sin pasos intermedios que puedan fallar silenciosamente.
