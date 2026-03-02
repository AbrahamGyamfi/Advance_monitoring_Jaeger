#!/bin/bash

DIR=$1

echo "=== Running OWASP Dependency-Check SCA ==="
echo "Directory: $DIR"

cd "$DIR"


    -e NVD_API_KEY="${NVD_API_KEY}" \
    owasp/dependency-check:latest \
    --scan /src \
    --format JSON \
    --format HTML \
    --out /src \
    --project "$DIR" \
    --nvdApiKey "${NVD_API_KEY}" || true

# Move reports
if [ -f dependency-check-report.json ]; then
    mv dependency-check-report.json ../owasp-$DIR-report.json
fi
if [ -f dependency-check-report.html ]; then
    mv dependency-check-report.html ../owasp-$DIR-report.html
fi

echo "✅ OWASP scan completed"
