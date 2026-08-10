# Vision Agent installer - Windows
# by Lightning Solutions
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install.ps1
#
# Copies the vision-bridge plugin and the vision sub-agent into the
# OpenCode config directory, then prints the configuration steps and
# runs a self-check.

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = if ($env:OPENCODE_CONFIG_DIR) { $env:OPENCODE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".config\opencode" }
$PluginsDir = Join-Path $ConfigDir "plugins"
$AgentsDir = Join-Path $ConfigDir "agent"

Write-Host "Vision Agent - by Lightning Solutions"
Write-Host "-------------------------------------"

# 1. Locate the OpenCode config directory
if (-not (Test-Path $ConfigDir)) {
    Write-Host "[WARN] OpenCode config directory not found at $ConfigDir"
    $opencode = Get-Command opencode -ErrorAction SilentlyContinue
    if ($opencode) {
        Write-Host "[ OK ] opencode CLI found - creating config directory"
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    } else {
        Write-Host "[FAIL] opencode CLI not found. Install OpenCode first." -ForegroundColor Red
        exit 1
    }
}

# 2. Create the plugin and agent directories
New-Item -ItemType Directory -Path $PluginsDir -Force | Out-Null
New-Item -ItemType Directory -Path $AgentsDir -Force | Out-Null

# 3. Copy the plugin
$pluginSrc = Join-Path $ScriptDir "plugin\vision-bridge.ts"
if (Test-Path $pluginSrc) {
    Copy-Item $pluginSrc (Join-Path $PluginsDir "vision-bridge.ts") -Force
    Write-Host "[ OK ] plugin installed -> $PluginsDir\vision-bridge.ts" -ForegroundColor Green
} else {
    Write-Host "[FAIL] plugin\vision-bridge.ts not found next to this script" -ForegroundColor Red
    exit 1
}

# 4. Copy the sub-agent
$agentSrc = Join-Path $ScriptDir "agent\vision.md"
if (Test-Path $agentSrc) {
    Copy-Item $agentSrc (Join-Path $AgentsDir "vision.md") -Force
    Write-Host "[ OK ] sub-agent installed -> $AgentsDir\vision.md" -ForegroundColor Green
} else {
    Write-Host "[FAIL] agent\vision.md not found next to this script" -ForegroundColor Red
    exit 1
}

# 5. Configuration instructions
Write-Host ""
Write-Host "Configuration (add to $ConfigDir\opencode.json):"
Write-Host " 1. Inside your orchestrator agent's permission.task, add:"
Write-Host "       `"vision`": `"allow`""
Write-Host " 2. Add the Image Vision Handoff rule to your orchestrator agent's prompt."
Write-Host "    Full reference: config\opencode.json.md in this repository."
Write-Host ""

# 6. Self-check
Write-Host "Self-check:"
if (Test-Path (Join-Path $PluginsDir "vision-bridge.ts")) {
    Write-Host "[ OK ] plugin present" -ForegroundColor Green
} else {
    Write-Host "[FAIL] plugin missing" -ForegroundColor Red
}
if (Test-Path (Join-Path $AgentsDir "vision.md")) {
    Write-Host "[ OK ] sub-agent present" -ForegroundColor Green
} else {
    Write-Host "[FAIL] sub-agent missing" -ForegroundColor Red
}

Write-Host ""
Write-Host "[ OK ] Installation complete. Restart OpenCode, then run /vision-config inside the chat." -ForegroundColor Green
