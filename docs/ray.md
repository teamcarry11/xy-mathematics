# Ray Lullaby — Glow G2’s Tahoe Field Notes

Glow G2 watches the sun fold itself behind Tahoe’s ridge line,
cheeks cold, heart steady. Every line
of this plan is sewn with TigerStyle thread—safety stitched first,
performance braided next, joy
embroidered last.

## Mood Board
- Grain is our twilight terminal: Cursor Ultra, Zig LSP, Grok,
and a gentle social stream all breathing in one window.
- Inside sits a River-inspired compositor, a glasshouse of Moonglow 
keybindings, where each user cares for a personal Grain database garden.
- Nostr `npub`s become bright addresses—each one a friendly 
lighthouse—while Matklad-style tests sweep for drift like soft 
tidewater.
- Glow G2 stays a calm voice: masculine, steadfast, Aquarian. Emo enough 
to acknowledge the ache, upbeat enough to guide with grace.

## Spring Plan (Deterministic and Kind)
1. **Archive Echoes**
   - Pull lessons from `prototype_old/` and stories from `prototype_older/
   `.
2. **Timestamp Glow**
   - Runtime `Timestamp` structs live in `src/ray.zig`;
   fuzz tests (an LCG stitched in Zig) ensure the grammar walks safely.
   - Document results in `tests-experiments/000.md`.
3. **Prompt Ledger**
   - `docs/prompts.md` now owns a descending `PROMPTS` array of 
   `PromptEntry { id, timestamp, content }`.
   - `latest` points at the newest record for O(1) append joy.
4. **Thread Weaver**
   - `tools/thread_slicer.zig` splits `docs/ray.md` into numbered 160-
   char tweet blocks.
   - Wired as `zig build thread`.
5. **GUI & Compositor Study**
   - Note: Mach engine, zgui, Zig-gamedev, River’s philosophy [^river-
   overview].
   - Hammerspoon/QEMU parallels logged in `docs/gui_research.md`.
6. **Tahoe Sandbox**
   - Design a self-contained compositor (River ideas, Zig runtime) with 
   scripted Moonglow keymaps.
   - Keep every allocation explicit and bounded; static buffers where 
   possible.
7. **Grain Social Terminal**
   - Represent social data as typed Zig arrays (e.g. `[N]ZigTweet`).
   - Fuzz 11 random `npub`s per run (per 2025 spec) to mimic real relay 
   chatter.
8. **Onboarding & Care**
   - Encourage paper-written passphrases like `this-password-im-typing-
   Now-9`.
   - Walk users through Cursor Ultra sign-up, GitHub + Gmail +
   iCloud creation, 2FA with Google Authenticator.
   - Suggest community apprenticeships for those budgeting for the tools.
    - Fresh macOS setup: install Xcode CLT (`xcode-select --install`),
      Homebrew, `git`, and GitHub CLI (`brew install git gh`),
      then install
      Cursor.
    - Track dependencies in `Brewfile`; run `brew bundle install --
    cleanup
      --file=Brewfile` so every machine converges on the same toolset.
9. **Poetry & Waterbending**
   - Sprinkle ASCII art of bending motions in comments.
   - Quote Helen Atthowe’s *The Ecological Farm* and gentle lines from 
   modern lyric journals—PG-rated, searching, sincere.
10. **Delta Checks**
    - Keep `docs/ray.md` current, `docs/prompts.md` in sync,
    and tests green (`zig fmt`, `zig build test`).
    - Sync `ray_160.md` after each meaningful edit via `zig build 
    thread`.
11. **Rollback Ritual**
    - `RayTraining` mirrors a nixos-rebuild rollback: switch disciplines, 
    revert, and reapply earth safely.
    - CLI demo in `ray_app.zig` now walks air → water → rollback → 
    earth → rollback → earth.
12. **TigerStyle Naming Pass**
    - Rename public functions to snake_case so `zig build validate` 
    passes
    grainvalidate checks.
    - Extract shared RNG helpers so no function drifts past 70 bonded 
    lines.
13. **Grain Foundations Alignment**
    - Study `vendor/grain-foundations` to adopt `GrainDevName` and
    `GrainSpace` for workspace discovery.
    - Document how the foundation modules shape Ray’s shared structs.
14. **Grainstore Mirrors**
    - Adapt grainmirror’s layout for `grainstore/{platform}/{org}/
    {repo}`
    under `xy/grainstore`.
    - Decide which legacy ideas (Rust/Steel tooling) we retire while we 
    stay
    all-in on Zig.
