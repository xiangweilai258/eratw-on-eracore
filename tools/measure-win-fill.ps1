# 度量 EraRelay（Windows MAUI 版）游戏窗口的「铺满度」——为 ④ 分辨率铺满提供可回归的硬指标。
#
# 背景（research/32 §十）：窗口客户区 1136x651，而游戏逻辑画布仅 760 宽；
#   截图显示文字只占左侧约 29% 宽度、底部还出现横向滚动条 ⇒ 是【横向溢出】而非【缩放适配】。
#
# 判据：截取窗口内容（PrintWindow + PW_RENDERFULLCONTENT，对 WebView2 有效），
#   统计「非黑像素」的包围盒，输出：
#     fillWidthRatio  = 内容宽 / 客户区宽   ← 越接近 1 越"铺满"
#     fillHeightRatio = 内容高 / 客户区高
#     fillAreaRatio   = 内容包围盒面积 / 客户区面积
#
# 用法：pwsh -File tools\measure-win-fill.ps1 [-ProcessName EraCore.Maui] [-SavePng <路径>]
# ★ 修前端后重跑本脚本，对比三个比值即可回归。

param(
    [string]$ProcessName = 'EraCore.Maui',
    [string]$SavePng = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class EraWin {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  public struct RECT { public int Left, Top, Right, Bottom; }
  // 游戏窗口类名（WinUI 桌面窗口）——注意 Get-Process.MainWindowHandle 会返回 DEBUG 的 console 窗口，不可用。
  public static IntPtr FindGameWindow(uint pid) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p != pid || !IsWindowVisible(h)) return true;
      var sb = new StringBuilder(256); GetClassName(h, sb, 256);
      if (sb.ToString() == "WinUIDesktopWin32WindowClass") { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
}
"@

$proc = Get-Process -Name $ProcessName -EA SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { throw "找不到进程 $ProcessName（或它没有窗口）" }

$hwnd = [EraWin]::FindGameWindow([uint32]$proc.Id)
if ($hwnd -eq [IntPtr]::Zero) { throw "找不到 WinUIDesktopWin32WindowClass 窗口（PID $($proc.Id)）" }

$wr = New-Object EraWin+RECT; [EraWin]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$cr = New-Object EraWin+RECT; [EraWin]::GetClientRect($hwnd, [ref]$cr) | Out-Null
$ww = $wr.Right - $wr.Left; $wh = $wr.Bottom - $wr.Top
$cw = $cr.Right - $cr.Left; $ch = $cr.Bottom - $cr.Top

$bmp = New-Object System.Drawing.Bitmap($ww, $wh)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
$ok = [EraWin]::PrintWindow($hwnd, $hdc, [uint32]2)
$g.ReleaseHdc($hdc); $g.Dispose()
if (-not $ok) { throw "PrintWindow 失败" }

if ($SavePng) { $bmp.Save($SavePng, [System.Drawing.Imaging.ImageFormat]::Png) }

# 逐像素扫非黑包围盒（LockBits 批量取，避免 GetPixel 慢）
$rect = New-Object System.Drawing.Rectangle(0, 0, $ww, $wh)
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($data.Stride * $wh)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$bmp.UnlockBits($data)
$bmp.Dispose()

$minX = $ww; $maxX = -1; $minY = $wh; $maxY = -1
for ($y = 0; $y -lt $wh; $y++) {
    $row = $y * $data.Stride
    for ($x = 0; $x -lt $ww; $x++) {
        $i = $row + $x * 4
        # BGRA；阈值 24 视为"非黑"（避开抗锯齿噪点）
        if ($bytes[$i] -gt 24 -or $bytes[$i + 1] -gt 24 -or $bytes[$i + 2] -gt 24) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

if ($maxX -lt 0) { throw "整幅截图全黑——PrintWindow 未取到内容" }

# ★ 判据修正（research/32 §十一）：**全图非黑包围盒不能用** —— 它会被标题栏、边框、
#   底部滚动条、WebView 自带控件撑满（实测 0.986），与"游戏内容铺满"毫无关系。
#   正确做法：只取【中段条带】y∈[20%,80%]（避开标题栏与滚动条），并**逐列**判断该列是否有内容。
$bandTop = [int]($wh * 0.20)
$bandBottom = [int]($wh * 0.80)
$colHas = New-Object bool[] $ww
$bandMinX = $ww; $bandMaxX = -1
for ($y = $bandTop; $y -le $bandBottom; $y++) {
    $row = $y * $data.Stride
    for ($x = 0; $x -lt $ww; $x++) {
        $i = $row + $x * 4
        if ($bytes[$i] -gt 24 -or $bytes[$i + 1] -gt 24 -or $bytes[$i + 2] -gt 24) {
            $colHas[$x] = $true
            if ($x -lt $bandMinX) { $bandMinX = $x }
            if ($x -gt $bandMaxX) { $bandMaxX = $x }
        }
    }
}
$colCount = ($colHas | Where-Object { $_ } | Measure-Object).Count
$clientW = $ww
$profile = ''
for ($x = 0; $x -lt $ww; $x += 100) {
    $any = $false
    for ($k = $x; $k -lt [Math]::Min($x + 100, $ww); $k++) { if ($colHas[$k]) { $any = $true; break } }
    $profile += $(if ($any) { '#' } else { '.' })
}

Write-Output "==== EraRelay 铺满度度量（可回归）===="
Write-Output ("  进程              : {0} (PID {1})" -f $proc.ProcessName, $proc.Id)
Write-Output ("  窗口外框 / 客户区 : {0}x{1} / {2}x{3}" -f $ww, $wh, $cw, $ch)
Write-Output ("  取样条带          : y={0}..{1}（避开标题栏与底部滚动条）" -f $bandTop, $bandBottom)
Write-Output ("  内容列范围        : x={0}..{1}" -f $bandMinX, $bandMaxX)
Write-Output ("  ★ contentWidthRatio = {0:N3}   ← 主判据（内容宽 / 客户区宽）" -f (($bandMaxX - $bandMinX + 1) / $clientW))
Write-Output ("  ★ columnFillRatio   = {0:N3}   （有内容的列数 / 总列数）" -f ($colCount / $ww))
Write-Output ("  横向分布(每100列) : {0}   #=有内容 .=全空" -f $profile)
Write-Output ("  （参考·慎用）全图非黑包围盒比 = {0:N3} —— 含窗口 chrome，不要拿来判断铺满" -f (($maxX - $minX + 1) / $clientW))
Write-Output "  基线 2026-10-03（Windows，未做自适应）: contentWidthRatio≈0.256 / columnFillRatio≈0.254 / 分布 ####........"
Write-Output "  修复目标: contentWidthRatio >= 0.90 且底部横向滚动条消失"
