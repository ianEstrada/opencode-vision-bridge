# ============================================================
#  Vision Agent - one-line installer (Windows / PowerShell)
#  by Lightning Solutions
#
#  Usage (copy-paste into a terminal):
#    powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/ianEstrada/opencode-vision-bridge/master/install.ps1 | iex"
#
#  What it does:
#    1. Downloads the plugin, sub-agent and command from the repo
#    2. Installs them into the OpenCode config directory
#    3. Automatically edits opencode.json (backup first):
#       - adds "vision": "allow" to the orchestrator's permission.task
#       - appends the Image Vision Handoff rule to the orchestrator prompt
#    4. Runs a self-check
# ============================================================

$ErrorActionPreference = "Stop"

$RepoBase = "https://raw.githubusercontent.com/ianEstrada/opencode-vision-bridge/master"

$ConfigDir = if ($env:OPENCODE_CONFIG_DIR) { $env:OPENCODE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".config\opencode" }
$PluginsDir = Join-Path $ConfigDir "plugins"
$AgentsDir = Join-Path $ConfigDir "agent"
$CommandsDir = Join-Path $ConfigDir "command"
$ConfigPath = Join-Path $ConfigDir "opencode.json"

Write-Host ""
Write-Host "======================================"
Write-Host "  Vision Agent - by Lightning Solutions"
Write-Host "======================================"
Write-Host ""

# ---------- helpers ----------
function Write-Status($ok, $msg) {
    $color = if ($ok) { "Green" } else { "Red" }
    $tag = if ($ok) { "[ OK ]" } else { "[FAIL]" }
    Write-Host "$tag $msg" -ForegroundColor $color
}

function Install-RepoFile($remote, $dest, $label) {
    if (Test-Path $dest) {
        Write-Status $true "$label already installed: $dest"
        return
    }
    $url = "$RepoBase/$remote"
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        Write-Status $true "$label installed -> $dest"
    } catch {
        Write-Status $false "$label download failed: $url"
        throw
    }
}

# ---------- 1. install files ----------
New-Item -ItemType Directory -Path $PluginsDir, $AgentsDir, $CommandsDir -Force | Out-Null

Install-RepoFile "plugin/vision-bridge.ts"    (Join-Path $PluginsDir  "vision-bridge.ts")    "Plugin"
Install-RepoFile "agent/vision.md"            (Join-Path $AgentsDir   "vision.md")            "Sub-agent"
Install-RepoFile "command/vision-config.md"   (Join-Path $CommandsDir "vision-config.md")     "Command"

# ---------- 2. edit opencode.json ----------
$visionRule = @"
### Image Vision Handoff (MANDATORY)

When the user attaches or pastes an image in a message (image file part, screenshot, or image in chat) and you cannot see its content:
1. If the message contains the placeholder `[Image attached - Vision Agent by Lightning Solutions (see analysis). Image path: <path>]`, ALWAYS delegate to the `vision` sub-agent (multimodal MiMo-V2.5): pass the `Image path: <path>` value from the placeholder as the file path in the delegation prompt, ask for a detailed description in the user's language, and use its report as your understanding of the image. This is the PRIMARY path - do not skip it.
2. If a FULL text description was injected instead (part starting with `[Image attached - described by vision model]:` followed by a real description), use that description directly and do NOT delegate.
3. Never claim to have seen an image you have not seen.
"@

$jsonEdited = $false

if (Test-Path $ConfigPath) {
    # backup first
    $backup = "$ConfigPath.vision-backup"
    if (-not (Test-Path $backup)) {
        Copy-Item $ConfigPath $backup -Force
        Write-Host "Backup created: $backup"
    }

    $json = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Edit EVERY agent that has a permission.task block (option C):
    # any agent that can delegate (plan, build, gentle-orchestrator, ...)
    # gets the vision permission and the Handoff rule, so pasting an
    # image works regardless of which agent the user talks to.
    $editedAgents = @()

    foreach ($prop in $json.agent.PSObject.Properties) {
        $agent = $prop.Value
        $name = $prop.Name

        if (-not $agent.permission -or -not $agent.permission.task) {
            Write-Host "[INFO] Skipping '$name' (no permission.task)"
            continue
        }

        # 2a. permission.task -> vision: allow
        if (-not $agent.permission.task.vision) {
            $agent.permission.task | Add-Member -NotePropertyName "vision" -NotePropertyValue "allow"
            $jsonEdited = $true
            Write-Status $true "Permission added: $name.permission.task.vision = allow"
        } else {
            Write-Host "[INFO] Permission vision already present in '$name'"
        }

        # 2b. append the vision rule to the prompt
        if ($agent.prompt) {
            if ($agent.prompt -notmatch "Image Vision Handoff") {
                $agent.prompt = $agent.prompt.TrimEnd() + "`n`n" + $visionRule.Trim()
                $jsonEdited = $true
                Write-Status $true "Vision Handoff rule appended to '$name' prompt"
            } else {
                Write-Host "[INFO] Vision Handoff rule already present in '$name'"
            }
        }

        $editedAgents += $name
    }

    if ($editedAgents.Count -eq 0) {
        Write-Host "[WARN] No agent with permission.task found - add config manually (see config/opencode.json.md)"
    }

    if ($jsonEdited) {
        $json | ConvertTo-Json -Depth 100 | Set-Content $ConfigPath -Encoding UTF8
        Write-Status $true "opencode.json updated"
    } else {
        Write-Host "[INFO] opencode.json already configured"
    }

    # validate the result
    try {
        Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
        Write-Status $true "opencode.json is valid JSON"
    } catch {
        Write-Status $false "opencode.json is INVALID after edit - restoring backup"
        Copy-Item $backup $ConfigPath -Force
        throw
    }
} else {
    Write-Host "[WARN] opencode.json not found at $ConfigPath"
    Write-Host "       Create it with the content from config/opencode.json.md in the repo."
}

# ---------- 3. self-check ----------
Write-Host ""
Write-Host "Self-check:"
Write-Status (Test-Path (Join-Path $PluginsDir "vision-bridge.ts"))   "Plugin present"
Write-Status (Test-Path (Join-Path $AgentsDir "vision.md"))           "Sub-agent present"
Write-Status (Test-Path (Join-Path $CommandsDir "vision-config.md"))  "Command present"

Write-Host ""
Write-Host "======================================"
Write-Host "  INSTALLATION COMPLETE"
Write-Host "======================================"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart OpenCode (config does not hot-reload)"
Write-Host "  2. In the chat, run:  /vision-config"
Write-Host "  3. Paste an image and enjoy the analysis"
Write-Host ""
