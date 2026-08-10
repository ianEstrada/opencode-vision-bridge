# ⚡ Vision Agent — by Lightning Solutions

**Dale ojos a tu modelo de OpenCode que no puede ver imágenes.**

¿Usás OpenCode con un modelo sin visión (como deepseek-flash)? Si pegás una imagen en el chat, te aparece:

```
ERROR: Cannot read "clipboard" (this model does not support image input)
```

Este proyecto resuelve eso con una **arquitectura en 2 piezas** que es simple, rápida y resistente a fallos:

| Pieza | Rol | Qué hace |
|---|---|---|
| **Plugin `vision-bridge`** | 🚪 **Portero** | Detecta la imagen pegada, la guarda a disco y la reemplaza por un placeholder con la ruta. Tarda **~1ms**. No llama APIs, no redimensiona, no falla. |
| **Sub-agente `vision`** | 🧠 **Cerebro** | El orquestador SIEMPRE le delega la descripción. Usa un modelo multimodal (MiMo-V2.5 o Groq qwen) que lee la imagen desde la ruta del placeholder y la describe con todo el detalle. |

```
Pegás la imagen → plugin la guarda a disco (1ms)
  → placeholder con ruta: [🖼️ Image attached — Vision Agent by Lightning Solutions (see analysis). Image path: ...]
  → el orquestador delega al sub-agente vision
  → sub-agente la lee y la describe → respondés con el análisis
```

---

## 📁 Instalación (3 archivos)

### 1. Copiá los archivos

| Archivo | Dónde va |
|---|---|
| `plugin/vision-bridge.ts` | `~/.config/opencode/plugins/` (o `.opencode/plugins/` del proyecto) |
| `agent/vision.md` | `~/.config/opencode/agent/` (o `.opencode/agent/` del proyecto) |

### 2. Agregá los cambios de configuración

Seguí `config/opencode.json.md` — son 2 cambios en tu `opencode.json`:

**a)** Permití que el orquestador delegue al sub-agente `vision`:

```json
"permission": {
  "task": {
    "vision": "allow"
  }
}
```

**b)** Agregá la regla **Image Vision Handoff** al prompt de tu agente orquestador (el texto completo está en `config/opencode.json.md`).

### 3. Elegí el modelo de visión del sub-agente

En `agent/vision.md`, la línea `model:` define qué modelo ve las imágenes:

| Opción | Modelo | Costo |
|---|---|---|
| **MiMo-V2.5** (recomendado) | `opencode-go/mimo-v2.5` | Incluido en el paquete opencode-go — **30.100 req/5h** |
| Groq | `groq/qwen/qwen3.6-27b` | Tier free: ~8K tokens/min |

> MiMo es la opción recomendada: está en el paquete opencode-go, es gratis y sin rate limits agresivos.

### 4. Reiniciá OpenCode

La configuración **no se recarga en caliente** — cerrá y volvé a abrir OpenCode.

---

## 🧪 Cómo probar

1. Pegá una imagen en el chat (Ctrl+V o arrastrá un archivo)
2. Tu mensaje mostrará el placeholder con la ruta (sin error de clipboard)
3. El orquestador delega al sub-agente vision automáticamente
4. Recibís la descripción/análisis completo de la imagen

**Pro tip**: no solo describe — podés pedirle que **evalúe** (ej. *"evaluá este diseño de UI"* o *"¿qué dice este error?"*) y te responde con análisis profundo.

---

## 🧠 Por qué esta arquitectura (y no otra)

Probamos durante una sesión completa la alternativa "el plugin describe automáticamente con una API". Fue un cementerio de fallos:

| Intento | Falla |
|---|---|
| Llamar a Groq desde el plugin | Rate limit del tier free |
| Llamar a MiMo vía SDK desde el plugin | `session.create` no conecta en producción |
| Hook `experimental.chat.messages.transform` | Nunca inyectó la descripción en producción |
| Redimensionar la imagen antes de enviarla | El texto fino se degrada y el modelo **alucina** detalles (inventa typos que no existen) |

**La lección**: la arquitectura más resistente es la que tiene MENOS eslabones y usa mecanismos NATIVOS de OpenCode (sub-agentes), no hooks experimentales ni APIs externas desde el plugin.

Reglas de diseño finales:
- **NUNCA redimensionar** — la calidad total gana; el resize hace alucinar al modelo
- **NUNCA llamar APIs de visión desde el plugin** — rate limits y fallos silenciosos
- **Siempre delegar** al sub-agente vision — mecanismo nativo, probado y robusto

---

## 🗺️ Estructura

```
opencode-vision-bridge/
├── plugin/
│   └── vision-bridge.ts      ← el portero (3.3 KB, ~1ms)
├── agent/
│   └── vision.md             ← el cerebro (sub-agente multimodal)
└── config/
    └── opencode.json.md      ← cambios de config + regla del orquestador
```

---

## 🛠️ Troubleshooting

| Síntoma | Causa | Solución |
|---|---|---|
| `Cannot read "clipboard"` al pegar | Plugin no cargado (OpenCode viejo) | Reiniciá OpenCode |
| Placeholder dice `Image path: unknown` | La imagen no se pudo persistir | Revisá permisos de escritura en el temp |
| El sub-agente vision no aparece | `agent/vision.md` mal ubicado o sin reiniciar | Verificá la ruta y reiniciá |
| El orquestador no delega | Falta la regla Image Vision Handoff | Agregá la sección al prompt (config/) |
| Groq da 429 | Rate limit del tier free | Cambiá el modelo del sub-agente a MiMo |
| La descripción inventa texto | Imagen redimensionada | Asegurate de usar el plugin sin resize (este repo) |

---

## ⚖️ Licencia

MIT — libre para usar, modificar y compartir.

---

**Vision Agent by Lightning Solutions** ⚡
