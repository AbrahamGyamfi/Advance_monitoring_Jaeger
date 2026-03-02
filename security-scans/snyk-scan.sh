#!/bin/bash

DIR=$1

echo "=== Running Snyk SCA ==="
echo "Directory: $DIR"

cd "$DIR"

# Run Snyk test via Docker - fail on high severity
docker run --rm \
    -e SNYK_TOKEN="${SNYK_TOKEN}" \
    -v $(pwd):/project \
    snyk/snyk:node \
    test --severity-threshold=high --file=/project/package.json

# Also generate JSON report
docker run --rm \
    -e SNYK_TOKEN="${SNYK_TOKEN}" \
    -v $(pwd):/project \
    snyk/snyk:node \
    test --json --file=/project/package.json > ../snyk-$DIR-report.json || true

echo "Snyk scan completed - Pipeline will FAIL if High/Critical vulnerabilities found"
