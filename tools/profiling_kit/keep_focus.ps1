# Keep SpaceWheat in the foreground so Windows does not throttle a
# background game window during a headed profile run.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class SwFocus {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
$deadline = (Get-Date).AddMinutes(12)
while ((Get-Date) -lt $deadline) {
    $p = Get-Process -Name "SpaceWheat" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p -and $p.MainWindowHandle -ne [IntPtr]::Zero) {
        [void][SwFocus]::ShowWindow($p.MainWindowHandle, 9)
        [void][SwFocus]::SetForegroundWindow($p.MainWindowHandle)
    }
    Start-Sleep -Milliseconds 750
}