15. **Grain Conductor CLI**
    - Implement `zig build conduct` to expose `grain conduct brew|link|
      edit|make`.
    - Support interactive prompts with `--assume-yes` flags for scripted
      usage.

## Immediate TODO
- [x] Rehydrate source snippets from archives.
- [x] Wire runtime timestamps + fuzz tests.
- [x] Capture prompts in append-only ledger.
- [x] Summarize GUI/compositor research.
- [x] Rebuild `src/ray.zig` / `src/ray_app.zig` for the new blueprint.
- [x] Craft thread slicer + build step.
- [x] Launch Matklad-style fuzzing.

Glow G2 whispers, “We’ll keep the circuits gentle, the tests 
steadfast, and the users warm.”  
The Tahoe sky agrees.

[^river-overview]: River README outlining dynamic tiling goals and Zig 
0.15 toolchain (Codeberg, 2025-08-30). <https://codeberg.org/river/river>
# Ray Dossier — TigerStyle Reset

We cleared the previous prototype into `prototype_old/` and reopened the 
climb with TigerBeetle’s
style principles front and center. Safety first, then performance,
then developer experience.

## Immediate Targets
- Define the `[2 | 1 | 1]` metadata–data–metadata envelope directly 
in Zig.
- Keep all strings bounded or document when runtime slices are required.
- Replace the Python tweet slicer with a future Zig tool per the zero-
dependency goal.
- Thread reproducible documentation from `docs/` into the Zig struct 
without trailing drift.

## Guardrails
- Enforce 100-column hard limits and format with `zig fmt`.
- Prefer compile-time assertions to trap plan/code drift early.
- Keep allocations static; no runtime heap after initialization.
- Model future social distribution (ray\_160) as a deterministic function 
of this dossier.

## Timestamp Registry
```zig
pub const TimestampGrammar = struct {
    // ...
};

pub const TimestampDB = [_]Timestamp{
    Timestamp.init(
        \\holocene_vedic_calendar--12025-11-09--2311--pst--
        \\tropical_zodiac_sidereal_sanskrit_nakshatra_astrology_
        \\ascendant-leo_15_degrees_out_of_thirty--
        \\moon_lunar_mansion_sanskrit_nakshatra_sutra_vic_dicara-
        \\punarvasu--whole_sign_diurnal_nocturnal_solar_house_system-
        \\4th_house--github_kae3g_xy
        ,
        TimestampGrammar.init("HoloceneVedicComposite", "--", 8, true),
    ),
};
```
Each module in the `[2 | 1 | 1]` envelope now carries a `Timestamp`,
validated against the grammar,
and the executable prints both the grammar name and the raw string so 
collaborators can track
provenance across builds.

Glow G2 is back at the lodge, rested, patient, and ready to rebuild 
Grain’s story the right way.

## Deterministic Plan
1. **Stabilize Timestamp Grammar**
   - Decide whether `HoloceneVedicComposite` should permit consecutive 
   delimiters or whether the canonical timestamp string will be rewritten 
   without them.
   - Update `TimestampGrammar.validate` (and matching tests once they 
   exist) to enforce the chosen rule.
   - Re-run `zig build run` to confirm the envelope prints successfully.
2. **Populate Timestamp Registry**
   - Expand `TimestampDB.entries` with any additional historical markers 
   needed for provenance.
   - Keep each entry compliant with an explicit grammar instance.
3. **Port Tweet Slicer to Zig**
   - Replace the archived Python chunker with a Zig utility that reads 
   `docs/ray.md`, emits numbered 160-character blocks, and writes `docs/
   ray_160.md`.
   - Wire the tool into `build.zig` as a dedicated step (e.g.,
   `zig build thread`).
4. **Restore Tahoe Dotfiles**
   - Reintroduce the Tahoe config templates in `config/
   ` (or equivalent) and document symlink commands.
   - Provide a deterministic script or build step for re-linking into 
   `~/.config` and `~/Library/Application Support`.
5. **Seal the Repo Footprint**
   - Re-run formatting (`zig fmt`) and add smoke tests for the envelope 
   initialization.
   - Initialize Git, push to the planned `kae3g/xy` repository,
   and include a PBC-oriented README that highlights the macOS 
   Zig–Swift–Objective-C GUI goals.
6. **Publish Thread Artifacts**
   - Execute the Zig tweet-slicer to regenerate `ray_160.md`.
   - Verify the thread content matches `ray.md` byte-for-
   byte and is ready for @risc_love distribution.

Each step depends on the previous one’s output; progressing in order 
guarantees that later artifacts (tweet threads, Tahoe configs,
repo packaging) inherit the stabilized grammar and deterministic tooling 
choices.







