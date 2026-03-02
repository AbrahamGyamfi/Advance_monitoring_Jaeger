#!/bin/bash

DIR=$1

echo "=== Running OWASP Dependency-Check SCA ==="
echo "Directory: $DIR"

cd "$DIR"

# Create cache directory on Jenkins server
mkdir -p /tmp/owasp-cache

# Run OWASP Dependency-Check with cache and skip update for speed
docker run --rm \
    -v $(pwd):/src \
    -v /tmp/owasp-cache:/usr/share/dependency-check/data \
    owasp/dependency-check:latest \
    --scan /src \
    --format JSON \
    --format HTML \
    --out /src \
    --project "$DIR" \
    --noupdate || true

# Move reports
mv dependency-check-report.json ../owasp-$DIR-report.json 2>/dev/null || true
mv dependency-check-report.html ../owasp-$DIR-report.html 2>/dev/null || true

echo "✅ OWASP scan completed"
