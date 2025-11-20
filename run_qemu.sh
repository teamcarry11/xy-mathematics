#!/bin/bash
# Run Grain OS in QEMU

# Ensure kernel is built
zig build kernel-rv64

# Run QEMU
qemu-system-riscv64 \
    -machine virt \
    -bios none \
    -kernel zig-out/bin/grain-rv64 \
    -m 128M \
    -smp 1 \
    -nographic \
    -serial mon:stdio
