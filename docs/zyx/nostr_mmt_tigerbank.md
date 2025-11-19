# Nostr MMT TigerBank Specification

Date: 2025-11-10  
Author: Glow G2  

## Overview
TigerBank is a TigerStyle-aligned payment layer that fuses Nostr identities with TigerBeetle's
debit/credit engine and embraces Modern Monetary Theory (MMT). Every user can operate a personal
central bank by minting currencies referenced by a URL-safe label:

```
~{nostr-npub}/{UserGeneratedTitle}
```

Example: `~npub1abcd...xyz/SolsticeCredits`

The label is globally unique, referentially transparent, and can be copied into contracts or QR codes.

## Components
- **Identity**: The Nostr npub anchors the issuer. Verification is handled by existing Nostr relays.
- **Ledger**: TigerBeetle maintains double-entry balances for each currency. Each ledger can expand
  or contract supply instantly under issuer control.
- **Consensus**: A Zig-native smart contract protocol inspired by Solana's Alpenglow [^alpenglow].
  It integrates Rotor-like data dissemination with one/two-round voting for fast finality.

## Zig Payload Structure
When broadcasting currency operations in non-interactive CLI mode, a typed payload is emitted:

```zig
pub const MMTCurrencyPayload = struct {
    npub: [32]u8,
    title: []const u8,
    policy: Policy,
    action: Action,
    pub const max_title_len: usize = 96;
    pub fn encode(self: MMTCurrencyPayload, buffer: []u8) ![]const u8;
};

pub const Policy = struct {
    base_rate_bps: i32,        // interest rate in basis points
    tax_rate_bps: i32,         // percentage for automatic tax collection
};

pub const Action = union(enum) {
    mint: u128,                // increase supply
    burn: u128,                // decrease supply
    loan: LoanTerms,
    collect_tax: u128,
};

pub const LoanTerms = struct {
    principal: u128,
    rate_bps: i32,
    duration_seconds: u64,
};
```

Payloads now encode into stack-local fixed buffers (`max_encoded_len = 192` bytes) to honor
TigerStyle’s single-thread determinism and grainwrap/grainvalidate limits. Titles longer than
96 bytes are rejected at the CLI boundary.

## CLI Workflow
- `grain conduct mmt` (interactive) retains the staged prompts for npub, title, policy, and
  actions. The non-interactive path consolidates to stack buffers:

```
grain conduct mmt \
  --npub=<npub_hex> \
  --title=<name> \
  --mint=1000 \
  --cluster=host:port \
  --relay=wss://node \
  --emit-raw
```

- `--cluster=` and `--relay=` can repeat up to eight entries each; any overflow trips an explicit
  `TooManyClusterEndpoints`/`TooManyRelays` error.
- `--emit-raw` prints the packed bytes without contacting TigerBeetle.
- Without endpoints the stub validates, warns, and returns.
- `grain conduct cdn` mirrors the behaviour for TigerBank CDN bundles:

```
grain conduct cdn \
  --npub=<npub_hex> \
  --tier=premier \
  --start=1700000000 \
  --seats=4 \
  --autopay \
  --cluster=host:port \
  --relay=wss://node
```

- `tigerbank_cdn.zig` defines the 32-byte npub + 12-byte metadata layout (fixed 44 bytes) and
  enforces autopay flags for subscription automation.
- Both commands route through `tigerbank_client.zig`, which still logs deterministic messages until
  the real network plumbing (TigerBeetle RPC / Nostr POST) is grafted in.
- Shared codecs now live in `src/contracts.zig`; both CLI paths alias
  `SettlementContracts` so optional inventory/sales/payroll ledgers can
  reuse the same buffers.
- Architecture overview recorded in `src/grain_lattice.zig` for tests and
  documentation introspection.
- Encryption: `src/grainvault.zig` provides Cursor/Claude API keys—the same
  secrets sign and encrypt settlement envelopes before they leave Ghostty.

## AI & CLI Automation
- `grain conduct ai` loads API secrets from `grainvault.zig` (mirrored from
  `{teamtreasure02}/grainvault`) via the `CURSOR_API_TOKEN` and `CLAUDE_CODE_API_TOKEN` environment
  variables, then spawns either Cursor CLI or Claude Code with static argument lists.
- Secrets are never embedded in the repo; the stub exits with `MissingSecret` if the environment
  has not been initialised.

## Consensus Sketch
- Implement Rotor-style dissemination: each validator relays erasure-coded payload slices.
- Voting:
  - Round-one: requires 80% stake for 150 ms finality.
  - Round-two: fallback 60% stake for resilience (20% adversarial + 20% offline tolerated).
- TigerBeetle cluster ingests finalized blocks.
- Validator scheduling follows stake-weighted rotation analogous to Alpenglow's leader schedule.

## Tax & Interest
- Taxes collected automatically into issuer reserve accounts.
- Loan repayment schedules enforced by TigerBeetle tasks; overdue accounts trigger automatic rate
  hikes as defined in policy.

## Future Work
- Integrate with GUI TahoeSandbox for visual dashboards.
- Extend CLI to broadcast to multiple relays simultaneously.
- Formal verification of interest/tax smart contracts.
- Wire TigerBank CDN bundles into the Grain Pottery abstraction so CDN “kilns” can be scheduled
  alongside currency issuance tasks.

[^alpenglow]: Quentin Kniep, Kobi Sliwinski, Roger Wattenhofer, “Alpenglow: A New Consensus for Solana,” Anza Technology Blog, 19 May 2025. <https://www.anza.xyz/blog/alpenglow-a-new-consensus-for-solana>

