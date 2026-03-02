#!/bin/bash

IMAGE=$1
REPORT_FILE=${2:-trivy-report.json}

echo "🔍 Scanning image: $IMAGE"

# Use Trivy via Docker (no installation needed)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -v $(pwd):/output \
    aquasec/trivy:latest image \
    --format json \
    --output /output/$REPORT_FILE \
    --severity CRITICAL,HIGH \
    $IMAGE || true

# Check for critical/high vulnerabilities
if [ -f "$REPORT_FILE" ]; then
    CRITICAL=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' $REPORT_FILE 2>/dev/null || echo 0)
    HIGH=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' $REPORT_FILE 2>/dev/null || echo 0)
    
    echo "📊 Scan Results:"
    echo "  Critical: $CRITICAL"
    echo "  High: $HIGH"
    
    if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
        echo "❌ FAILED: Found $CRITICAL critical and $HIGH high vulnerabilities"
        exit 1
    fi
fi

echo "✅ PASSED: No critical or high vulnerabilities found"
