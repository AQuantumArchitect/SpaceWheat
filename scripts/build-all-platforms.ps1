<#
  scripts/build-all-platforms.ps1 - native GDExtension build on Windows (the canonical
  dev machine, issue #47). PowerShell twin of scripts/build-all-platforms.sh, which
  stays for Linux/CI (the Linux .so is built there, not here).

  Usage (PowerShell 7, repo root or anywhere):
    .\scripts\build-all-platforms.ps1                 # Windows DLL + both web wasms
    .\scripts\build-all-platforms.ps1 -Windows        # Windows DLL only
    .\scripts\build-all-platforms.ps1 -Web            # web wasms only (threaded + nothreads)
    .\scripts\build-all-platforms.ps1 -Clean          # rebuild godot-cpp from scratch

  Produces (commit them; never ship uncommitted binaries):
    native/bin/windows/libquantummatrix.windows.template_{release,debug}.x86_64.dll
    native/bin/web/libquantummatrix.wasm            (threads=yes; preset "Web", threaded engine)
    native/bin/web/libquantummatrix.nothreads.wasm  (threads=no; preset "Web-Slim", Pages)

  Toolchain (see RELEASE.md "Location"):
    - Python 3 with SCons:           pip install scons
    - MinGW-w64 g++ (WinLibs UCRT):  winget install BrechtSanders.WinLibs.POSIX.UCRT
    - emsdk, pinned:                 C:\Users\<you>\emsdk  (emsdk install 4.0.20; emsdk activate 4.0.20)
      The 4.6.2 web export template was built with Emscripten 4.0.20; a side module from any
      other version links, loads, then aborts on unresolved libc++ symbols.
  godot-cpp is the git submodule, pinned at 10.0.0-stable (api_version=4.6).
#>
param(
  [switch]$Windows,
  [switch]$Web,
  [switch]$Clean,
  [int]$Jobs = [Environment]::ProcessorCount
)
$ErrorActionPreference = 'Stop'
$EmsdkVersion = '4.0.20'
$ApiVersion   = '4.6'
if (-not $Windows -and -not $Web) { $Windows = $true; $Web = $true }

$Root     = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$GodotCpp = Join-Path $Root 'godot-cpp'
$Native   = Join-Path $Root 'native'

function Step([string]$m) { Write-Host "== $m" -ForegroundColor Cyan }
function Fail([string]$m) { throw "build-all-platforms.ps1: $m" }
function Need([string]$cmd, [string]$hint) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { Fail "$cmd not found. $hint" }
}
function Run([string]$exe, [string[]]$argv) {
  & $exe @argv
  if ($LASTEXITCODE -ne 0) { Fail "$exe failed ($LASTEXITCODE): $($argv -join ' ')" }
}

# ---- toolchain --------------------------------------------------------------
if (-not (Test-Path (Join-Path $GodotCpp 'SConstruct'))) {
  Fail "godot-cpp submodule is empty. Run: git submodule update --init --recursive"
}
Need 'scons' 'Run: pip install scons'
if ($Windows) {
  Need 'g++' 'Install MinGW-w64: winget install BrechtSanders.WinLibs.POSIX.UCRT (then reopen the shell)'
}
if ($Web) {
  if (-not (Get-Command 'em++' -ErrorAction SilentlyContinue)) {
    $emsdk = if ($env:EMSDK) { $env:EMSDK } else { Join-Path $HOME 'emsdk' }
    $envScript = Join-Path $emsdk 'emsdk_env.ps1'
    if (-not (Test-Path $envScript)) { Fail "emsdk not found at $emsdk. Install it, then: emsdk install $EmsdkVersion; emsdk activate $EmsdkVersion" }
    & (Join-Path $emsdk 'emsdk.ps1') activate $EmsdkVersion | Out-Null
    . $envScript | Out-Null
  }
  $emver = ((& em++ --version 2>$null | Select-Object -First 1) -replace '.*?(\d+\.\d+\.\d+).*', '$1')
  if ($emver -ne $EmsdkVersion) { Fail "Emscripten $emver is active; the web export template needs exactly $EmsdkVersion (emsdk activate $EmsdkVersion)" }
}

