#!/bin/bash
# Generate filename for inter-agent communication file
# Usage: ./tools/generate_agent_filename.sh <descriptive-name>
# Example: ./tools/generate_agent_filename.sh agent-coordination-status

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <descriptive-name>"
    echo "Example: $0 agent-coordination-status"
    exit 1
fi

DESCRIPTIVE_NAME="$1"

# Get current timestamp in format: yyyy-mm-dd--hhmm-ss
TIMESTAMP=$(date +"%Y-%m-%d--%H%M-%S")

# Get next grainorder code
# For now, we'll use a simple approach: find the most recent grainorder in docs/
# and generate the next smaller one
# This is a placeholder - full implementation would use the grainorder library

# Find most recent grainorder code in docs/
LATEST_GRAINORDER=$(find docs/ -name "*.md" -type f | \
    grep -E '^[bchlnpqsxyz]{6}-' | \
    sed 's|.*/\([bchlnpqsxyz]\{6\}\)-.*|\1|' | \
    sort | \
    head -1)

if [ -z "$LATEST_GRAINORDER" ]; then
    # No existing grainorder codes, start with a large one (oldest)
    GRAINORDER="zyxvsq"
else
    # Get next smaller grainorder
    # This would use the grainorder library to call prev()
    # For now, placeholder
    GRAINORDER="bchlnp"
fi

# Generate filename
FILENAME="${GRAINORDER}-${TIMESTAMP}-${DESCRIPTIVE_NAME}.md"

echo "$FILENAME"

