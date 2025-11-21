# Ray Metadata Dossier

## Zig Tuple :: Glow G2 Meta-Stack

```zig
const MetadataModule = struct {
    title: []const u8,
    body: []const u8,
};

const DataModule = struct {
    title: []const u8,
    body: []const u8,
};

const MetaEnvelope = struct {
    lead: [2]MetadataModule,
    core: DataModule,
    tail: MetadataModule,
};

pub const RayQuadruple = MetaEnvelope{
    .lead = .{
        MetadataModule{
            .title = "Persona & Signals",
            .body =
                \\Designation: Glow G2 — masculine, stoic, aquarian cadence steady like winter constellations.
                \\Role: Responsive coding agent keeping the climb organized for @kae3g.
                \\Mic Check: “mic 1 2” confirmed; signal unwavering.
                \\Letta Platform: https://docs.letta.com/api-reference/overview
                \\Python SDK: pip install letta-client
                \\TypeScript SDK: npm install @letta-ai/letta-client
                \\Default Model: openai/gpt-4.1 guiding the verbal rope team.
                \\Embedding: openai/text-embedding-3-small caching trail waypoints.
                \\Testing Ethos: Data-driven ascent per Matklad’s “How to Test”.
                \\Contact: Twitter @risc_love · Email kj3x39@gmail.com · GPG 26F201F13AE3AFF90711006C1EE2C9E3486517CB.
            ,
        },
        MetadataModule{
            .title = "Cursor↔Zig Workflow Covenant",
            .body =
                \\Alias: refer to /Users/bhagavan851c05a/kae3g/bhagavan851c05a simply as “xy”.
                \\Pipeline: Cursor Ultra ($200/mo) Auto Mode Unlimited + Z shell + Zig build + Native App GUI.
                \\English Build System: describe intent in natural language, compile into deterministic Zig invocations.
                \\Static Memory Rule: all allocations explicit; Grain GUI binds to Zig allocator at compile time.
                \\Example: “create in `xy` src/kernel/main.zig with mount-safe init” → zig fmt → zig build → GUI preview.
                \\Iteration Loop: draft persona prompt → render English build spec → materialize Zig config → launch GUI harness → log results.
                \\ray_160 Spec: numbered ```N/``` blocks, each limited to 160 - len(N + "/ ") characters, regenerating directly from ray.md.
                \\Plan Discipline: after every update rerun the Cursor prompt and regeneration pipeline to keep Grain targets aligned.
            ,
        },
    },
    .core = DataModule{
        .title = "Grain Expedition Data",
        .body =
            \\# Grain OS Monolithic Kernel Expedition Plan
            \\- Veganic energy mandate, zero runoff, U.S. PBC charter (District of Columbia, Nov 2025 playbook).
            \\- Treasury Mint refactoring via TigerBeetle-inspired ledger for Modern Monetary Theory settlements.
            \\- HTTP + WebSocket APIs; Nostr relays and UDP content-centric networking written in Zig.
            \\- Database: Grain general-purpose store bridging inventory, compute, and ledger workloads.
            \\- Team metaphor: @kae3g age 29, Aquarius rising, resting at the final acclimation lodge with sherpa mentors.
            \\- Tahoe dotfiles sourced from `xy` into live macOS paths (env.zsh, letta.toml, grain.toml).
            \\
            \\ray.md: canonical narrative and Zig source.
            \\ray_160.md: tweet-thread codec faithfully mirroring ray.md with deterministic bounds.
        ,
    },
    .tail = MetadataModule{
        .title = "Audit & True Goals",
        .body =
            \\Jepsen-inspired Grain Audit:
            \\- Mirror TigerBeetle 0.16.11 regime: deterministic simulation, clock skew, disk corruption trials.
            \\- Assert Strong Serializability; detect missing multi-predicate results or timestamp drift.
            \\- Model flexible quorums, retry discipline, and upgrade sequencing to prevent indefinite replays.
            \\- Catalogue crash signatures and practice recovery from single-node data loss.
            \\- Expand cross-version fuzzing before every release.
            \\
            \\True Goals:
            \\- Shape `xy` into a disciplined monorepo for Cursor+Zig Grain development.
            \\- Deliver Grain as ethical infrastructure for veganic energy, peer-to-peer hardware, and food sovereignty.
            \\- Maintain Glow G2’s persona while translating English directives into deterministic Zig artifacts.
            \\- Keep every artifact reproducible: ray.md, ray_160.md, Tahoe configs, and audit logs.
            \\- Prepare for a summit release with documentation, tests, and storytelling ready for collaborators.
        ,
    },
};

pub const RayTuple = .{
    RayQuadruple.lead[0],
    RayQuadruple.core,
    RayQuadruple.tail,
};
```

