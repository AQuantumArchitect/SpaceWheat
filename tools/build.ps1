<#
  tools/build.ps1 - the one place SpaceWheat is exported. CI (ci.yml, "build" job) and
  tools/release.ps1 both call this; nothing else spells an export command.

  Usage (PowerShell 7, from anywhere):
    .\tools\build.ps1 -Preset windows               # -> build/release/windows/SpaceWheat.exe
    .\tools\build.ps1 -Preset web-slim              # -> build/web-slim/index.html
    .\tools\build.ps1 -Preset windows -Out D:\x     # other output folder (it is emptied first)
    .\tools\build.ps1 -Preset windows -Godot PATH   # Godot binary (else env GODOT4, `godot` on PATH,
                                                    #   then the Windows dev-machine path below)

  Needs Godot 4.6.2 with its export templates. Refuses to build when a native binary the
  preset ships is missing, untracked, or modified: only committed binaries ship.
  Godot's exit code is unreliable for export failures, so the output-file checks are the gate.
  Rebuilding the binaries themselves is scripts/build-all-platforms.{sh,ps1}, not this.
#>
param(
  [Parameter(Mandatory=$true)][ValidateSet('windows', 'web-slim')][string]$Preset,
  [string]$Out,
  [string]$Godot
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$GodotVersion = '4.6.2'
$WindowsDevGodot = 'C:\Users\Luke Spooner\Documents\antigravity_i_guess\Godot\Godot_v4.6.2-stable_win64_console.exe'

$Presets = @{
  'windows'  = @{ Name='Windows Desktop'; File='SpaceWheat.exe'; DefaultOut='build/release/windows'
                  Native=@('native/bin/windows/libquantummatrix.windows.template_release.x86_64.dll',
                           'native/bin/windows/libquantummatrix.windows.template_debug.x86_64.dll')
                  Check=@('SpaceWheat.exe', 'libquantummatrix.windows.template_release.x86_64.dll') }
  'web-slim' = @{ Name='Web-Slim'; File='index.html'; DefaultOut='build/web-slim'
                  Native=@('native/bin/web/libquantummatrix.nothreads.wasm')
                  Check=@('index.html', 'index.pck', 'index.wasm', 'libquantummatrix.nothreads.wasm') }
}
$P = $Presets[$Preset]

function Fail([string]$msg) { throw "build.ps1: $msg" }

Push-Location $Root
try {
  # ---- native binaries: present, tracked, unmodified -------------------------
  foreach ($n in $P.Native) {
    if (-not (Test-Path $n)) { Fail "missing native binary $n (build it with scripts/build-all-platforms, then commit it)" }
    git ls-files --error-unmatch $n 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "native binary $n is not committed" }
    if (git status --porcelain -- $n) { Fail "native binary $n has uncommitted changes" }
  }

  # ---- Godot -----------------------------------------------------------------
  $bin = if ($Godot) { $Godot } elseif ($env:GODOT4) { $env:GODOT4 }
         elseif (Get-Command godot -ErrorAction SilentlyContinue) { 'godot' } else { $WindowsDevGodot }
  if (-not (Get-Command $bin -ErrorAction SilentlyContinue)) { Fail "Godot $GodotVersion not found ($bin); pass -Godot or set env GODOT4" }
  $ver = (& $bin --version 2>$null | Select-Object -Last 1)
  if (-not ($ver -like "$GodotVersion*")) { Fail "Godot at $bin reports '$ver', expected $GodotVersion" }

  # ---- export ----------------------------------------------------------------
  $dest = if ($Out) { $Out } else { Join-Path $Root $P.DefaultOut }
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  New-Item -ItemType Directory -Force $dest | Out-Null
  $dest = (Resolve-Path $dest).Path
  Write-Host "== $($P.Name)  (Godot $ver)  ->  $dest"

  & $bin --headless --path $Root --import 2>&1 | Out-Null
  & $bin --headless --path $Root --export-release $P.Name (Join-Path $dest $P.File)
  if ($LASTEXITCODE -ne 0) { Write-Warning "Godot exited $LASTEXITCODE during export" }

  foreach ($f in $P.Check) {
    if (-not (Test-Path (Join-Path $dest $f))) { Fail "build output is missing $f" }
  }
  if ($Preset -eq 'web-slim') {
    New-Item -ItemType File -Force (Join-Path $dest '.nojekyll') | Out-Null
    # GitHub Pages rejects files of 100 MB or more.
    $big = Get-ChildItem $dest -Recurse -File | Where-Object Length -gt 95MB
    if ($big) { Fail "files over 95 MB (GitHub limit 100 MB): $($big.FullName -join ', ')" }
  }
  $size = '{0:N1} MB' -f ((Get-ChildItem $dest -Recurse -File | Measure-Object Length -Sum).Sum / 1MB)
  Write-Host "Built $dest ($size)"
} finally { Pop-Location }
