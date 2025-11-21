#!/bin/bash
# Mirror tigerbeetle repository into grainstore without .git folder
# Usage: ./tools/mirror_tigerbeetle.sh [source_path]

set -e

SOURCE="${1:-$HOME/github/tigerbeetle/tigerbeetle}"
TARGET="grainstore/github/tigerbeetle/tigerbeetle"

if [ ! -d "$SOURCE" ]; then
    echo "Error: Source directory not found: $SOURCE"
    echo "Usage: $0 [source_path]"
    echo "Or clone it first: git clone https://github.com/tigerbeetle/tigerbeetle $SOURCE"
    exit 1
fi

echo "Mirroring tigerbeetle from $SOURCE to $TARGET..."

# Create target directory
mkdir -p "$TARGET"

# Use rsync to copy everything except .git
rsync -av --exclude='.git' --exclude='.gitignore' "$SOURCE/" "$TARGET/"

echo "Done! Tigerbeetle mirrored to $TARGET (without .git folder)"

