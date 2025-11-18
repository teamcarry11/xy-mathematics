#!/bin/bash
# Run test with lldb and capture backtrace

set -e

echo "Building test..."
zig build hello-world-test 2>&1 | grep -E "(test|error)" || true

TEST_BIN=$(find .zig-cache -name "test" -type f -executable 2>/dev/null | head -1)

if [ -z "$TEST_BIN" ]; then
    echo "ERROR: Test binary not found"
    exit 1
fi

echo "Test binary: $TEST_BIN"
echo ""
echo "Running with lldb (capturing backtrace)..."
echo ""

# Create lldb script
cat > /tmp/lldb_script.txt << 'EOF'
settings set target.process.stop-on-sharedlibrary-events false
run
bt
frame select 0
disassemble --pc
quit
EOF

lldb "$TEST_BIN" -s /tmp/lldb_script.txt 2>&1 | head -100

