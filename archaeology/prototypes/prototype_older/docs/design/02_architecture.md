# Grain Documentary Part 2 — Architecture Skyline

This chapter unpacks `src/grain_lattice.zig`, the Djinn-inspired Alpenglow
translation. We map roles (clients, gateways, validators, observers,
anchors) to DAG components, explain virtual voting, and outline security
controls. Contracts from `src/contracts.zig` provide fixed-size envelopes
that keep TigerBank, CDN bundles, and optional ledgers pinned to static
buffers.

Highlights:
- SettlementContracts as the canonical interface.
- Grain Lattice envelope tests driven by `zig build test`.
- Weak-subjectivity checkpoints via GrainVault credentials.
- DM module `src/dm.zig` (X25519 + ChaCha20-Poly1305) ready for GUI
  integration.
- GrainLoop `src/grain_loop.zig` brings TigerBeetle-style io_uring
  discipline to our UDP story without pulling in libuv.
- Graindaemon `src/graindaemon.zig` frames s6-like supervision as a static
  state machine for `xy`.
- Next steps: transport abstraction for TigerBank (debug vs TCP) routed
  through Grain Conductor flags.
