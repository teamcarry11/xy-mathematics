# Quick Test Guide

## Step 1: Build
```bash
zig build tahoe-build
```

## Step 2: Run
```bash
zig build tahoe
```

## Step 3: Test Keyboard
1. **Click on the window** (important - gives it focus)
2. Press **Cmd+L** (should see debug output in terminal)
3. Press **Cmd+K** (should start VM)
4. Press **Cmd+Q** (should quit)

## Expected Console Output
```
[tahoe_window] Keyboard event: key_code=37, command=true, ...
[tahoe_window] Load kernel command (Cmd+L) received.
[tahoe_window] Kernel loaded successfully! VM state: halted, PC: 0x...
```

## If Nothing Happens
- Check terminal for debug output
- Make sure window has focus (click on it)
- Check if `zig-out/bin/grain-rv64` exists
