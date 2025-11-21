# Grain Documentary Part 5 — Settlement Contracts

Here we detail `src/contracts.zig`. TigerBank MMT and CDN payloads share
static encoders; optional modules cover inventory, proof-of-sales, and
payroll. The documentary explains how `storeIntLittle()` keeps Zig 0.15
compatible, how `zig build test` guards byte order, and why prompts.md has
a dedicated descending-order test. Readers learn to extend the envelope
with new optional structs while preserving TigerStyle limits.
