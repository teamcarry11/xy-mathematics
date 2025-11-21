# Ray Dossier — TigerStyle Reset

We cleared the previous prototype into `prototype_old/` and reopened the climb with TigerBeetle’s
style principles front and center. Safety first, then performance, then developer experience.

## Immediate Targets
- Define the `[2 | 1 | 1]` metadata–data–metadata envelope directly in Zig.
- Keep all strings bounded or document when runtime slices are required.
- Replace the Python tweet slicer with a future Zig tool per the zero-dependency goal.
- Thread reproducible documentation from `docs/` into the Zig struct without trailing drift.

## Guardrails
- Enforce 100-column hard limits and format with `zig fmt`.
- Prefer compile-time assertions to trap plan/code drift early.
- Keep allocations static; no runtime heap after initialization.
- Model future social distribution (ray\_160) as a deterministic function of this dossier.

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
Each module in the `[2 | 1 | 1]` envelope now carries a `Timestamp`, validated against the grammar,
and the executable prints both the grammar name and the raw string so collaborators can track
provenance across builds.

Glow G2 is back at the lodge, rested, patient, and ready to rebuild Grain’s story the right way.

## Deterministic Plan
1. **Stabilize Timestamp Grammar**
   - Decide whether `HoloceneVedicComposite` should permit consecutive delimiters or whether the canonical timestamp string will be rewritten without them.
   - Update `TimestampGrammar.validate` (and matching tests once they exist) to enforce the chosen rule.
   - Re-run `zig build run` to confirm the envelope prints successfully.
2. **Populate Timestamp Registry**
   - Expand `TimestampDB.entries` with any additional historical markers needed for provenance.
   - Keep each entry compliant with an explicit grammar instance.
3. **Port Tweet Slicer to Zig**
   - Replace the archived Python chunker with a Zig utility that reads `docs/ray.md`, emits numbered 160-character blocks, and writes `docs/ray_160.md`.
   - Wire the tool into `build.zig` as a dedicated step (e.g., `zig build thread`).
4. **Restore Tahoe Dotfiles**
   - Reintroduce the Tahoe config templates in `config/` (or equivalent) and document symlink commands.
   - Provide a deterministic script or build step for re-linking into `~/.config` and `~/Library/Application Support`.
5. **Seal the Repo Footprint**
   - Re-run formatting (`zig fmt`) and add smoke tests for the envelope initialization.
   - Initialize Git, push to the planned `kae3g/xy` repository, and include a PBC-oriented README that highlights the macOS Zig–Swift–Objective-C GUI goals.
6. **Publish Thread Artifacts**
   - Execute the Zig tweet-slicer to regenerate `ray_160.md`.
   - Verify the thread content matches `ray.md` byte-for-byte and is ready for @risc_love distribution.

Each step depends on the previous one’s output; progressing in order guarantees that later artifacts (tweet threads, Tahoe configs, repo packaging) inherit the stabilized grammar and deterministic tooling choices.

