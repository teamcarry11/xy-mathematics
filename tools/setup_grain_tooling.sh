#!/bin/bash
# Setup Grain Tooling: grainwrap-100 and grainvalidate-70
# Why: Create forks of grainwrap and grainvalidate with updated limits for Grain Style
# Grain Style: Script follows bash best practices, explicit error handling

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ORG="teamcarry11"
GITHUB_DIR="$HOME/github"
TEAMCARRY_DIR="$GITHUB_DIR/$ORG"
# Get script directory to find monorepo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GRAINSTORE_DIR="$MONOREPO_DIR/grainstore/github/$ORG"

# Source repos (from vendor or external)
GRAINWRAP_SRC="$MONOREPO_DIR/vendor/grainwrap"
GRAINVALIDATE_SRC="$MONOREPO_DIR/vendor/grainvalidate"

echo -e "${GREEN}Setting up Grain Tooling...${NC}"

# Step 1: Create teamcarry11 directory if it doesn't exist
echo -e "${YELLOW}Step 1: Creating teamcarry11 directory...${NC}"
mkdir -p "$TEAMCARRY_DIR"

# Step 2: Copy grainwrap to grainwrap-100
echo -e "${YELLOW}Step 2: Copying grainwrap to grainwrap-100...${NC}"
if [ -d "$GRAINWRAP_SRC" ]; then
    cp -r "$GRAINWRAP_SRC" "$TEAMCARRY_DIR/grainwrap-100"
    cd "$TEAMCARRY_DIR/grainwrap-100"
    
    # Update to 100-char limit (Grain Style)
    # Update max_width in types.zig
    sed -i '' 's/max_width: usize = 73/max_width: usize = 100/g' src/types.zig
    # Update default_config in grainwrap.zig
    sed -i '' 's/.max_width = 73,/.max_width = 100,/g' src/grainwrap.zig
    sed -i '' 's/73 characters is the graincard/100 characters (Grain Style limit)/g' src/grainwrap.zig
    # Update CLI help text
    sed -i '' 's/73-char limit/100-char limit/g' src/cli.zig
    
    # Replace README with Glow G2 voice version
    if [ -f "$MONOREPO_DIR/tools/grainwrap-100-readme.md" ]; then
        cp "$MONOREPO_DIR/tools/grainwrap-100-readme.md" readme.md
    fi
    
    # Initialize git if not already
    if [ ! -d ".git" ]; then
        git init
        git add .
        git commit -m "Initial commit: grainwrap-100 (100-char limit for Grain Style)"
    fi
    
    echo -e "${GREEN}✓ grainwrap-100 created${NC}"
else
    echo -e "${RED}✗ grainwrap source not found at $GRAINWRAP_SRC${NC}"
    exit 1
fi

# Step 3: Copy grainvalidate to grainvalidate-70
echo -e "${YELLOW}Step 3: Copying grainvalidate to grainvalidate-70...${NC}"
if [ -d "$GRAINVALIDATE_SRC" ]; then
    cp -r "$GRAINVALIDATE_SRC" "$TEAMCARRY_DIR/grainvalidate-70"
    cd "$TEAMCARRY_DIR/grainvalidate-70"
    
    # Replace README with Glow G2 voice version
    if [ -f "$MONOREPO_DIR/tools/grainvalidate-70-readme.md" ]; then
        cp "$MONOREPO_DIR/tools/grainvalidate-70-readme.md" readme.md
    fi
    
    # Initialize git if not already
    if [ ! -d ".git" ]; then
        git init
        git add .
        git commit -m "Initial commit: grainvalidate-70 (70-line function limit)"
    fi
    
    echo -e "${GREEN}✓ grainvalidate-70 created${NC}"
else
    echo -e "${RED}✗ grainvalidate source not found at $GRAINVALIDATE_SRC${NC}"
    exit 1
fi

# Step 4: Create GitHub repos using gh CLI
echo -e "${YELLOW}Step 4: Creating GitHub repositories...${NC}"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}✗ GitHub CLI (gh) not found. Please install it first.${NC}"
    echo -e "${YELLOW}Install: brew install gh${NC}"
    exit 1
fi

# Create grainwrap-100 repo
cd "$TEAMCARRY_DIR/grainwrap-100"
if ! gh repo view "$ORG/grainwrap-100" &> /dev/null; then
    echo -e "${YELLOW}Creating GitHub repo: $ORG/grainwrap-100...${NC}"
    gh repo create "$ORG/grainwrap-100" --public --source=. --remote=origin --push
    echo -e "${GREEN}✓ grainwrap-100 repo created${NC}"
else
    echo -e "${YELLOW}Repo $ORG/grainwrap-100 already exists, skipping...${NC}"
    git remote add origin "https://github.com/$ORG/grainwrap-100.git" 2>/dev/null || true
    git branch -M main 2>/dev/null || true
    git push -u origin main 2>/dev/null || true
fi

# Create grainvalidate-70 repo
cd "$TEAMCARRY_DIR/grainvalidate-70"
if ! gh repo view "$ORG/grainvalidate-70" &> /dev/null; then
    echo -e "${YELLOW}Creating GitHub repo: $ORG/grainvalidate-70...${NC}"
    gh repo create "$ORG/grainvalidate-70" --public --source=. --remote=origin --push
    echo -e "${GREEN}✓ grainvalidate-70 repo created${NC}"
else
    echo -e "${YELLOW}Repo $ORG/grainvalidate-70 already exists, skipping...${NC}"
    git remote add origin "https://github.com/$ORG/grainvalidate-70.git" 2>/dev/null || true
    git branch -M main 2>/dev/null || true
    git push -u origin main 2>/dev/null || true
fi

# Step 5: Grainmirror into monorepo
echo -e "${YELLOW}Step 5: Mirroring into monorepo grainstore...${NC}"
cd "$MONOREPO_DIR"

# Create grainstore directory structure
mkdir -p "$GRAINSTORE_DIR"

# Mirror grainwrap-100
if [ ! -d "$GRAINSTORE_DIR/grainwrap-100" ]; then
    echo -e "${YELLOW}Mirroring grainwrap-100...${NC}"
    git clone "https://github.com/$ORG/grainwrap-100.git" "$GRAINSTORE_DIR/grainwrap-100"
    echo -e "${GREEN}✓ grainwrap-100 mirrored${NC}"
else
    echo -e "${YELLOW}grainwrap-100 already mirrored, updating...${NC}"
    cd "$GRAINSTORE_DIR/grainwrap-100"
    git pull origin main || true
fi

# Mirror grainvalidate-70
if [ ! -d "$GRAINSTORE_DIR/grainvalidate-70" ]; then
    echo -e "${YELLOW}Mirroring grainvalidate-70...${NC}"
    git clone "https://github.com/$ORG/grainvalidate-70.git" "$GRAINSTORE_DIR/grainvalidate-70"
    echo -e "${GREEN}✓ grainvalidate-70 mirrored${NC}"
else
    echo -e "${YELLOW}grainvalidate-70 already mirrored, updating...${NC}"
    cd "$GRAINSTORE_DIR/grainvalidate-70"
    git pull origin main || true
fi

echo -e "${GREEN}✓ All tooling setup complete!${NC}"
echo -e "${GREEN}Repositories:${NC}"
echo -e "  - https://github.com/$ORG/grainwrap-100"
echo -e "  - https://github.com/$ORG/grainvalidate-70"
echo -e "${GREEN}Mirrored to:${NC}"
echo -e "  - $GRAINSTORE_DIR/grainwrap-100"
echo -e "  - $GRAINSTORE_DIR/grainvalidate-70"

