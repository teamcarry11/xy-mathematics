#!/bin/bash
# Mirror River Compositor for reference (GPL-3.0 - study only, not for direct code use)

set -e

RIVER_VERSION="0.3.12"
RIVER_URL="https://codeberg.org/river/river/releases/download/v${RIVER_VERSION}"
BASE_DIR="grainstore/codeberg/river/river"

echo "Mirroring River Compositor v${RIVER_VERSION} for reference..."
echo "⚠️  Note: River is GPL-3.0 licensed - for study/inspiration only!"

# Create directory structure
mkdir -p "${BASE_DIR}"
cd "${BASE_DIR}"

# Download release tarball and signature
echo "Downloading release tarball..."
wget -q "${RIVER_URL}/river-${RIVER_VERSION}.tar.gz" || curl -L -o "river-${RIVER_VERSION}.tar.gz" "${RIVER_URL}/river-${RIVER_VERSION}.tar.gz"

echo "Downloading signature..."
wget -q "${RIVER_URL}/river-${RIVER_VERSION}.tar.gz.sig" || curl -L -o "river-${RIVER_VERSION}.tar.gz.sig" "${RIVER_URL}/river-${RIVER_VERSION}.tar.gz.sig"

# Extract tarball
echo "Extracting..."
tar -xzf "river-${RIVER_VERSION}.tar.gz"

# Move contents to current directory
if [ -d "river-${RIVER_VERSION}" ]; then
    mv "river-${RIVER_VERSION}"/* .
    rmdir "river-${RIVER_VERSION}"
fi

# Clean up tarball (keep signature for verification)
rm -f "river-${RIVER_VERSION}.tar.gz"

echo "✅ River Compositor mirrored to ${BASE_DIR}"
echo "📝 License: GPL-3.0-or-later (for reference/study only)"
echo "📋 Note: Cannot directly fork code due to GPL license"
echo "💡 Use for architecture inspiration, not direct code copying"

