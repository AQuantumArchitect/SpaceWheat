<#
  tools/release.ps1 - build ONE game from a clean, tagged commit and push it to itch.

  Usage (PowerShell 7, from anywhere):
    .\tools\release.ps1 -Channel windows            # build + push (needs a tag, clean tree)
    .\tools\release.ps1 -Channel windows -DryRun    # build only, no push
    .\tools\release.ps1 -Channel windows -AllowUntagged -DryRun   # test build of an untagged HEAD

  Needs: Godot 4.6.2 with its export templates (see tools/build.ps1 for how it is found);
  for a push also butler on PATH and BUTLER_API_KEY in the environment (never printed).
  Version = the git tag on HEAD (git tag v0.3.1-alpha). It must match
  config/version in project.godot ("0.3.1-alpha"), so the title-screen stamp and
  the itch userversion can't disagree. Settings live in RELEASE.md + the block below.

  Safety rules (all enforced, none skippable on a real push):
    - only committed code ships: a dirty tree is refused unless -DryRun
    - only a tagged HEAD is pushed: -AllowUntagged is for -DryRun only
    - the tag must match project.godot's config/version
    - tools/build.ps1 does the export: pinned Godot, committed native DLL, exe + DLL in the output
#>
param(
  [Parameter(Mandatory=$true)][string]$Channel,
  [switch]$DryRun,
  [switch]$AllowUntagged
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# ---- per-game config (keep in sync with RELEASE.md) -------------------------
$ItchTarget   = 'aquantumarchitect/spacewheat'
$Channels = @{
  windows = @{ Preset='windows'; Out='build/release/windows' }
}
# -----------------------------------------------------------------------------

function Fail([string]$msg) { throw "release.ps1: $msg" }

if (-not $Channels.ContainsKey($Channel)) { Fail "Unknown channel '$Channel'. Known: $($Channels.Keys -join ', ')" }
if ($AllowUntagged -and -not $DryRun) { Fail "-AllowUntagged is only for -DryRun; itch gets tagged builds only." }
$C = $Channels[$Channel]

Push-Location $Root
try {
  # ---- source state ---------------------------------------------------------
  $dirty = git status --porcelain --untracked-files=no
  if ($dirty) {
    if (-not $DryRun) { Fail "Working tree has uncommitted changes. Commit first; releases ship only committed code." }
    Write-Warning "Working tree is dirty; this dry-run build is NOT what a release would ship."
  }
  $Tag = git describe --tags --exact-match 2>$null
  if ($LASTEXITCODE -ne 0) { $Tag = $null }
  if (-not $Tag) {
    if (-not $AllowUntagged) { Fail "HEAD has no tag. Tag it first, e.g.: git tag v0.3.1-alpha" }
    $Version = (git describe --tags --always --dirty) + '-untagged'
  } else {
    $Version = $Tag
  }
  # The tag must name the version the game shows on its title screen.
  $projVersion = (Select-String -Path (Join-Path $Root 'project.godot') -Pattern '^config/version="([^"]+)"').Matches.Groups[1].Value
  if ($Tag -and ($Tag.TrimStart('v') -ne $projVersion)) {
    $msg = "Tag $Tag does not match project.godot config/version '$projVersion'."
    if ($DryRun) { Write-Warning $msg } else { Fail "$msg Bump config/version or retag." }
  }

  # ---- tools (butler is checked before the long build, not after) -----------
  if (-not $DryRun) {
    if (-not (Get-Command butler -ErrorAction SilentlyContinue)) { Fail "butler is not on PATH" }
    if (-not $env:BUTLER_API_KEY) { Fail "BUTLER_API_KEY is not set" }
  }

  # ---- build: tools/build.ps1 owns Godot, the native-binary gate and the export --
  $Out = Join-Path $Root $C.Out
  Write-Host "== $ItchTarget`:$Channel  version $Version"
  & (Join-Path $PSScriptRoot 'build.ps1') -Preset $C.Preset -Out $Out

  Set-Content -Path (Join-Path $Out 'VERSION.txt') -Value "$Version`n$(git rev-parse HEAD)"

  if ($DryRun) { Write-Host "DryRun: built $Out, not pushed."; return }
  butler push $Out "$ItchTarget`:$Channel" --userversion $Version
  if ($LASTEXITCODE -ne 0) { Fail "butler push failed" }
  Write-Host "Pushed $Version. Now download it from itch, play 2 minutes, then update 'Last verified build' in RELEASE.md."
} finally { Pop-Location }
