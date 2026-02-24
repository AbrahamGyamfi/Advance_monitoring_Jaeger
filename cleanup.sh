#!/bin/bash
set -euo pipefail

SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"

echo "🧹 Cleaning up TaskFlow Monitoring Resources"
echo "⚠️  Note: GuardDuty and CloudTrail will NOT be deleted"
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

# Destroy Terraform resources (excludes GuardDuty and CloudTrail)
echo "🗑️  Destroying Terraform resources..."
echo "    - EC2 instances (Jenkins, App, Monitoring)"
echo "    - Security groups"
echo "    - IAM roles and policies"
echo "    - CloudWatch log groups"
echo "    - S3 bucket (CloudTrail logs)"
echo ""
echo "    ✓ Keeping: GuardDuty detector"
echo "    ✓ Keeping: CloudTrail trail"
echo ""

cd terraform
terraform destroy -auto-approve

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Resources preserved:"
if [ -n "$GUARDDUTY_ID" ]; then
  echo "  - GuardDuty detector: $GUARDDUTY_ID"
else
  echo "  - GuardDuty detector: (query with: aws guardduty list-detectors)"
fi
echo "  - CloudTrail trail: taskflow-trail"
echo ""
echo "To manually delete if needed:"
if [ -n "$GUARDDUTY_ID" ]; then
  echo "  aws guardduty delete-detector --detector-id $GUARDDUTY_ID --region eu-west-1"
else
  echo "  aws guardduty delete-detector --detector-id <detector-id> --region eu-west-1"
fi
echo "  aws cloudtrail delete-trail --name taskflow-trail --region eu-west-1"
