# create-deploy-bundle.ps1
# 폐쇄망 배포용 ds-closed-nw-deploy 번들 생성 + ZIP 압축 스크립트
#
# 사용법: powershell -ExecutionPolicy Bypass -File create-deploy-bundle.ps1

$ErrorActionPreference = "Stop"

# ── 인코딩 설정 (한글 깨짐 방지) ────────────────────────────────
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding             = [System.Text.Encoding]::UTF8

# ── 경로 설정 ────────────────────────────────────────────────────
$SCRIPT_DIR    = $PSScriptRoot
$DEPLOY_DIR    = Join-Path $SCRIPT_DIR "ds-closed-nw-deploy"
$ZIP_PATH      = Join-Path $SCRIPT_DIR "ds-closed-nw-deploy.zip"
$FILES_TO_COPY = @("package.json", "postinstall.mjs", "bin", "dist", "node_modules")

# ── 헤더 ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  =================================================" -ForegroundColor Magenta
Write-Host "   DS-OhMyCloseAgent - 폐쇄망 배포 번들 생성      " -ForegroundColor Magenta
Write-Host "  =================================================" -ForegroundColor Magenta
Write-Host ""

# ── [1/5] 빌드 ───────────────────────────────────────────────────
Write-Host "[1/5] 소스 코드 빌드 중 (bun run build)..." -ForegroundColor Yellow
Push-Location $SCRIPT_DIR
& bun run build
$buildExit = $LASTEXITCODE
Pop-Location
if ($buildExit -ne 0) {
    Write-Host "  XX 빌드 실패 (exit $buildExit)" -ForegroundColor Red
    exit $buildExit
}
Write-Host "  OK 빌드 완료" -ForegroundColor Green

# ── [2/5] 배포 폴더 초기화 ──────────────────────────────────────
Write-Host "[2/5] 배포 폴더 초기화 중..." -ForegroundColor Yellow
if (Test-Path $DEPLOY_DIR) {
    Remove-Item -Path $DEPLOY_DIR -Recurse -Force
    Write-Host "  OK 기존 ds-closed-nw-deploy 폴더 삭제" -ForegroundColor Green
}
New-Item -ItemType Directory -Path $DEPLOY_DIR | Out-Null
Write-Host "  OK ds-closed-nw-deploy 폴더 생성" -ForegroundColor Green

# ── [3/5] 파일 복사 ──────────────────────────────────────────────
Write-Host "[3/5] 파일 복사 중..." -ForegroundColor Yellow
$copied  = 0
$skipped = 0
foreach ($item in $FILES_TO_COPY) {
    $src = Join-Path $SCRIPT_DIR $item
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination (Join-Path $DEPLOY_DIR $item) -Recurse -Force
        Write-Host "  -> $item" -ForegroundColor Cyan
        $copied++
    } else {
        Write-Host "  !! $item 없음 - 건너뜀" -ForegroundColor Yellow
        $skipped++
    }
}
Write-Host "  OK 복사 완료 ($copied 건 / 건너뜀 $skipped 건)" -ForegroundColor Green

# ── [4/5] deploy/plugin/dist 갱신 ───────────────────────────────
Write-Host "[4/5] deploy/plugin/dist/index.js 갱신 중..." -ForegroundColor Yellow
$deployDist = Join-Path $SCRIPT_DIR "deploy\plugin\dist"
$builtIndex = Join-Path $SCRIPT_DIR "dist\index.js"
if (Test-Path $builtIndex) {
    New-Item -ItemType Directory -Path $deployDist -Force | Out-Null
    Copy-Item $builtIndex -Destination (Join-Path $deployDist "index.js") -Force
    Write-Host "  OK deploy/plugin/dist/index.js 갱신 완료" -ForegroundColor Green
} else {
    Write-Host "  !! dist/index.js 없음 - deploy/plugin 갱신 건너뜀" -ForegroundColor Yellow
}

# ── [5/5] ZIP 압축 ───────────────────────────────────────────────
Write-Host "[5/5] ZIP 압축 중..." -ForegroundColor Yellow
if (Test-Path $ZIP_PATH) {
    Remove-Item $ZIP_PATH -Force
}
Compress-Archive -Path $DEPLOY_DIR -DestinationPath $ZIP_PATH -CompressionLevel Optimal
$zipSizeMB = [math]::Round((Get-Item $ZIP_PATH).Length / 1MB, 1)
Write-Host "  OK ZIP 생성 완료: ds-closed-nw-deploy.zip ($zipSizeMB MB)" -ForegroundColor Green

# ── 완료 ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  =================================================" -ForegroundColor Green
Write-Host "   번들 생성 완료!" -ForegroundColor Green
Write-Host "  =================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  배포 폴더 : $DEPLOY_DIR" -ForegroundColor Cyan
Write-Host "  ZIP 파일  : $ZIP_PATH ($zipSizeMB MB)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [폐쇄망 설치 방법]" -ForegroundColor White
Write-Host "    ZIP을 대상 PC로 복사 후:" -ForegroundColor Gray
Write-Host "    cp -r ds-closed-nw-deploy ~/.opencode/plugins/oh-my-openagent" -ForegroundColor Gray
Write-Host "  또는 deploy/install.ps1 사용 (완전 오프라인)" -ForegroundColor Gray
Write-Host ""