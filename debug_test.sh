#!/bin/bash
# Debug script for Hello World test crash
# Usage: ./debug_test.sh

set -e

echo "Building test with debug symbols..."
zig build hello-world-test 2>&1 | grep -E "(test|error)" || true

echo ""
echo "Finding test binary..."
TEST_BIN=$(find .zig-cache -name "test" -type f -executable 2>/dev/null | head -1)

if [ -z "$TEST_BIN" ]; then
    echo "ERROR: Test binary not found"
    exit 1
fi

echo "Test binary: $TEST_BIN"
echo ""
echo "Running with lldb..."
echo "Commands to run in lldb:"
echo "  (lldb) run"
echo "  (lldb) bt          # Backtrace when it crashes"
echo "  (lldb) frame select 0"
echo "  (lldb) print elf_data.ptr"
echo ""

lldb "$TEST_BIN"

