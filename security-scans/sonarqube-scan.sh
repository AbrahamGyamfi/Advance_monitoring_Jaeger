#!/bin/bash
set -e

PROJECT_KEY="${1:-taskflow}"
SOURCE_DIR="${2:-.}"

echo "=== Running SonarQube SAST Scan ==="
echo "Project: $PROJECT_KEY"
echo "Source: $SOURCE_DIR"

# Run SonarQube scanner (using image with Node.js)
docker run --rm --network host \
  -e SONAR_HOST_URL="${SONAR_HOST_URL}" \
  -e SONAR_TOKEN="${SONAR_TOKEN}" \
  -v "$(pwd)/$SOURCE_DIR:/usr/src" \
  sonarsource/sonar-scanner-cli:latest \
  -Dsonar.projectKey="$PROJECT_KEY" \
  -Dsonar.sources=. \
  -Dsonar.exclusions="**/node_modules/**,**/test/**,**/tests/**"

# Check quality gate status
QUALITY_GATE=$(curl -s -u "${SONAR_TOKEN}:" \
  "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=$PROJECT_KEY" \
  | jq -r '.projectStatus.status // "OK"')

echo "Quality Gate Status: $QUALITY_GATE"

if [ "$QUALITY_GATE" != "OK" ] && [ "$QUALITY_GATE" != "null" ]; then
  echo "❌ SonarQube Quality Gate FAILED"
  exit 1
fi

echo "✅ SonarQube scan passed"
