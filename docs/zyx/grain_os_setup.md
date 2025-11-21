# Grain OS Setup Guide

> *Note: This document is a work in progress. For questions or to get in touch, please see `contact.md` in the root directory.*

To run Grain OS (Basin Kernel) on macOS, you need the QEMU emulator for RISC-V 64-bit.

## 1. Install QEMU

We recommend using Homebrew to install QEMU:

```bash
brew install qemu
```

Verify the installation:

```bash
qemu-system-riscv64 --version
```

## 2. Running Grain OS

Once QEMU is installed, you can boot the kernel using the provided script:

```bash
./run_qemu.sh
```

Or manually:

```bash
qemu-system-riscv64 \
    -machine virt \
    -bios none \
    -kernel zig-out/bin/grain-rv64 \
    -m 128M \
    -smp 1 \
    -nographic \
    -serial mon:stdio
```

## 3. Expected Output

You should see the Grain OS boot banner:

```
   ______           _          ____  _____
  / ____/________ _(_)___     / __ \/ ___/
 / / __/ ___/ __ `/ / __ \   / / / /\__ \ 
/ /_/ / /  / /_/ / / / / /  / /_/ /___/ / 
\____/_/   \__,_/_/_/ /_/   \____//____/  
                                          
Grain Basin Kernel v0.1.0 (RISC-V64)
Copyright (c) 2025 Team Carry

[kernel] Initializing Basin...
[kernel] Users initialized: 2
[kernel] System ready. Entering trap loop.
```

To exit QEMU, press `Ctrl+A` then `X`.
