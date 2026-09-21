# Phoenix installer for Windows.
#
#   irm https://github.com/mailtoharutyunyan/phoenix-releases/releases/latest/download/install.ps1 | iex
#
# Downloads the current Windows release and runs its installer. The counterpart to install.sh,
# and deliberately NOT a port of it — the two platforms fail in different places:
#
#   macOS   ships a .zip, is quarantined by the browser, and is verifiable: install.sh runs
#           `codesign --verify --deep --strict` and installs nothing if that fails.
#   Windows ships an NSIS .exe, is not quarantined, and is NOT verifiable — see VERIFICATION
#           below. This script therefore does less checking, and says so rather than printing
#           a reassuring tick it has not earned.
#
# WHICH RELEASE. `releases/latest` EXCLUDES prereleases, and the Windows build currently ships
# on prerelease tags (`v1.13.0-win1`), because publishing it as a full release would make it
# the update feed every installed macOS copy reads. So resolving `latest` would find a release
# with no .exe on it and fail with a 404 that looks like a broken script. This walks the
# release list instead and takes the newest one that actually carries a Windows installer,
# which is correct today and stays correct once Windows ships as a full release.
#
# VERIFICATION, AND ITS LIMIT — READ THIS BEFORE TRUSTING THE TICK. There is no Authenticode
# signature (no paid code-signing certificate) and no published checksum for the .exe: the
# Windows job produces no `latest.yml`, so there is nothing to compare against. What this
# script can prove is that the bytes arrived intact and are a real Windows executable — it
# checks the `MZ` header and a plausible size, and prints the SHA-256 so you can compare it
# against the release page yourself. What it CANNOT prove is who produced them. Anyone telling
# you this is "verified" the way the macOS install is would be wrong.
#
# SMARTSCREEN WILL WARN, AND THAT IS EXPECTED. An unsigned installer trips Microsoft Defender
# SmartScreen: "Windows protected your PC". It is not a malware finding — it is the absence of
# a certificate. More info -> Run anyway. Said here so it is not a surprise mid-install.

$ErrorActionPreference = 'Stop'

# PowerShell 5.1 still negotiates TLS 1.0 by default on some builds, and GitHub refuses it —
# the failure is an opaque "underlying connection was closed", not a protocol error.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = 'mailtoharutyunyan/phoenix-releases'
$Api  = "https://api.github.com/repos/$Repo"

