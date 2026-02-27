#!/bin/bash
set -euo pipefail

SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"

echo "🧹 Cleaning up TaskFlow Resources"
echo ""

# Stop monitoring containers
MONITORING_IP=$(cd terraform && terraform output -raw monitoring_public_ip 2>/dev/null || echo "")

if [ -n "$MONITORING_IP" ] && [ -f "$SSH_KEY_PATH" ]; then
    echo "🛑 Stopping monitoring containers..."
    ssh -o StrictHostKeyChecking=accept-new -i "$SSH_KEY_PATH" ec2-user@$MONITORING_IP << 'EOF'
cd ~/monitoring
docker-compose down -v
docker system prune -af
EOF
fi

GUARDDUTY_ID=$(cd terraform && terraform output -raw guardduty_detector_id 2>/dev/null || echo "")

# Destroy all Terraform resources
echo "🗑️  Destroying Terraform resources..."
echo ""

cd terraform
terraform destroy -auto-approve

echo ""
echo "✅ Cleanup complete!"
