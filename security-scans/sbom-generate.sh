#!/bin/bash
set -e

IMAGE=$1
REPORT_FILE=${2:-sbom.json}

echo "📦 Generating SBOM for: $IMAGE"

# Install Syft if not present
if ! command -v syft &> /dev/null; then
    echo "Installing Syft..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
fi

# Generate SBOM
syft $IMAGE -o json > $REPORT_FILE

echo "✅ SBOM generated: $REPORT_FILE"
