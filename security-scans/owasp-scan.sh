#!/bin/bash
set -e

DIR=$1

echo "=== Running OWASP Dependency-Check SCA ==="
echo "Directory: $DIR"

cd "$DIR"

# Run OWASP Dependency-Check with NVD API key
docker run --rm -v $(pwd):/src -v ~/.m2:/root/.m2 \
    -e NVD_API_KEY="${NVD_API_KEY}" \
    owasp/dependency-check:latest \
    --scan /src \
    --format JSON \
    --format HTML \
    --out /src \
    --project "$DIR" \
    --nvdApiKey "${NVD_API_KEY}" \
    --failOnCVSS 7

# Move reports
mv dependency-check-report.json ../owasp-$DIR-report.json 2>/dev/null || true
mv dependency-check-report.html ../owasp-$DIR-report.html 2>/dev/null || true

echo "✅ OWASP scan completed"
