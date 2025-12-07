#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# =========================
# USER CONFIG
# =========================
$DROPLET_NAME = "llama-fallback-gpu"
$REGION = "tor1"
$GPU_SIZE = "gpu-4000adax1-20gb"

$SNAPSHOT_NAME = "llama-fallback-gpu-working"
$SSH_KEY_NAME = "macbook-air-m4"

$RESERVED_IP = "146.190.191.38"

$DROPLET_TAGS = "llama"

# =========================
# Resolve SNAPSHOT ID
# =========================
Write-Host "Resolving snapshot '$SNAPSHOT_NAME'..." -ForegroundColor Cyan

$snapshotOutput = doctl compute snapshot list --format ID,Name --no-header | Out-String
$snapshotLines = $snapshotOutput -split "`n" | Where-Object { $_.Trim() -ne "" }

$matchingSnapshots = $snapshotLines | Where-Object { 
    $_ -match '^\s*(\S+)\s+(.+)$' -and $Matches[2].Trim() -eq $SNAPSHOT_NAME
}

$COUNT = ($matchingSnapshots | Measure-Object).Count

if ($COUNT -eq 0) {
    Write-Host "❌ No snapshot found named '$SNAPSHOT_NAME'" -ForegroundColor Red
    exit 1
} elseif ($COUNT -gt 1) {
    Write-Host "❌ Multiple snapshots found named '$SNAPSHOT_NAME':" -ForegroundColor Red
    $matchingSnapshots | ForEach-Object { Write-Host $_ }
    Write-Host "Make snapshot names unique." -ForegroundColor Red
    exit 1
}

$matchingSnapshots[0] -match '^\s*(\S+)\s+' | Out-Null
$SNAPSHOT_ID = $Matches[1]
Write-Host "✅ Snapshot ID: $SNAPSHOT_ID" -ForegroundColor Green

# =========================
# Resolve SSH KEY ID
# =========================
Write-Host "Resolving SSH key '$SSH_KEY_NAME'..." -ForegroundColor Cyan

$sshKeyOutput = doctl compute ssh-key list --format ID,Name --no-header | Out-String
$sshKeyLines = $sshKeyOutput -split "`n" | Where-Object { $_.Trim() -ne "" }

$matchingKeys = $sshKeyLines | Where-Object { 
    $_ -match '^\s*(\S+)\s+(.+)$' -and $Matches[2].Trim() -eq $SSH_KEY_NAME
}

$COUNT = ($matchingKeys | Measure-Object).Count

if ($COUNT -eq 0) {
    Write-Host "❌ No SSH key found named '$SSH_KEY_NAME'" -ForegroundColor Red
    exit 1
} elseif ($COUNT -gt 1) {
    Write-Host "❌ Multiple SSH keys found named '$SSH_KEY_NAME':" -ForegroundColor Red
    $matchingKeys | ForEach-Object { Write-Host $_ }
    Write-Host "Make SSH key names unique." -ForegroundColor Red
    exit 1
}

$matchingKeys[0] -match '^\s*(\S+)\s+' | Out-Null
$SSH_KEY_ID = $Matches[1]
Write-Host "✅ SSH key ID: $SSH_KEY_ID" -ForegroundColor Green

# =========================
# Create DROPLET
# =========================
Write-Host "Creating GPU droplet '$DROPLET_NAME'..." -ForegroundColor Cyan

doctl compute droplet create $DROPLET_NAME `
    --region $REGION `
    --size $GPU_SIZE `
    --image $SNAPSHOT_ID `
    --ssh-keys $SSH_KEY_ID `
    --tag-names $DROPLET_TAGS `
    --wait

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create droplet" -ForegroundColor Red
    exit 1
}

# =========================
# Resolve DROPLET ID
# =========================
Write-Host "Resolving droplet ID..." -ForegroundColor Cyan

$dropletOutput = doctl compute droplet list --format ID,Name --no-header | Out-String
$dropletLines = $dropletOutput -split "`n" | Where-Object { $_.Trim() -ne "" }

$matchingDroplet = $dropletLines | Where-Object { 
    $_ -match '^\s*(\S+)\s+(.+)$' -and $Matches[2].Trim() -eq $DROPLET_NAME
}

if (-not $matchingDroplet) {
    Write-Host "❌ Failed to resolve droplet ID" -ForegroundColor Red
    exit 1
}

$matchingDroplet -match '^\s*(\S+)\s+' | Out-Null
$DROPLET_ID = $Matches[1]
Write-Host "✅ Droplet ID: $DROPLET_ID" -ForegroundColor Green

# =========================
# Assign Reserved IP
# =========================
Write-Host "Assigning Reserved IP $RESERVED_IP..." -ForegroundColor Cyan

doctl compute reserved-ip-action assign $RESERVED_IP $DROPLET_ID

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to assign reserved IP" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ GPU droplet ready at $RESERVED_IP delete with:" -ForegroundColor Green
Write-Host "  doctl compute droplet delete $DROPLET_ID" -ForegroundColor Yellow
