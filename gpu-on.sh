#!/bin/bash
set -euo pipefail

# =========================
# USER CONFIG
# =========================
DROPLET_NAME="llama-fallback-gpu"
REGION="tor1"
GPU_SIZE="gpu-4000adax1-20gb"

SNAPSHOT_NAME="llama-fallback-gpu-working"
SSH_KEY_NAME="macbook-air-m4"

RESERVED_IP="146.190.191.38"

DROPLET_TAGS="llama"

# =========================
# Resolve SNAPSHOT ID
# =========================
echo "Resolving snapshot '$SNAPSHOT_NAME'..."

SNAPSHOT_IDS=$(doctl compute snapshot list \
  --format ID,Name \
  --no-header | awk "\$2==\"$SNAPSHOT_NAME\"{print \$1}")

COUNT=$(echo "$SNAPSHOT_IDS" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  echo "❌ No snapshot found named '$SNAPSHOT_NAME'"
  exit 1
elif [ "$COUNT" -gt 1 ]; then
  echo "❌ Multiple snapshots found named '$SNAPSHOT_NAME':"
  echo "$SNAPSHOT_IDS"
  echo "Make snapshot names unique."
  exit 1
fi

SNAPSHOT_ID="$SNAPSHOT_IDS"
echo "✅ Snapshot ID: $SNAPSHOT_ID"

# =========================
# Resolve SSH KEY ID
# =========================
echo "Resolving SSH key '$SSH_KEY_NAME'..."

SSH_KEY_IDS=$(doctl compute ssh-key list \
  --format ID,Name \
  --no-header | awk "\$2==\"$SSH_KEY_NAME\"{print \$1}")

COUNT=$(echo "$SSH_KEY_IDS" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  echo "❌ No SSH key found named '$SSH_KEY_NAME'"
  exit 1
elif [ "$COUNT" -gt 1 ]; then
  echo "❌ Multiple SSH keys found named '$SSH_KEY_NAME':"
  echo "$SSH_KEY_IDS"
  echo "Make SSH key names unique."
  exit 1
fi

SSH_KEY_ID="$SSH_KEY_IDS"
echo "✅ SSH key ID: $SSH_KEY_ID"

# =========================
# Create DROPLET
# =========================
echo "Creating GPU droplet '$DROPLET_NAME'..."

doctl compute droplet create "$DROPLET_NAME" \
  --region "$REGION" \
  --size "$GPU_SIZE" \
  --image "$SNAPSHOT_ID" \
  --ssh-keys "$SSH_KEY_ID" \
  --tag-names "$DROPLET_TAGS" \
  --wait

# =========================
# Resolve DROPLET ID
# =========================
echo "Resolving droplet ID..."

DROPLET_ID=$(doctl compute droplet list \
  --format ID,Name \
  --no-header | awk "\$2==\"$DROPLET_NAME\"{print \$1}")

if [ -z "$DROPLET_ID" ]; then
  echo "❌ Failed to resolve droplet ID"
  exit 1
fi

echo "✅ Droplet ID: $DROPLET_ID"

# =========================
# Assign Reserved IP
# =========================
echo "Assigning Reserved IP $RESERVED_IP..."

doctl compute reserved-ip-action assign "$RESERVED_IP" \
  "$DROPLET_ID"

echo "✅ GPU droplet ready at $RESERVED_IP delete with:"
echo "  doctl compute droplet delete $DROPLET_ID"