#!/bin/bash
set -e

PROJECT_DIR="${1:-.}"
PROJECT_NAME="${2:-taskflow}"

echo "=== Running Snyk SCA Scan ==="
echo "Directory: $PROJECT_DIR"

cd "$PROJECT_DIR"

# Test for vulnerabilities
snyk test \
  --severity-threshold=high \
  --json > ../snyk-${PROJECT_NAME}-report.json || SCAN_FAILED=1

# Generate report
snyk test --json-file-output=../snyk-${PROJECT_NAME}-report.json || true

if [ "$SCAN_FAILED" = "1" ]; then
  CRITICAL=$(jq '[.vulnerabilities[] | select(.severity=="critical")] | length' ../snyk-${PROJECT_NAME}-report.json)
  HIGH=$(jq '[.vulnerabilities[] | select(.severity=="high")] | length' ../snyk-${PROJECT_NAME}-report.json)
  
  echo "❌ Snyk found vulnerabilities:"
  echo "   Critical: $CRITICAL"
  echo "   High: $HIGH"
  exit 1
fi

echo "✅ Snyk scan passed - no Critical/High vulnerabilities"
