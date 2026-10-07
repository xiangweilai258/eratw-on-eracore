<#
外发前自检 —— 扫描待发布目录，检查六类合规红线。

用法：
    pwsh tools/check-release.ps1 -Path <目录>
    pwsh tools/check-release.ps1 -Path <目录> -Deep      # 额外做文本内容扫描（慢，逐文件读）

分级：
    FAIL  必须修掉，否则不要发
    WARN  人工确认
    OK    通过

依据见仓库根目录 RELEASE-RULES.md。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [switch]$Deep
)

$ErrorActionPreference = 'Continue'

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "路径不存在: $Path" -ForegroundColor Red
    exit 2
}
$root = (Resolve-Path -LiteralPath $Path).Path
Write-Host "=== 外发自检 ===" -ForegroundColor Cyan
Write-Host "目标: $root"
Write-Host "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if ($Deep) { Write-Host "模式: 深度（含文本内容扫描）" }
Write-Host ''

$fails = New-Object System.Collections.Generic.List[string]
$warns = New-Object System.Collections.Generic.List[string]
$oks   = New-Object System.Collections.Generic.List[string]

function Add-Fail([string]$m) { $script:fails.Add($m) }
function Add-Warn([string]$m) { $script:warns.Add($m) }
function Add-Ok([string]$m)   { $script:oks.Add($m) }

$files = Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue
Write-Host "文件总数: $($files.Count)"

# ---------- 1. 游戏本体特征 ----------
$erb = @($files | Where-Object { $_.Extension -eq '.erb' })
$csv = @($files | Where-Object { $_.Extension -eq '.csv' })
$hasEraDir = Test-Path -LiteralPath (Join-Path $root 'eraTW')
$hasConfig = @($files | Where-Object { $_.Name -eq 'emuera.config' }).Count -gt 0
$hasSav    = @($files | Where-Object { $_.Extension -eq '.sav' }).Count -gt 0

if ($hasEraDir) { Add-Fail "存在 eraTW/ 目录 —— 这是游戏本体" }
if ($erb.Count -gt 100) { Add-Fail ".erb 文件 $($erb.Count) 个（>100）—— 高度疑似游戏本体" }
elseif ($erb.Count -gt 0) { Add-Warn ".erb 文件 $($erb.Count) 个 —— 确认是否为游戏内容" }
if ($hasConfig) { Add-Fail "存在 emuera.config —— 游戏配置，通常属游戏本体" }
if ($hasSav)    { Add-Fail "存在 .sav 存档 —— 游戏数据" }
if ($csv.Count -gt 50) { Add-Warn ".csv 文件 $($csv.Count) 个 —— 确认是否为游戏数据表" }
if (-not $hasEraDir -and $erb.Count -eq 0 -and -not $hasConfig) { Add-Ok "未发现游戏本体特征" }

# ---------- 2. APK / 大二进制 ----------
$apks = @($files | Where-Object { $_.Extension -in '.apk', '.aab', '.ipa' })
if ($apks.Count -gt 0) {
    Add-Fail "存在安装包 $($apks.Count) 个: $(($apks | Select-Object -First 3 | ForEach-Object { $_.Name }) -join ', ')"
} else { Add-Ok "无 APK/AAB/IPA" }

$big = @($files | Where-Object { $_.Length -gt 200MB })
foreach ($f in $big) { Add-Warn "超大文件 $([math]::Round($f.Length/1MB,1)) MB: $($f.FullName.Substring($root.Length))" }

# ---------- 3. 凭证文件名 ----------
$credPat = '(?i)^(\.?gh_token|\.?git-credentials|id_rsa|id_ed25519|\.env|\.npmrc|\.pypirc|.*\.token|token\.txt|credentials\.json)$'
$creds = @($files | Where-Object { $_.Name -match $credPat })
if ($creds.Count -gt 0) {
    Add-Fail "存在疑似凭证文件: $(($creds | Select-Object -First 5 | ForEach-Object { $_.FullName.Substring($root.Length) }) -join ', ')"
} else { Add-Ok "无凭证类文件名" }

# ---------- 4. 合规必备文件 ----------
foreach ($need in @('LICENSE-NOTICE.md', 'README.md')) {
    if (Test-Path -LiteralPath (Join-Path $root $need)) { Add-Ok "合规文件存在: $need" }
    else { Add-Fail "缺少 $need —— 外发必须带署名与许可说明" }
}

# ---------- 5. 构建产物 / 内部状态 ----------
$junkDirs = @('bin', 'obj', 'node_modules', '.git', '.vs')
foreach ($d in $junkDirs) {
    $hit = @($files | Where-Object { $_.FullName -match "\\$([regex]::Escape($d))\\" })
    if ($hit.Count -gt 0) { Add-Warn "含构建产物/内部状态目录 '$d'（$($hit.Count) 个文件）—— 外发前建议剔除" }
}

# ---------- 6. 个人标识 / 绝对路径 ----------
$exts = @('.md', '.txt', '.py', '.ps1', '.sh', '.json', '.yml', '.yaml', '.cs', '.ts', '.vue', '.xml', '.cfg', '.toml')
$scan = if ($Deep) { @($files | Where-Object { $_.Extension -in $exts }) }
        else { @($files | Where-Object { $_.Extension -in @('.md', '.txt', '.py', '.ps1', '.sh') }) }
# ★ 必须同时覆盖 Windows 反斜杠与正斜杠：实测 port/make-patch.py 用的是 "C:/Users/<名>/..."，
# 只写反斜杠的形式会整个漏掉（本脚本首版就漏了，被当场抓到）。
$piiPat = '(?-i)([A-Za-z]:[\\/]Users[\\/]|/Users/|/home/)(?![<>$%])[A-Za-z0-9_.\-]+'
$piiHits = New-Object System.Collections.Generic.List[string]
foreach ($f in $scan) {
    try {
        $m = Select-String -LiteralPath $f.FullName -Pattern $piiPat -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($m) { $piiHits.Add("$($f.FullName.Substring($root.Length)) (L$($m[0].LineNumber))") }
    } catch { }
}
if ($piiHits.Count -gt 0) {
    Add-Warn "疑似个人标识/绝对路径 $($piiHits.Count) 处（扫描 $($scan.Count) 个文本文件）:"
    $piiHits | Select-Object -First 10 | ForEach-Object { Add-Warn "    $_" }
} else { Add-Ok "未发现个人标识/绝对路径（扫描 $($scan.Count) 个文本文件）" }

# ---------- 汇总 ----------
Write-Host ''
Write-Host '=== FAIL ===' -ForegroundColor Red
if ($fails.Count -eq 0) { Write-Host '  （无）' -ForegroundColor DarkGray } else { $fails | ForEach-Object { Write-Host "  x $_" -ForegroundColor Red } }
Write-Host ''
Write-Host '=== WARN ===' -ForegroundColor Yellow
if ($warns.Count -eq 0) { Write-Host '  （无）' -ForegroundColor DarkGray } else { $warns | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Yellow } }
Write-Host ''
Write-Host '=== OK ===' -ForegroundColor Green
$oks | ForEach-Object { Write-Host "  v $_" -ForegroundColor Green }

Write-Host ''
if ($fails.Count -gt 0) {
    Write-Host "结论: 不要发（$($fails.Count) 项 FAIL）" -ForegroundColor Red
    exit 1
}
Write-Host "结论: 可以发（$($warns.Count) 项 WARN 请人工确认）" -ForegroundColor Green
exit 0
