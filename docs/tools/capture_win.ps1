# A window's picture on Windows, for capture.tcl (X11 has ImageMagick's
# import): the client area of the window whose handle Tk's `wm frame` gives,
# without its title bar or borders, copied from the screen. The window must
# be shown whole and on top (capture.tcl raises it, and puts it at the
# screen's top left); nothing is asked of its thread, so the caller may
# wait for this to end (PrintWindow, which asks the window to draw itself,
# needs the caller's event loop running, and a handler that waits in it
# stalled the capture).
#   powershell -NoProfile -ExecutionPolicy Bypass -File capture_win.ps1 <0x-handle> <file.png>
param([Parameter(Mandatory = $true)][string]$Handle,
      [Parameter(Mandatory = $true)][string]$Out)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class VmdanceCapture {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT p);
}
"@
[VmdanceCapture]::SetProcessDPIAware() | Out-Null
$h = [IntPtr]::new([Convert]::ToInt64(($Handle -replace '^0x', ''), 16))
$r = New-Object VmdanceCapture+RECT
if (-not [VmdanceCapture]::GetClientRect($h, [ref]$r)) { throw "no window $Handle" }
$w = $r.Right - $r.Left
$ht = $r.Bottom - $r.Top
if ($w -le 0 -or $ht -le 0) { throw "window $Handle has no area (${w}x${ht})" }
$p = New-Object VmdanceCapture+POINT
if (-not [VmdanceCapture]::ClientToScreen($h, [ref]$p)) { throw "window ${Handle}: no place on the screen" }
$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($p.X, $p.Y, 0, 0, (New-Object System.Drawing.Size $w, $ht))
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
