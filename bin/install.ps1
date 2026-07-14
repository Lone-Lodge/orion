# install.ps1 — put orbit/orion on your PATH, permanently, for this user.
#
#   Run once:   E:\lone-lodge\orion\bin\install.ps1
#
# Fixes the usual "The system cannot find the path specified." — that comes
# from a STALE `orbit` earlier on PATH (an old shim pointing at a dead dir).
# This prepends THIS repo's bin\ so the correct, self-locating shims win, and
# tells you if an older orbit is being shadowed.

$ErrorActionPreference = 'Stop'
$bin  = $PSScriptRoot
$dist = (Resolve-Path (Join-Path $bin '..\dist') -ErrorAction SilentlyContinue)
if (-not $dist) { $dist = Join-Path $bin '..\dist' }

Write-Host "orbit setup" -ForegroundColor Cyan
Write-Host "  bin : $bin"
Write-Host "  dist: $dist"
Write-Host ""

# 1. Verify the toolchain exes exist (dist\ is gitignored, so a fresh clone
#    has these shims but no exes until the toolchain is built).
$missing = @()
foreach ($e in 'orbit.exe','orion.exe') {
    if (-not (Test-Path (Join-Path $dist $e))) { $missing += $e }
}
if ($missing.Count) {
    Write-Warning ("Missing in dist\: {0}" -f ($missing -join ', '))
    Write-Warning "Build the toolchain first — PATH will be set anyway so it works once built."
} else {
    Write-Host "  toolchain: orbit.exe + orion.exe found" -ForegroundColor Green
}

# 2. Warn about a stale 'orbit' already on PATH (the actual culprit here).
$existing = Get-Command orbit -ErrorAction SilentlyContinue
if ($existing -and $existing.Source -and ($existing.Source -notlike "$bin*")) {
    Write-Warning "Another 'orbit' is already on PATH and shadows this one:"
    Write-Warning "    $($existing.Source)"
    Write-Warning "This install prepends $bin so the correct shim wins in NEW terminals."
    Write-Warning "If it keeps losing, delete/rename that stale shim."
}

# 3. Prepend bin to the USER PATH (persistent), if not already at the front.
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
if (-not $userPath) { $userPath = '' }
$parts = @($userPath -split ';' | Where-Object { $_ -ne '' -and $_ -ne $bin })
$new = (@($bin) + $parts) -join ';'
[Environment]::SetEnvironmentVariable('Path', $new, 'User')
Write-Host "  user PATH: $bin is now first" -ForegroundColor Green

# 4. Update THIS session too, so you don't have to reopen the terminal.
if (($env:Path -split ';') -notcontains $bin) { $env:Path = "$bin;$env:Path" }

Write-Host ""
Write-Host "Done. In THIS terminal (PATH already updated) try:" -ForegroundColor Cyan
Write-Host "  cd E:\lone-lodge\cubsy"
Write-Host "  orbit play dev"
Write-Host ""
Write-Host "New terminals pick it up automatically." -ForegroundColor DarkGray
