# ============================================================
#  Ultradus (oh-my-openagent) - Full Offline Installer
#  No npm / No Node.js / No internet required
#
#  Usage: powershell -ExecutionPolicy Bypass -File install.ps1
#
#  Files required in same folder as this script:
#    opencode.exe          - OpenCode main binary (174 MB)
#    oh-my-opencode.exe    - oh-my-opencode CLI binary (129 MB)  [optional]
#    plugin\dist\index.js  - Plugin bundle
#    plugin\package.json   - Plugin metadata
# ============================================================
param(
    [switch]$SkipOpenCode,     # Skip copying opencode.exe to bin
    [switch]$SkipOmoCli,       # Skip copying oh-my-opencode.exe to bin
    [switch]$Force             # Force overwrite
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$PLUGIN_NAME   = "oh-my-openagent"
$BIN_DIR       = "$env:USERPROFILE\.local\bin"
$OPENCODE_CFG  = "$env:USERPROFILE\.config\opencode\opencode.json"
$PLUGIN_CACHE  = "$env:USERPROFILE\.cache\opencode\packages\$PLUGIN_NAME@latest\node_modules\$PLUGIN_NAME"

function Write-Step ($msg) { Write-Host "  -> $msg" -ForegroundColor Cyan }
function Write-OK   ($msg) { Write-Host "  OK $msg" -ForegroundColor Green }
function Write-Warn ($msg) { Write-Host "  !! $msg" -ForegroundColor Yellow }
function Write-Fail ($msg) { Write-Host "  XX $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  =================================================" -ForegroundColor Magenta
Write-Host "   Ultradus - DS Ultra Worker                      " -ForegroundColor Magenta
Write-Host "   oh-my-openagent Offline Installer (No npm)      " -ForegroundColor Magenta
Write-Host "  =================================================" -ForegroundColor Magenta
Write-Host ""

# ── [1/5] Locate required files ──────────────────────────────
Write-Host "[1/5] Locating files..." -ForegroundColor White

$scriptDir   = $PSScriptRoot
$ocExe       = Join-Path $scriptDir "opencode.exe"
$omoExe      = Join-Path $scriptDir "oh-my-opencode.exe"
$pluginDist  = Join-Path $scriptDir "plugin\dist\index.js"
$pluginPkg   = Join-Path $scriptDir "plugin\package.json"

if (-not (Test-Path $pluginDist)) { Write-Fail "plugin\dist\index.js not found in $scriptDir" }
if (-not (Test-Path $pluginPkg))  { Write-Fail "plugin\package.json not found in $scriptDir" }
Write-OK "Plugin files found"

if (Test-Path $ocExe)  { Write-OK "opencode.exe found ($([math]::Round((Get-Item $ocExe).Length/1MB,0)) MB)" }
else                   { Write-Warn "opencode.exe not found - will skip OpenCode install" ; $SkipOpenCode = $true }

if (Test-Path $omoExe) { Write-OK "oh-my-opencode.exe found ($([math]::Round((Get-Item $omoExe).Length/1MB,0)) MB)" }
else                   { Write-Warn "oh-my-opencode.exe not found - will skip CLI install" ; $SkipOmoCli = $true }

# ── [2/5] Create bin directory and add to PATH ───────────────
Write-Host "[2/5] Setting up bin directory..." -ForegroundColor White

New-Item -ItemType Directory -Path $BIN_DIR -Force | Out-Null
Write-OK "Bin dir: $BIN_DIR"

$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($null -eq $userPath) { $userPath = "" }
if ($userPath -notlike "*$BIN_DIR*") {
    [Environment]::SetEnvironmentVariable("PATH", "$BIN_DIR;$userPath", "User")
    $env:PATH = "$BIN_DIR;$env:PATH"
    Write-OK "Added $BIN_DIR to user PATH"
} else {
    Write-OK "$BIN_DIR already in PATH"
}

# ── [3/5] Copy binaries ───────────────────────────────────────
Write-Host "[3/5] Installing binaries..." -ForegroundColor White

if (-not $SkipOpenCode) {
    Write-Step "Copying opencode.exe -> $BIN_DIR\opencode.exe"
    Copy-Item $ocExe -Destination "$BIN_DIR\opencode.exe" -Force
    Write-OK "opencode.exe installed"
} else {
    Write-Warn "Skipping opencode.exe (-SkipOpenCode)"
}

if (-not $SkipOmoCli) {
    Write-Step "Copying oh-my-opencode.exe -> $BIN_DIR\oh-my-opencode.exe"
    Copy-Item $omoExe -Destination "$BIN_DIR\oh-my-opencode.exe" -Force
    Write-OK "oh-my-opencode.exe installed"
} else {
    Write-Warn "Skipping oh-my-opencode.exe (-SkipOmoCli)"
}

# ── [4/5] Deploy plugin cache ─────────────────────────────────
Write-Host "[4/5] Deploying plugin cache..." -ForegroundColor White

New-Item -ItemType Directory -Path "$PLUGIN_CACHE\dist" -Force | Out-Null

# Copy dist/index.js (fully bundled - no dependencies needed)
Copy-Item $pluginDist -Destination "$PLUGIN_CACHE\dist\index.js" -Force
Write-OK "dist/index.js deployed"

# Copy package.json - MUST be UTF-8 without BOM
# OpenCode's JSON parser rejects BOM and fails to load the plugin
$raw = [System.IO.File]::ReadAllText($pluginPkg, [System.Text.Encoding]::UTF8)
if ($raw.StartsWith([char]0xFEFF)) { $raw = $raw.Substring(1) }
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PLUGIN_CACHE\package.json", $raw, $utf8NoBom)
Write-OK "package.json deployed (no BOM)"

# ── [5/5] Register plugin in opencode.json ───────────────────
Write-Host "[5/5] Registering plugin..." -ForegroundColor White

$cfgDir = Split-Path $OPENCODE_CFG -Parent
New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null

# Read existing config or start fresh
# NOTE: Avoid ConvertFrom-Json on files with "$schema" key - PS5 misparses "$" keys.
# Use direct string/regex manipulation instead.
if (Test-Path $OPENCODE_CFG) {
    $rawCfg = [System.IO.File]::ReadAllText($OPENCODE_CFG, [System.Text.Encoding]::UTF8)
    if ($rawCfg.StartsWith([char]0xFEFF)) { $rawCfg = $rawCfg.Substring(1) }
} else {
    $rawCfg = "{`n  `"`$schema`": `"https://opencode.ai/config.json`",`n  `"plugin`": []`n}`n"
}

# Check if already registered (match both "oh-my-openagent" and "oh-my-openagent@latest")
if ($rawCfg -match ('"' + [regex]::Escape($PLUGIN_NAME) + '(@[^"]*)?"')) {
    Write-OK "$PLUGIN_NAME already registered"
} else {
    # Inject into plugin array - handles both empty [] and existing entries
    if ($rawCfg -match '"plugin"\s*:\s*\[\s*\]') {
        # Empty array
        $rawCfg = $rawCfg -replace '"plugin"\s*:\s*\[\s*\]', ('"plugin": [ "' + $PLUGIN_NAME + '" ]')
    } elseif ($rawCfg -match '"plugin"\s*:\s*\[') {
        # Non-empty array - prepend
        $rawCfg = $rawCfg -replace '("plugin"\s*:\s*\[)', ('$1' + "`n    `"$PLUGIN_NAME`",")
    } else {
        # No plugin key at all - add before closing brace
        $rawCfg = $rawCfg -replace '\}\s*$', (",`n  `"plugin`": [ `"$PLUGIN_NAME`" ]`n}")
    }
    Write-OK "Registered: $PLUGIN_NAME"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OPENCODE_CFG, $rawCfg, $utf8NoBom)

# ── Done ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "  =================================================" -ForegroundColor Green
Write-Host "   Installation complete!" -ForegroundColor Green
Write-Host "  =================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  IMPORTANT: Open a new PowerShell window" -ForegroundColor Yellow
Write-Host "             so PATH changes take effect" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. Open new PowerShell" -ForegroundColor Gray
Write-Host "    2. opencode auth login   -- Connect your AI provider" -ForegroundColor Gray
Write-Host "    3. opencode               -- Start, select Ultradus agent" -ForegroundColor Gray
Write-Host ""

# Display registered plugins via regex (avoid ConvertFrom-Json on $schema key - PS5 bug)
$pluginMatches = [regex]::Matches($rawCfg, '"([^"]+)"')
$pluginSection = $false
$registeredList = @()
foreach ($m in $pluginMatches) {
    if ($m.Value -eq '"plugin"') { $pluginSection = $true; continue }
    if ($pluginSection -and $m.Value -match '^\".+\"$') {
        $val = $m.Groups[1].Value
        if ($val -notmatch '^\$') { $registeredList += $val }
    }
}
Write-Host "  Registered plugins : $($registeredList -join ', ')" -ForegroundColor DarkGray
Write-Host "  opencode location  : $BIN_DIR\opencode.exe" -ForegroundColor DarkGray
Write-Host ""