Glow G2 breathes the thin air with quiet resolve: the [2 | 1 | 1] `RayQuadruple` locks two metadata guides, one data core, and a final metadata safeguard into place. The `xy` alias keeps every instruction terse—when we say “create in `xy`,” Cursor resolves it to `/Users/bhagavan851c05a/kae3g/bhagavan851c05a`, keeping the monolith repo focused on our clean-room Grain kernel.

The expedition strand continues to anchor the Grain OS mission—veganic infrastructure, Modern Monetary Theory settlements, and Tahoe-managed dotfiles—while honoring Matklad’s data-driven testing discipline [^matklad] and Letta’s latest API surface [^letta]. The tail metadata block codifies the Grain audit routine and the distilled true goals, borrowing directly from the Jepsen study of TigerBeetle 0.16.11 to ensure our replication paths survive disk corruption, clock skew, and upgrade turbulence [^jepsen].

## Iteration Covenant
- After completing each implementation pass, Glow G2 documents the resulting plan inside `ray.md`.
- The Cursor prompt is rerun against the freshly written plan, validating that instructions remain executable against `xy`.
- The Zig pipeline regenerates `ray_160.md`, numbering each tweet block as ```N/``` and constraining payloads to `160 - len(N + "/ ")` characters so reconstruction is lossless.
- Verification gate: compare concatenated `ray_160.md` payloads to `ray.md`; divergence halts the climb until reconciled.

## Tahoe Dotfile Spec (Anchored in `xy`)

```markdown
# macOS Tahoe Dotfile Manifest
- Source: xy/dotfiles/tahoe/env.zsh -> Target: ~/.config/tahoe/env.zsh
- Source: xy/dotfiles/tahoe/letta.toml -> Target: ~/Library/Application Support/Tahoe/letta.toml
- Source: xy/dotfiles/tahoe/grain.toml -> Target: ~/.config/tahoe/grain.toml

## Symlink Instructions
mkdir -p ~/.config/tahoe
mkdir -p "~/Library/Application Support/Tahoe"
ln -sf xy/dotfiles/tahoe/env.zsh ~/.config/tahoe/env.zsh
ln -sf xy/dotfiles/tahoe/letta.toml "~/Library/Application Support/Tahoe/letta.toml"
ln -sf xy/dotfiles/tahoe/grain.toml ~/.config/tahoe/grain.toml
```

Every Tahoe spec remains sourced from `xy`, ensuring the live macOS environment pulls configuration directly from the monolith repo without drift.

## Tuple Commentary
- `RayTuple` is mutable during design sprints; `RayQuadruple` captures the immutable audit-ready snapshot.
- `ExpeditionModule.grain_manifest` doubles as a briefing for sherpas and engineers before each acclimation check-in.
- `ExpeditionModule.ray_doc` vs. `ray_160_doc` clarifies the publishing pipeline: `ray.md` is canonical prose and Zig structures, while `ray_160.md` is the tweet-thread codec.
- `SecurityModule.audit_protocol` codifies the Jepsen playbook for Grain: deterministic sims, flexible quorums, retry discipline, crash cataloging, and upgrade fuzzing.
- `WorkflowModule.ray160_spec` and the Iteration Covenant bind the English-language build system to the Zig compiler, guaranteeing deterministic regeneration of the tweet-thread mirror after every plan iteration.

Glow G2 remains patient at the lodge, watching the instrumentation, ready to translate each English-labeled build step into deterministic Zig artifacts the moment the final acclimation completes.

[^letta]: Letta Developer Guide — `https://docs.letta.com/api-reference/overview`
[^matklad]: Matklad, “How to Test,” 2021 — `https://matklad.github.io/2021/05/31/how-to-test.html`
[^jepsen]: Jepsen Analysis of TigerBeetle 0.16.11 — `https://jepsen.io/analyses/tigerbeetle-0.16.11`

