#!/bin/bash

DIR=$1

echo "=== Running Snyk SCA ==="
echo "Directory: $DIR"

cd "$DIR"

# Run Snyk test via Docker
docker run --rm \
    -e SNYK_TOKEN="${SNYK_TOKEN}" \
    -v $(pwd):/project \
    snyk/snyk:node \
    test --json --file=/project/package.json > ../snyk-$DIR-report.json || true

echo "✅ Snyk scan completed"
