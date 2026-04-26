#Requires -Version 5.1
<#
.SYNOPSIS
    Installs whisper-npu-dictation — Whisper on AMD XDNA 2 NPU, global push-to-talk.

.DESCRIPTION
    1. Checks prerequisites (Windows 11, NPU present, Python, winget)
    2. Installs Lemonade Server (MSI)
    3. Installs AutoHotkey v2
    4. Installs Python audio packages (sounddevice, soundfile, numpy)
    5. Installs whispercpp:npu backend and pulls the Whisper model
    6. Configures the NPU as default backend
    7. Creates a Windows startup shortcut
    8. Launches dictee.ahk

.NOTES
    Run from C:\scripts\dictee\ as your normal user account.
    One UAC prompt for Lemonade MSI install — everything else is user-level.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Lem       = "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe"
$AHK       = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"

function Write-Step  { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Host "    --  $msg (already done)" -ForegroundColor DarkGray }
function Write-Fail  { param($msg) Write-Host "    !!  $msg" -ForegroundColor Red; exit 1 }

# ── 0. Prerequisites ────────────────────────────────────────────────────────

Write-Step "Checking prerequisites"

# Windows 11
$build = [System.Environment]::OSVersion.Version.Build
if ($build -lt 22000) { Write-Fail "Windows 11 required (build 22000+). Found build $build." }
Write-OK "Windows 11 build $build"

# NPU
$npu = Get-PnpDevice -Class ComputeAccelerator -ErrorAction SilentlyContinue |
       Where-Object Status -eq OK
if (-not $npu) { Write-Fail "No NPU found (ComputeAccelerator device, Status=OK). Check Device Manager." }
Write-OK "NPU detected: $($npu.FriendlyName)"

# Python
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { Write-Fail "Python not found. Install from https://www.python.org/ and add to PATH." }
$pyver = & python --version 2>&1
Write-OK "Python: $pyver"

# winget
$wg = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wg) { Write-Fail "winget not found. Update the App Installer from the Microsoft Store." }
Write-OK "winget found"

# ── 1. Lemonade Server ───────────────────────────────────────────────────────

Write-Step "Lemonade Server"

