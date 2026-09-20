# ============================================================================
#  01-install-wsl-ubuntu.ps1   (v2 - 2026-09-20)
#  Enable / verify WSL2, install the modern WSL, install Ubuntu, set default.
#
#  RUN in an ELEVATED PowerShell:
#     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#     & "$HOME\WorkBuddy\2026-09-20-10-03-15\wsl-claude-setup\01-install-wsl-ubuntu.ps1"
#
#  ASCII-ONLY on purpose (PowerShell 5.1 reads .ps1 as ANSI/GBK without a BOM;
#  Chinese text garbles and can break parsing). Keep this file ASCII-only.
#
#  v2 CHANGELOG - why this rewrite was needed:
#   * wsl.exe writes progress to STDERR. Combined with $ErrorActionPreference
#     = 'Stop' and a `2>$null` redirect, PowerShell turns that into a
#     terminating NativeCommandError. Fixed: EAP is set to 'Continue' around
#     every wsl call and stderr is never redirected.
#   * The default WSL update endpoint (Microsoft Store CDN) returned HTTP 403
#     on this network. Fix: prefer a LOCAL MSI bundled next to this script,
#     then `wsl --update --web-download` (GitHub), then plain `wsl --update`.
#   * A stale HKCU Lxss registration for "Ubuntu" existed whose BasePath did
#     not exist on disk -> cleaned up (only when the path is really missing).
#   * Ubuntu itself is installed with --web-download (GitHub) because the
#     Store CDN is blocked here.
#
#  Idempotent: safe to run repeatedly.
# ============================================================================

$ErrorActionPreference = 'Stop'   # for PS cmdlets
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Step($m)      { Write-Host "`n==== $m ====" -ForegroundColor Cyan }
function Ok($m)        { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m)      { Write-Host "  [!!] $m" -ForegroundColor Yellow }
function Info($m)      { Write-Host "  ..   $m" -ForegroundColor Gray }

# Native exes (wsl.exe / msiexec.exe) write to stderr; never treat that as fatal.
function Use-Native { $ErrorActionPreference = 'Continue' }

# ---------------------------------------------------------------- 1. version
Step '1/7 Check Windows version'
$v = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Write-Host ("  Product    : {0}" -f $v.ProductName)
Write-Host ("  Version    : {0}  (Build {1})" -f $v.DisplayVersion, $v.CurrentBuild)

# ---------------------------------------------------------------- 2. features
Step '2/7 Verify WSL / VirtualMachinePlatform / HypervisorPlatform'
$needReboot = $false
foreach ($f in @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform', 'HypervisorPlatform')) {
    $st = (Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue).State
    Write-Host ("  {0,-38} : {1}" -f $f, $st)
    if ($st -ne 'Enabled') {
        Warn "Enabling $f ..."
        Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart | Out-Null
        $needReboot = $true
    }
}
if ($needReboot) {
    Write-Host ""
    Warn "A Windows feature was just enabled. A REBOOT IS REQUIRED."
    Warn "Reboot, then run this script again (it is idempotent)."
    exit 0
}
Ok 'All three required features are already enabled. No reboot needed.'

# ------------------------------------------------------- 3. install/update WSL
Step '3/7 Install the modern WSL (this is what the 403 / must-update error was about)'

Use-Native
$modernPath = 'C:\Program Files\WSL\wsl.exe'
$msi = Join-Path $ScriptDir 'wsl.2.7.14.0.x64.msi'
# Self-hosted copy of the upstream installer (see the project Release page).
$MsiUrl = 'https://github.com/QianRongAn/wsl2-ubuntu-claude-code-setup/releases/download/wsl-2.7.14/wsl.2.7.14.0.x64.msi'

if (Test-Path $modernPath) {
    Ok "Modern WSL already present at $modernPath"
    Info (& $modernPath --version 2>&1 | Select-Object -First 2)
} elseif (Test-Path $msi) {
    Info "Found local installer: $msi"
    Info 'Installing silently (takes ~1 minute)...'
    $p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
    if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
        Ok "WSL installed from local MSI (msiexec exit $($p.ExitCode))."
        if ($p.ExitCode -eq 3010) { Warn 'Exit 3010 = a reboot is recommended before first use.' }
    } else {
        Warn "msiexec failed with exit $($p.ExitCode). Trying wsl --update instead..."
    }
} else {
    Warn "Local MSI not found at: $msi"
    Warn 'Trying online update instead.'
}