function Write-Ok   { param($m) Write-Host "  [ok] $m" -ForegroundColor Green }
function Write-Step { param($m) Write-Host "  $m" }
function Die {
    param($m)
    Write-Host "  [x] $m" -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host '  Phoenix - Windows installer' -ForegroundColor Cyan
Write-Host ''

# ---- 1. Find a release that actually has a Windows installer -------------------------------
Write-Step 'Finding the current Windows release...'

$headers = @{ 'Accept' = 'application/vnd.github+json'; 'User-Agent' = 'phoenix-installer' }
try {
    $releases = Invoke-RestMethod -Uri "$Api/releases?per_page=30" -Headers $headers -UseBasicParsing
} catch {
    Die "Could not reach GitHub. If this says 403 or 429 it is a rate limit, not your machine, and it clears in a few minutes. ($($_.Exception.Message))"
}

$rel = $null
foreach ($r in $releases) {
    if ($r.draft) { continue }
    $exe = $r.assets | Where-Object { $_.name -like '*.exe' } | Select-Object -First 1
    if ($exe) { $rel = $r; $asset = $exe; break }
}
if (-not $rel) {
    Die 'No release carries a Windows installer yet. Check https://github.com/mailtoharutyunyan/phoenix-releases/releases'
}

$kind = if ($rel.prerelease) { ' (prerelease)' } else { '' }
Write-Ok "Found $($rel.tag_name)$kind - $($asset.name)"

# ---- 2. Download ---------------------------------------------------------------------------
$out = Join-Path $env:TEMP $asset.name
$sizeMb = [math]::Round($asset.size / 1MB, 1)
Write-Step "Downloading $sizeMb MB..."

# PROGRESS IS NOT OPTIONAL HERE, AND NEITHER IS Invoke-WebRequest.
#
# `Invoke-WebRequest`'s own progress bar repaints per chunk and makes a large download roughly
# an order of magnitude slower in PS 5.1, so it is not usable. But simply suppressing it and
# calling the blocking `WebClient.DownloadFile` prints nothing at all for 110 MB — reported
# from a real install as "windows is not showing progress", and indistinguishable from a hung
# script. install.sh already learned this on macOS and passes `curl -#` for the same reason.
#
# So: download ASYNCHRONOUSLY and poll the file on disk against the size GitHub already told us
# in the release metadata. The bar is drawn with a carriage return on one line, four times a
# second, which costs nothing measurable and never scrolls.
$prevProgress = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'
$wc = $null
try {
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', 'phoenix-installer')
    $task = $wc.DownloadFileTaskAsync($asset.browser_download_url, $out)

    $total = [double]$asset.size
    $started = Get-Date
    while (-not $task.IsCompleted) {
        Start-Sleep -Milliseconds 250
        $have = 0
        if (Test-Path $out) { try { $have = (Get-Item $out).Length } catch { $have = 0 } }
        $frac = if ($total -gt 0) { [math]::Min(1.0, $have / $total) } else { 0 }
        $filled = [int]($frac * 28)
        $bar = ('=' * $filled).PadRight(28, '.')
        $elapsed = ((Get-Date) - $started).TotalSeconds
        $rate = if ($elapsed -gt 0) { ($have / 1MB) / $elapsed } else { 0 }
        Write-Host -NoNewline ("`r  [{0}] {1,3:N0}%  {2,6:N1}/{3:N1} MB  {4,5:N1} MB/s" -f `
            $bar, ($frac * 100), ($have / 1MB), ($total / 1MB), $rate)
    }
    # Surfaces the real exception; without this a failed task is silently a zero-byte file.
    $task.GetAwaiter().GetResult()
    Write-Host -NoNewline ("`r{0}`r" -f (' ' * 78))
} catch {
    Write-Host ''
    Die "Download failed: $($_.Exception.Message)"
} finally {
    $ProgressPreference = $prevProgress
    if ($wc) { $wc.Dispose() }
}

# ---- 3. Check what can actually be checked --------------------------------------------------
$file = Get-Item $out
if ($file.Length -ne $asset.size) {
    Remove-Item $out -Force -ErrorAction SilentlyContinue
    Die "Download was $($file.Length) bytes, expected $($asset.size). It has been discarded - run this again."
}

# `MZ` is the DOS header every Windows executable starts with. A truncated download or an HTML
# error page saved under an .exe name both fail here, and both would otherwise be discovered by
# the user double-clicking something that does nothing.
$head = [System.IO.File]::ReadAllBytes($out)[0..1]
if ($head[0] -ne 0x4D -or $head[1] -ne 0x5A) {
    Remove-Item $out -Force -ErrorAction SilentlyContinue
    Die 'The download is not a Windows executable - it has been discarded. Run this again.'
}
Write-Ok "$($file.Length) bytes, valid executable header"

$sha = (Get-FileHash -Path $out -Algorithm SHA256).Hash.ToLower()
Write-Step "SHA-256: $sha"
Write-Host '       (no publisher signature exists - compare this against the release page if it matters to you)' -ForegroundColor DarkGray

# ---- 4. Install ------------------------------------------------------------------------------
Write-Host ''
Write-Host '  SmartScreen may warn that the publisher is unknown. The installer is unsigned;' -ForegroundColor Yellow
Write-Host '  that warning is the absence of a certificate, not a malware finding.' -ForegroundColor Yellow
Write-Host '  Choose "More info" then "Run anyway".' -ForegroundColor Yellow
Write-Host ''
Write-Step 'Starting the installer...'

# NSIS built with oneClick:false shows a real wizard, so this must NOT be run silently: the user
# chooses the install directory. Waited on so the summary below reflects the actual outcome.
$proc = Start-Process -FilePath $out -PassThru -Wait
if ($proc.ExitCode -ne 0) {
    Die "The installer exited with code $($proc.ExitCode). Nothing was changed if you cancelled it."
}

Remove-Item $out -Force -ErrorAction SilentlyContinue
Write-Ok 'Installed.'
Write-Host ''
Write-Host '  Phoenix hides its taskbar button while Private mode is on, so use Ctrl+B to show' -ForegroundColor DarkGray
Write-Host '  and hide the overlay (Ctrl+Alt+B always shows it).' -ForegroundColor DarkGray
Write-Host ''
