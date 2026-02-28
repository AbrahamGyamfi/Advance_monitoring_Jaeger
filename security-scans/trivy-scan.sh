#!/bin/bash
set -e

IMAGE=$1
REPORT_FILE=${2:-trivy-report.json}

echo "🔍 Scanning image: $IMAGE"

# Install Trivy if not present
if ! command -v trivy &> /dev/null; then
    echo "Installing Trivy..."
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
    echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt-get update && sudo apt-get install -y trivy
fi

# Scan image
trivy image --format json --output $REPORT_FILE --severity CRITICAL,HIGH $IMAGE

# Check for critical/high vulnerabilities
CRITICAL=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' $REPORT_FILE)
HIGH=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' $REPORT_FILE)

echo "📊 Scan Results:"
echo "  Critical: $CRITICAL"
echo "  High: $HIGH"

if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
    echo "❌ FAILED: Found $CRITICAL critical and $HIGH high vulnerabilities"
    exit 1
fi

echo "✅ PASSED: No critical or high vulnerabilities found"