if (-not (Test-Path $modernPath)) {
    Info 'Attempt: wsl --update --web-download  (GitHub, bypasses the blocked Store CDN)'
    & wsl.exe --update --web-download 2>&1 | ForEach-Object { Info "$_" }
    if (-not (Test-Path $modernPath)) {
        Info 'Attempt: wsl --update  (Microsoft CDN)'
        & wsl.exe --update 2>&1 | ForEach-Object { Info "$_" }
    }
    if (-not (Test-Path $modernPath)) {
        Info 'Attempt: download the MSI from this project Release (GitHub)'
        try {
            $ProgressPreference = 'SilentlyContinue'
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $MsiUrl -OutFile $msi -UseBasicParsing -ErrorAction Stop
        } catch {
            Warn "Download failed: $($_.Exception.Message)"
        }
        if (Test-Path $msi) {
            Info 'Installing the downloaded MSI silently (takes ~1 minute)...'
            $d = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
            if ($d.ExitCode -eq 0 -or $d.ExitCode -eq 3010) {
                Ok "WSL installed from downloaded MSI (msiexec exit $($d.ExitCode))."
                if ($d.ExitCode -eq 3010) { Warn 'Exit 3010 = a reboot is recommended before first use.' }
            }
        }
    }
    if (-not (Test-Path $modernPath)) {
        Warn 'Could not install the modern WSL automatically (network blocked).'
        Warn 'Download this file manually (browser / proxy) and re-run this script:'
        Warn "  $MsiUrl"
        Warn "Save it as: $msi"
        exit 1
    }
}
Ok ('Modern WSL ready: ' + (& $modernPath --version 2>&1 | Select-Object -First 1))

# --------------------------------------- 4. clean stale Ubuntu registration
Step '4/7 Check for a stale / orphaned Ubuntu registration'
$lxss = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss'
if (Test-Path $lxss) {
    foreach ($key in Get-ChildItem $lxss) {
        $prop = Get-ItemProperty $key.PSPath
        if ($prop.DistributionName -eq 'Ubuntu') {
            $bp = $prop.BasePath
            if ($bp -and -not (Test-Path $bp)) {
                Warn "Orphaned entry found: BasePath does not exist -> $bp"
                Info 'Removing the stale registration (no data can be lost, the path is absent).'
                Remove-Item $key.PSPath -Recurse -Force
                Ok 'Stale registration removed.'
            } else {
                Ok "Existing Ubuntu registration looks valid: $bp"
            }
        }
    }
} else {
    Ok 'No Lxss registrations at all.'
}

# ---------------------------------------------------- 5. default version = 2
Step '5/7 Set default WSL version to 2'
& wsl.exe --set-default-version 2 2>&1 | ForEach-Object { Info "$_" }
Ok 'Default WSL version set to 2.'

# --------------------------------------------------------- 6. install Ubuntu
Step '6/7 Install the Ubuntu distribution'
$installed = (& wsl.exe -l -q 2>&1) -replace "`0", '' | Where-Object { $_ -and $_.Trim() -ne '' -and $_ -notmatch 'must be updated|Error|error' }
if (@($installed) -contains 'Ubuntu') {
    Ok 'Ubuntu is already installed, skipping.'
} else {
    Write-Host '  Downloading Ubuntu (a few hundred MB, uses the system proxy if set)...' -ForegroundColor Yellow
    $done = $false
    foreach ($args in @(@('--no-launch','--web-download'), @('--web-download'), @())) {
        $cmdline = @('wsl.exe','--install','-d','Ubuntu') + $args
        Info ("Attempt: " + ($cmdline -join ' '))
        & $cmdline[0] $cmdline[1..($cmdline.Count-1)] 2>&1 | ForEach-Object { Info "$_" }
        $check = (& wsl.exe -l -q 2>&1) -replace "`0", ''
        if (@($check) -contains 'Ubuntu') { $done = $true; break }
    }
    if ($done) { Ok 'Ubuntu installed.' }
    else {
        Warn 'Ubuntu could not be installed automatically.'
        Warn 'Open a NEW terminal and try manually (requires a working proxy for GitHub):'
        Warn '  wsl --install -d Ubuntu --web-download'
        exit 1
    }
}

# ---------------------------------------------------- 7. set default distro
Step '7/7 Set Ubuntu as the default distribution'
& wsl.exe --set-default Ubuntu 2>&1 | ForEach-Object { Info "$_" }
Ok 'Default distribution is now Ubuntu.'

# ---------------------------------------------------- extra: .wslconfig file
Step 'Extra: write %USERPROFILE%\.wslconfig'
$wslconfig = "$env:USERPROFILE\.wslconfig"
if (-not (Test-Path $wslconfig)) {
    @'
[wsl2]
memory=8GB
processors=4
swap=4GB
localhostForwarding=true
'@ | Set-Content -Path $wslconfig -Encoding Ascii
    Ok "Created $wslconfig (8GB RAM / 4 cores / 4GB swap - edit freely)."
} else {
    Ok "$wslconfig already exists, not overwriting."
}

# ------------------------------------------------------------------- summary
Write-Host "`n==================== RESULT / NEXT STEPS ====================" -ForegroundColor Cyan
& wsl.exe -l -v 2>&1 | ForEach-Object { Write-Host "  $_" }
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1) Open a NEW terminal window and run:  wsl -d Ubuntu"
Write-Host "     First launch asks you to create a UNIX username + password."
Write-Host "  2) Verify inside Ubuntu:   uname -r    # must contain 'WSL2'"
Write-Host "  3) Verify from Windows:    wsl -l -v   # Ubuntu VERSION must be 2"
Write-Host ""
Write-Host "Details and troubleshooting: see README.md in this folder."
