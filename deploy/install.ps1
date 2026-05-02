# ============================================================
#  oh-my-openagent (Ultradus) Offline Installer
#  Usage: powershell -ExecutionPolicy Bypass -File install.ps1
# ============================================================
param(
    [switch]$SkipCli,      # Skip CLI binary install
    [switch]$SkipPlugin,   # Skip OpenCode plugin cache install
    [switch]$Force         # Force overwrite existing cache
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$PLUGIN_NAME     = "oh-my-openagent"
$PACKAGE_NAME    = "oh-my-opencode"
$OPENCODE_CONFIG = "$env:USERPROFILE\.config\opencode\opencode.json"
$OPENCODE_CACHE  = "$env:USERPROFILE\.cache\opencode\packages\$PLUGIN_NAME@latest\node_modules\$PLUGIN_NAME"

function Write-Step ($msg) { Write-Host "  -> $msg" -ForegroundColor Cyan }
function Write-OK   ($msg) { Write-Host "  OK $msg" -ForegroundColor Green }
function Write-Warn ($msg) { Write-Host "  !! $msg" -ForegroundColor Yellow }
function Write-Fail ($msg) { Write-Host "  XX $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  =================================================" -ForegroundColor Magenta
Write-Host "   Ultradus - DS Ultra Worker                      " -ForegroundColor Magenta
Write-Host "   oh-my-openagent Offline Installer               " -ForegroundColor Magenta
Write-Host "  =================================================" -ForegroundColor Magenta
Write-Host ""

# ── [1/5] Find package files ─────────────────────────────────
Write-Host "[1/5] Locating package files..." -ForegroundColor White

$tgz = Get-ChildItem -Path $PSScriptRoot -Filter "$PACKAGE_NAME-*.tgz" `
    | Where-Object { $_.Name -notmatch "windows|darwin|linux|arm|musl" } `
    | Sort-Object LastWriteTime -Descending `
    | Select-Object -First 1

if (-not $tgz) { Write-Fail "No $PACKAGE_NAME-*.tgz found. Place the tgz in the same folder as this script." }
Write-OK "Main package : $($tgz.Name)"

$binaryTgz = Get-ChildItem -Path $PSScriptRoot -Filter "$PACKAGE_NAME-windows-x64-*.tgz" `
    | Sort-Object LastWriteTime -Descending `
    | Select-Object -First 1

if ($binaryTgz) { Write-OK "CLI binary   : $($binaryTgz.Name)" }
else            { Write-Warn "No CLI binary package found -- doctor/install commands won't work (plugin still works)" }

# ── [2/5] Prerequisites ──────────────────────────────────────
Write-Host "[2/5] Checking prerequisites..." -ForegroundColor White

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Fail "npm not found. Please install Node.js first."
}
Write-OK "npm $(npm --version)"

$ocRaw = opencode --version 2>$null
if ($ocRaw) { Write-OK "OpenCode $ocRaw" }
else        { Write-Warn "OpenCode not installed -- install it first before using the plugin" }

# ── [3/5] npm global install ─────────────────────────────────
Write-Host "[3/5] Installing npm packages globally..." -ForegroundColor White

if (-not $SkipCli) {
    if ($binaryTgz) {
        Write-Step "Installing CLI binary package..."
        $ErrorActionPreference = "Continue"
        npm install -g $binaryTgz.FullName --force --silent 2>$null
        $ErrorActionPreference = "Stop"
        Write-OK "CLI binary installed"
    }

    Write-Step "Installing main package..."
    $ErrorActionPreference = "Continue"
    npm install -g $tgz.FullName --force --silent 2>$null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($exitCode -ne 0) { Write-Warn "npm install exited with code $exitCode (may already be up to date)" }
    else { Write-OK "npm global install complete" }
} else {
    Write-Warn "Skipping CLI install (-SkipCli)"
}

# ── [4/5] Populate OpenCode plugin cache ─────────────────────
Write-Host "[4/5] Deploying OpenCode plugin cache..." -ForegroundColor White

if (-not $SkipPlugin) {
    if (-not (Test-Path $OPENCODE_CACHE)) {
        New-Item -ItemType Directory -Path $OPENCODE_CACHE -Force | Out-Null
        Write-Step "Created cache dir: $OPENCODE_CACHE"
    } else {
        Write-Step "Updating existing cache"
    }

    $tempDir = Join-Path $env:TEMP "omo_install_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        tar xzf $tgz.FullName -C $tempDir 2>&1 | Out-Null
        $extracted = Join-Path $tempDir "package"
        if (-not (Test-Path $extracted)) { Write-Fail "tgz extraction failed -- no 'package' folder found" }

        # Copy dist/index.js (the plugin bundle)
        $distDest = Join-Path $OPENCODE_CACHE "dist"
        New-Item -ItemType Directory -Path $distDest -Force | Out-Null
        Copy-Item "$extracted\dist\index.js" -Destination "$distDest\index.js" -Force
        Write-OK "dist/index.js deployed"

        # Copy package.json and bin/
        Copy-Item "$extracted\package.json" -Destination $OPENCODE_CACHE -Force
        if (Test-Path "$extracted\bin") {
            Copy-Item "$extracted\bin" -Destination $OPENCODE_CACHE -Recurse -Force
        }
        Write-OK "package.json + bin/ deployed"

        # Fix package name field to match OpenCode cache key
        # IMPORTANT: Write WITHOUT BOM - OpenCode's JSON parser rejects UTF-8 BOM
        $pkgJsonPath = Join-Path $OPENCODE_CACHE "package.json"
        $raw = [System.IO.File]::ReadAllText($pkgJsonPath, [System.Text.Encoding]::UTF8)
        if ($raw.StartsWith([char]0xFEFF)) { $raw = $raw.Substring(1) }
        $pkgJson = $raw | ConvertFrom-Json
        $pkgJson.name = $PLUGIN_NAME
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($pkgJsonPath, ($pkgJson | ConvertTo-Json -Depth 10), $utf8NoBom)
        Write-OK "package.json name -> $PLUGIN_NAME"

    } finally {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Warn "Skipping plugin cache deploy (-SkipPlugin)"
}

# ── [5/5] Register plugin in opencode.json ───────────────────
Write-Host "[5/5] Registering plugin in opencode.json..." -ForegroundColor White

$configDir = Split-Path $OPENCODE_CONFIG -Parent
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

if (Test-Path $OPENCODE_CONFIG) {
    $config = Get-Content $OPENCODE_CONFIG -Raw | ConvertFrom-Json
} else {
    $config = [PSCustomObject]@{ plugin = @() }
}

if (-not $config.PSObject.Properties["plugin"]) {
    $config | Add-Member -MemberType NoteProperty -Name "plugin" -Value @()
}

$plugins    = @($config.plugin)
$hasNew     = $plugins | Where-Object { $_ -eq $PLUGIN_NAME }
$hasLegacy  = $plugins | Where-Object { $_ -eq $PACKAGE_NAME }

if ($hasNew) {
    Write-OK "$PLUGIN_NAME already registered"
} elseif ($hasLegacy) {
    $config.plugin = $plugins | ForEach-Object { if ($_ -eq $PACKAGE_NAME) { $PLUGIN_NAME } else { $_ } }
    Write-OK "Updated plugin entry: $PACKAGE_NAME -> $PLUGIN_NAME"
} else {
    $config.plugin = @($PLUGIN_NAME) + $plugins
    Write-OK "Registered: $PLUGIN_NAME"
}

$config | ConvertTo-Json -Depth 10 | Set-Content $OPENCODE_CONFIG -Encoding UTF8

# ── Done ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "  =================================================" -ForegroundColor Green
Write-Host "   Installation complete!" -ForegroundColor Green
Write-Host "  =================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. opencode auth login   -- Authenticate your AI provider" -ForegroundColor Gray
Write-Host "    2. opencode               -- Start OpenCode, select Ultradus agent" -ForegroundColor Gray
Write-Host ""

$registeredPlugins = (Get-Content $OPENCODE_CONFIG | ConvertFrom-Json).plugin -join ", "
Write-Host "  Registered plugins: $registeredPlugins" -ForegroundColor DarkGray
Write-Host ""