if (Test-Path $Lem) {
    $lemver = & $Lem --version 2>&1
    Write-Skip "Lemonade already installed ($lemver)"
} else {
    $msi = "$env:TEMP\lemonade.msi"
    Write-Host "    Fetching latest release info..."
    $release = Invoke-RestMethod "https://api.github.com/repos/lemonade-sdk/lemonade/releases/latest"
    $asset   = $release.assets | Where-Object name -eq "lemonade.msi"
    if (-not $asset) { Write-Fail "lemonade.msi not found in latest release assets." }
    Write-Host "    Downloading lemonade.msi $($release.tag_name) ($([math]::Round($asset.size/1MB,1)) MB)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msi -UseBasicParsing
    Write-Host "    Installing (UAC prompt expected)..."
    Start-Process msiexec -ArgumentList "/i `"$msi`" /quiet /norestart" -Verb RunAs -Wait
    if (-not (Test-Path $Lem)) { Write-Fail "Lemonade install failed — $Lem not found after install." }
    Write-OK "Lemonade Server installed"
}

# ── 2. AutoHotkey v2 ────────────────────────────────────────────────────────

Write-Step "AutoHotkey v2"

if (Test-Path $AHK) {
    Write-Skip "AutoHotkey already installed"
} else {
    winget install --id AutoHotkey.AutoHotkey --accept-source-agreements --accept-package-agreements --silent
    if (-not (Test-Path $AHK)) { Write-Fail "AutoHotkey install failed — $AHK not found." }
    Write-OK "AutoHotkey v2 installed"
}

# ── 3. Python audio packages ─────────────────────────────────────────────────

Write-Step "Python packages (sounddevice, soundfile, numpy)"

$missing = @()
foreach ($pkg in @("sounddevice", "soundfile", "numpy")) {
    $check = & python -c "import $pkg" 2>&1
    if ($LASTEXITCODE -ne 0) { $missing += $pkg }
}

if ($missing.Count -eq 0) {
    Write-Skip "All packages already installed"
} else {
    Write-Host "    Installing: $($missing -join ', ')..."
    & python -m pip install --quiet $missing
    Write-OK "Packages installed"
}

# ── 4. Lemonade: whispercpp:npu backend ──────────────────────────────────────

Write-Step "whispercpp:npu backend"

$info = Invoke-RestMethod "http://localhost:13305/api/v1/system-info" -ErrorAction SilentlyContinue
if (-not $info) {
    Write-Host "    Starting Lemonade Server..."
    Start-Process "$env:LOCALAPPDATA\lemonade_server\app\lemonade-app.exe"
    $timeout = (Get-Date).AddSeconds(15)
    while ((Get-Date) -lt $timeout) {
        Start-Sleep -Seconds 2
        $info = Invoke-RestMethod "http://localhost:13305/api/v1/system-info" -ErrorAction SilentlyContinue
        if ($info) { break }
    }
    if (-not $info) { Write-Fail "Lemonade Server did not start within 15 s." }
}

$backendState = $info.recipes.whispercpp.backends.npu.state
if ($backendState -eq "installed") {
    Write-Skip "whispercpp:npu backend already installed"
} else {
    Write-Host "    Installing whispercpp:npu backend..."
    & $Lem backends install whispercpp:npu
    Write-OK "whispercpp:npu backend installed"
}

# ── 5. Whisper model ─────────────────────────────────────────────────────────

Write-Step "Whisper-Large-v3-Turbo model"

$modelRow = & $Lem list 2>&1 | Select-String "Whisper-Large-v3-Turbo"
if ($modelRow -and $modelRow -match "\bYes\b") {
    Write-Skip "Model already downloaded"
} else {
    Write-Host "    Pulling Whisper-Large-v3-Turbo (~1.5 GB)..."
    & $Lem pull Whisper-Large-v3-Turbo
    Write-OK "Model downloaded"
}

# ── 6. Configure NPU as default backend ──────────────────────────────────────

Write-Step "Setting whispercpp.backend = npu"
& $Lem config set whispercpp.backend=npu | Out-Null
Write-OK "Backend configured"

# ── 7. Load model on NPU ─────────────────────────────────────────────────────

Write-Step "Loading Whisper on NPU"

$status = & $Lem status 2>&1
if ($status -match "Whisper-Large-v3-Turbo") {
    Write-Skip "Model already loaded"
} else {
    & $Lem load Whisper-Large-v3-Turbo
    Write-OK "Model loaded on NPU"
}

# ── 8. Startup shortcut ───────────────────────────────────────────────────────

Write-Step "Windows startup shortcut"

$lnkPath = [System.Environment]::GetFolderPath('Startup') + "\dictee_vocale.lnk"
if (Test-Path $lnkPath) {
    Write-Skip "Startup shortcut already exists"
} else {
    $ws  = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut($lnkPath)
    $lnk.TargetPath       = $AHK
    $lnk.Arguments        = "`"$ScriptDir\dictee.ahk`""
    $lnk.WorkingDirectory = $ScriptDir
    $lnk.Description      = "Dictee vocale NPU — Ctrl+Maj"
    $lnk.Save()
    Write-OK "Startup shortcut created"
}

# ── 9. Launch ─────────────────────────────────────────────────────────────────

Write-Step "Launching dictee.ahk"

$running = Get-Process AutoHotkey -ErrorAction SilentlyContinue |
           Where-Object { $_.MainWindowTitle -eq "" }   # background AHK instances
if ($running) {
    Write-Host "    Restarting existing AHK instance..."
    $running | Stop-Process -Force
    Start-Sleep -Milliseconds 500
}
Start-Process $AHK -ArgumentList "`"$ScriptDir\dictee.ahk`""
Start-Sleep -Milliseconds 1500
$ahkProc = Get-Process AutoHotkey -ErrorAction SilentlyContinue
if ($ahkProc) { Write-OK "dictee.ahk running (PID $($ahkProc.Id))" }
else           { Write-Fail "AutoHotkey did not stay running — check dictee.ahk for syntax errors." }

# ── Done ──────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "  Installation complete." -ForegroundColor Green
Write-Host "  Hold Left Ctrl + Left Shift to dictate." -ForegroundColor Green
Write-Host "  Right-click the AHK tray icon to disable/quit." -ForegroundColor Green
Write-Host "  NOTE: after a reboot, reload the model with:" -ForegroundColor Yellow
Write-Host "    lemonade load Whisper-Large-v3-Turbo" -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Green