# ---- godot-cpp --------------------------------------------------------------
Push-Location $GodotCpp
try {
  if ($Clean -and (Test-Path 'bin')) { Step 'cleaning godot-cpp'; Remove-Item 'bin' -Recurse -Force }
  if ($Windows) {
    Step "godot-cpp windows (api_version=$ApiVersion)"
    Run 'scons' @('platform=windows', 'target=template_release', "api_version=$ApiVersion", 'use_mingw=yes', "-j$Jobs")
  }
  # Web: godot-cpp is built by native/SConstruct itself (below), so its flags
  # and the extension's can never drift apart.
} finally { Pop-Location }

# Same inputs as the bash path: copy the static libs into native/lib.
$lib = Join-Path $Native 'lib'
New-Item -ItemType Directory -Force $lib | Out-Null
$libs = @()
if ($Windows) { $libs += 'libgodot-cpp.windows.template_release.x86_64.a' }
foreach ($l in $libs) {
  $src = Join-Path $GodotCpp "bin/$l"
  if (-not (Test-Path $src)) { Fail "godot-cpp did not produce $l" }
  Copy-Item $src (Join-Path $lib $l) -Force
}

# ---- libquantummatrix -------------------------------------------------------
Push-Location $Native
try {
  $sources = Get-ChildItem 'src' -Recurse -Filter '*.cpp' | ForEach-Object { $_.FullName }
  $includes = @('-I./include', '-I./include/godot_cpp', '-I./include/gdextension')

  if ($Windows) {
    Step 'libquantummatrix windows'
    New-Item -ItemType Directory -Force 'bin/windows' | Out-Null
    $dll = 'bin/windows/libquantummatrix.windows.template_release.x86_64.dll'
    # Flags mirror native/Makefile.windows (the WSL cross build).
    Run 'g++' (@('-std=c++17', '-O2') + $includes + @('-DWINDOWS_ENABLED', '-DGDEXTENSION', '-DSPACEWHEAT_WITH_GODOT', '-pthread') +
               $sources + @('-shared', '-static-libgcc', '-static-libstdc++', './lib/libgodot-cpp.windows.template_release.x86_64.a', '-pthread', '-o', $dll))
    if (Get-Command 'strip' -ErrorAction SilentlyContinue) { & strip --strip-unneeded $dll }
    Copy-Item $dll 'bin/windows/libquantummatrix.windows.template_debug.x86_64.dll' -Force
  }

  if ($Web) {
    # Both variants go through godot-cpp's own SCons env (native/SConstruct), the
    # same as the bash build: a hand-written em++ line drifted from libgodot-cpp's
    # flags and produced wasms that loaded, then died in _bind_methods.
    New-Item -ItemType Directory -Force 'bin/web' | Out-Null
    foreach ($t in @('yes', 'no')) {
      Step "libquantummatrix web threads=$t"
      Run 'scons' @('platform=web', 'target=template_release', "api_version=$ApiVersion", "threads=$t", 'disable_exceptions=no', "-j$Jobs")
    }
    Set-Content 'bin/web/.emsdk-version' $EmsdkVersion
  }
} finally { Pop-Location }

# ---- summary ----------------------------------------------------------------
Step 'built'
$outs = @()
if ($Windows) { $outs += 'native/bin/windows/libquantummatrix.windows.template_release.x86_64.dll' }
if ($Web)     { $outs += 'native/bin/web/libquantummatrix.wasm', 'native/bin/web/libquantummatrix.nothreads.wasm' }
foreach ($o in $outs) {
  $p = Join-Path $Root $o
  if (-not (Test-Path $p)) { Fail "missing $o" }
  Write-Host ('  {0}  ({1:N1} MB)' -f $o, ((Get-Item $p).Length / 1MB))
}
Write-Host "Next: load-check in Godot 4.6.2, export 'Windows Desktop' and 'Web-Slim', commit the binaries."
