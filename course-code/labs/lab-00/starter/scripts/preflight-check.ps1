# preflight-check.ps1 — LLMOps Course Environment Validation (Windows)
# Run this before Lab 00: .\scripts\preflight-check.ps1
# Requires PowerShell 5.1+ (Windows) or PowerShell 7+ (cross-platform)

$Pass = 0; $Warn = 0; $Fail = 0

function Pass([string]$msg) { Write-Host "[PASS] $msg" -ForegroundColor Green; $script:Pass++ }
function Warn([string]$msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow; $script:Warn++ }
function Fail([string]$msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:Fail++ }

Write-Host "============================================="
Write-Host " LLMOps Course — Preflight Check"
Write-Host "============================================="

# OS detection
Write-Host ""
Write-Host "==> System: Windows (PowerShell $($PSVersionTable.PSVersion))"

# --- Docker Desktop ---
Write-Host ""
Write-Host "==> Checking Docker..."
$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Fail "Docker is not running. Start Docker Desktop first, then re-run this script."
} else {
    Pass "Docker is running"

    # Memory check
    $memBytes = [long](docker system info --format '{{.MemTotal}}' 2>$null)
    $memGB = [math]::Floor($memBytes / 1073741824)
    if ($memGB -ge 12) {
        Pass "Docker memory: ${memGB}GB (recommended >= 12GB)"
    } elseif ($memGB -ge 8) {
        Warn "Docker memory: ${memGB}GB (minimum met; recommend 12GB for Labs 04-09 — Docker Desktop > Settings > Resources > Memory)"
    } else {
        Fail "Docker memory: ${memGB}GB (below 8GB minimum — increase in Docker Desktop > Settings > Resources > Memory)"
    }

    # Disk space check
    try {
        $drive = (Split-Path (docker info --format '{{.DockerRootDir}}' 2>$null) -Qualifier)
        if (-not $drive) { $drive = "C:" }
        $disk = Get-PSDrive ($drive.TrimEnd(':')) -ErrorAction Stop
        $freeGB = [math]::Floor($disk.Free / 1GB)
        if ($freeGB -ge 20) {
            Pass "Disk space: ${freeGB}GB available on $drive"
        } else {
            Fail "Disk space: ${freeGB}GB available (need at least 20GB free on $drive)"
        }
    } catch {
        Warn "Could not check disk space. Ensure at least 20GB is available."
    }
}

# --- Required Tools ---
Write-Host ""
Write-Host "==> Checking required tools..."
foreach ($tool in @("kind", "kubectl", "helm", "docker")) {
    $cmd = Get-Command $tool -ErrorAction SilentlyContinue
    if ($cmd) {
        Pass "$tool found: $($cmd.Source)"
    } else {
        Fail "$tool not found — see prerequisites page at https://llmops.schoolofdevops.com/docs/setup/prerequisites"
    }
}

# --- Port Availability ---
Write-Host ""
Write-Host "==> Checking port availability..."
foreach ($port in @(80, 8000, 30000, 32000)) {
    $result = Test-NetConnection -ComputerName localhost -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue 2>$null
    if ($result) {
        Warn "Port $port is in use — may conflict with course lab services. Stop the conflicting service before starting Lab 00."
    } else {
        Pass "Port $port is available"
    }
}

# --- Stale KIND Cluster Check ---
Write-Host ""
Write-Host "==> Checking for stale KIND clusters..."
$kindCmd = Get-Command kind -ErrorAction SilentlyContinue
if ($kindCmd) {
    $clusters = kind get clusters 2>$null
    if ($clusters -match "llmops-kind") {
        Warn "Stale cluster found: llmops-kind already exists. If starting fresh, delete it: kind delete cluster --name llmops-kind"
    } else {
        Pass "No stale llmops-kind cluster found"
    }
}

# --- Summary ---
Write-Host ""
Write-Host "============================================="
Write-Host "==> Preflight summary: $Pass passed, $Warn warnings, $Fail failed"
Write-Host "============================================="

if ($Fail -gt 0) {
    Write-Host ""
    Write-Host "Fix the [FAIL] items above before proceeding to Lab 00." -ForegroundColor Red
    exit 1
}

if ($Warn -gt 0) {
    Write-Host ""
    Write-Host "Review the [WARN] items above. Warnings will not block Lab 00 but may cause issues in later labs." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Your environment is ready. Proceed to Lab 00: Cluster Setup." -ForegroundColor Green
