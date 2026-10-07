# EraRelay 前端布局探针（编排）—— 一条命令拿到「指定分辨率下的真实 DOM 几何 + 截图」
#
# 为什么要有它（research/43 §6）：
#   R 角、右半边两处翻车，共同原因都是「改完 CSS 只能靠猜」，因为没有真机眼睛。
#   本脚本用无头 Chrome 复刻真机分辨率（默认 1920×1200 = ALLDOCUBE 掌玩 mini 横屏），
#   直接读元素 boundingClientRect ⇒ CSS 改动在上真机之前就能有**可核对的判据**。
#   ★ 它替代不了真机（字体/IME/R角/触摸都要真机），但能把"低级几何错误"挡在前面。
#
# ★ 用法（★ 本机 PowerShell 执行策略禁止未签名 .ps1 —— 实测报「未对文件 … 进行数字签名」，
#   所以必须带 -ExecutionPolicy Bypass；这与项目里既有的 measure-win-fill.ps1 同理）：
#   pwsh -ExecutionPolicy Bypass -File tools\web-layout-probe.ps1
#   pwsh -ExecutionPolicy Bypass -File tools\web-layout-probe.ps1 -Width 1200 -Height 1920 -Prefix 竖屏
#   pwsh -ExecutionPolicy Bypass -File tools\web-layout-probe.ps1 -KeepRunning    # 不自杀，留着交互调试
#   ★ 不想碰执行策略也行：手工按下面"前置"起好三样，直接单跑 web-layout-probe.mjs（那条已实测通过）。
#
# ⚠ 状态（2026-10-08）：**web-layout-probe.mjs 已端到端实测通过**（1920×1200，几何与截图均正确）；
#   **本编排脚本尚未自测** —— 自测时被执行策略拦住，我**没有擅自去改系统执行策略**。用前请先跑一次。
#
# 输出：截图 + JSON 几何 → 默认 <当前目录>\layout-shots\（可用 -Out 覆盖）
#   ★ 默认值**不写死本机路径** —— 写死含用户名的绝对路径是外发红线之一。
param(
    [int]$Width = 1920,
    [int]$Height = 1200,
    [string]$Out = (Join-Path (Get-Location) 'layout-shots'),
    [string]$Prefix = 'probe',
    [int]$Port = 8080,
    [int]$VitePort = 5173,
    [int]$CdpPort = 9333,
    [string]$GameDir = '',
    [switch]$KeepRunning
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ROOT = Split-Path -Parent $PSScriptRoot                       # = eratw 仓库根
$ENGINE = if ($env:ERACORE_ENGINE) { $env:ERACORE_ENGINE } else { Join-Path (Split-Path -Parent $ROOT) 'eracore-engine' }
if (-not $GameDir) { $GameDir = Join-Path $ROOT 'eraTW' }

function Test-Port([int]$p) { [bool](Get-NetTCPConnection -LocalPort $p -State Listen -EA SilentlyContinue) }
function Find-Exe([string[]]$cands) { $cands | Where-Object { Test-Path $_ } | Select-Object -First 1 }

# ---------- 工具链（都做候选探测，换机不用改） ----------
$dotnet = Find-Exe @((Join-Path $ROOT 'tools\dotnet\dotnet.exe'), 'dotnet')
if (-not $dotnet) { throw '找不到 dotnet' }
$node = Find-Exe @(
    (Join-Path $ROOT 'tools\node\node.exe'),
    "$env:USERPROFILE\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe",
    'node')
if (-not $node) { throw '找不到 node（vite 与探针都要它）' }
$chrome = Find-Exe @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe")
if (-not $chrome) { throw '找不到 Chrome / Edge（无头截图用）' }

$cliDll = Join-Path $ENGINE 'EraCore.Cli\bin\Debug\net10.0\EraCore.Cli.dll'
if (-not (Test-Path $cliDll)) {
    throw "找不到 $cliDll —— 先构建：dotnet build `"$ENGINE\EraCore.Cli\EraCore.Cli.csproj`" -c Debug"
}
$web = Join-Path $ENGINE 'EraCore.Web'

$spawned = @()      # 只杀本脚本自己起的进程，不动用户已有的
$chromeProf = Join-Path $env:TEMP 'era-layout-probe-chrome'

try {
    # ---------- ① 游戏服务器 ----------
    if (Test-Port $Port) {
        Write-Host "[1/4] 端口 $Port 已在监听 —— 复用，不新起" -ForegroundColor DarkGray
    } else {
        Write-Host "[1/4] 起 CLI 游戏服务器（$Port）..." -ForegroundColor Cyan
        $spawned += Start-Process -FilePath $dotnet -PassThru -WindowStyle Hidden `
            -ArgumentList @('exec', "`"$cliDll`"", '--ExeDir', "`"$GameDir`"", '--server', '--port', "$Port")
        for ($i = 0; $i -lt 60 -and -not (Test-Port $Port); $i++) { Start-Sleep -Milliseconds 500 }
        if (-not (Test-Port $Port)) { throw "游戏服务器 $Port 没起来" }
    }

    # 没加载游戏就加载（已加载则跳过，避免重复载入 elatw 的 4498 个 ERB）
    $state = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/state" -TimeoutSec 15
    if (-not $state.gameDir) {
        Write-Host "      加载游戏目录：$GameDir" -ForegroundColor DarkGray
        $body = @{ gameDir = $GameDir } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$Port/load-game" `
            -ContentType 'application/json' -Body $body -TimeoutSec 300 | Out-Null
    }
    for ($i = 0; $i -lt 120; $i++) {
        $s = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/state" -TimeoutSec 15
        if ($s.state -eq 'WaitInput') { break }
        Start-Sleep -Seconds 1
    }
    Write-Host "      游戏状态：$((Invoke-RestMethod -Uri "http://127.0.0.1:$Port/state" -TimeoutSec 15).state) ｜ windowWidth=$($state.windowWidth)" -ForegroundColor DarkGray

    # ---------- ② 前端 dev server ----------
    if (Test-Port $VitePort) {
        Write-Host "[2/4] 端口 $VitePort 已在监听 —— 复用" -ForegroundColor DarkGray
    } else {
        Write-Host "[2/4] 起 vite dev（$VitePort）..." -ForegroundColor Cyan
        $spawned += Start-Process -FilePath $node -PassThru -WindowStyle Hidden -WorkingDirectory $web `
            -ArgumentList @((Join-Path $web 'node_modules\vite\bin\vite.js'), '--port', "$VitePort", '--strictPort')
        for ($i = 0; $i -lt 60 -and -not (Test-Port $VitePort); $i++) { Start-Sleep -Milliseconds 500 }
        if (-not (Test-Port $VitePort)) { throw "vite $VitePort 没起来" }
    }

    # ---------- ③ 无头浏览器 ----------
    Write-Host "[3/4] 起无头浏览器（$Width x $Height）..." -ForegroundColor Cyan
    $spawned += Start-Process -FilePath $chrome -PassThru -WindowStyle Hidden -ArgumentList @(
        '--headless=new', '--disable-gpu', "--remote-debugging-port=$CdpPort",
        "--window-size=$Width,$Height", '--force-device-scale-factor=1', '--hide-scrollbars',
        '--no-first-run', '--no-default-browser-check', "--user-data-dir=`"$chromeProf`"",
        "http://localhost:$VitePort/")
    for ($i = 0; $i -lt 40; $i++) {
        try { Invoke-RestMethod -Uri "http://127.0.0.1:$CdpPort/json/version" -TimeoutSec 3 | Out-Null; break }
        catch { Start-Sleep -Milliseconds 500 }
    }

    # ---------- ④ 量几何 + 出图 ----------
    Write-Host "[4/4] 量几何 + 出图..." -ForegroundColor Cyan
    & $node (Join-Path $PSScriptRoot 'web-layout-probe.mjs') `
        --width $Width --height $Height --out $Out --prefix $Prefix --cdp-port $CdpPort
    Write-Host "`n✓ 完成。看图与几何：$Out\$Prefix-*.png" -ForegroundColor Green
}
finally {
    if (-not $KeepRunning) {
        foreach ($p in $spawned) {
            if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -EA SilentlyContinue }
        }
        Write-Host "（已回收本脚本起的进程；-KeepRunning 可保留）" -ForegroundColor DarkGray
    }
}
