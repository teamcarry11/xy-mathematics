# Grain Documentary Part 6 — GrainVault & Encryption

We explain `src/grainvault.zig`: secrets live outside the repo, fetched
from the mirrored `{teamtreasure02}/grainvault`. Cursor and Claude CLI
commands derive arguments via the vault, ensuring every automation step
is encrypted. The documentary teaches best practices for key rotation,
MPC-capable validator keys, and layering encryption when streaming
settlement envelopes across Nostr relays.

Key moves:
- Export secrets per session; never commit them.
- Use HSM or secure enclaves for validator signing contexts.
- Anchor vault checksums inside Grain Lattice checkpoints.
