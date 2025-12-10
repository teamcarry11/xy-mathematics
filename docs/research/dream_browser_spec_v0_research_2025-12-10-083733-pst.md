# Dream Browser Spec v0 & MVP Plan: Research Deliverable

**Date**: 2025-12-10-083733-pst  
**From**: Grain Research Agent  
**To**: Grain Core Agent (Coordination), Grain Aurora Agent (Implementation)  
**Status**: Research Complete — Ready for Integration

---

## Executive Summary

Comprehensive Dream Browser specification and MVP plan produced by Research Agent. This document outlines a Nostr-first, DNS-compatible addressing and distribution stack with Grain-grade rigor.

**Key Deliverables**:
1. Dream URL Spec v0
2. Resolver Semantics & State Machine
3. DNS/Web Compatibility & Bridge
4. Security/Trust/UX Rules
5. Performance Plan
6. Spam/Abuse Mitigation
7. Evolve DAG (VC layer)
8. Storage Stack (Grain Style, Zig path)
9. Relay (Zig) MVP
10. Bilingual Module
11. Data Models
12. State Machines
13. Risk / Mitigation
14. Implementation Phasing

**Integration Point**: This research output should be integrated into **Grain Aurora Agent's** development plan, as Dream Browser is part of Aurora Agent's scope.

---

## Dream Browser Spec v0 & MVP Plan

### Primary Outcomes (must produce)

1) **Dream URL Spec v0**  

   - Schemes: `dream://` (primary), alias `nostr+dream://`; HTTPS bridge `https://<domain>/.well-known/dream?target=<payload>`.  

   - Payload types (nip-19 aligned): `nprofile`, `nevent`, `naddr`, optional `nrelay`/relay-set; `bundle/<sigil>/<hash|naddr>` for app/media manifests; `evolve/<root-hash>` for DAG heads/branches.  

   - Query params (ignore-unknown): `relays` (ordered, preferred first), `fallbacks`, `archival`, `storage` (`ipfs://cid;bt://infohash;iroh://hash;https://cdn/url`), `lang`, `cache` (`must-verify|max-age|immutable|stale-while-revalidate`), `sandbox` (capabilities), `qos` hints.  

   - Authority/alias: optional `alias@example.com/<payload>`. Resolution via DNS TXT/SRV carrying `{pubkey, relays, optional naddr, optional bundle head}` signed by domain TLS key or DNSSEC; optional on-chain anchor.  

   - Canonicalization: lowercase scheme, normalized relay URLs, deterministic param ordering. Display: checksum microtext for keys; safe truncation rules.  

   - Media type registration: `application/dream+nostr`; handler registration guidance.

2) **Resolver Semantics & State Machine**  

   - Bootstrap order: (a) pinned relays; (b) alias DNS TXT/SRV; (c) embedded defaults; (d) signed well-known list.  

   - Fetch: parallel to multiple relays + storage transports; first verifiable wins; cross-check hashes; fallback retry with backoff.  

   - Verification: nip-19 decode → signature verify; for blobs, verify content hash against signed manifest pointer; enforce declared hash algo.  

   - Mutability: signed manifests (dedicated event kind) point to immutable blobs; include TTL, ETag-like version, content-hash, storage URIs; cache states = fresh/stale/invalid; revalidation rules.  

   - Offline: serve last-verified with freshness badge; queue background revalidate; expose "force refresh".  

   - Sandbox: WASM/app bundles declare permissions (net/relays, storage, fs, sensors); default deny; require user consent for escalations.  

   - Error surfaces: relay unreachable, hash mismatch, signature fail, unknown capability → hard fail; offer alternate relay set.

3) **DNS/Web Compatibility & Bridge**  

   - TXT: `dream=pubkey=<npub>;relays=wss://...;addr=<naddr>;bundle=<naddr>` signed by TLS or DNSSEC.  

   - SRV: `_dream._tcp`, `_dream._ws` for relay bootstrap; priority/weight mapping to preference.  

   - `<link rel="alternate" type="application/dream+nostr" href="dream://...">` for "Open in Dream" from HTTPS.  

   - 302/JS bridge to launch handler; graceful degradation to web app if handler absent.  

   - Domain→pubkey binding UI: show verified badge when TXT/DNSSEC matches signature.

4) **Security/Trust/UX Rules**  

   - Pubkey↔alias pinning with history; mismatch warnings; require explicit trust reset.  

   - Relay reputation: uptime, latency, spam rate, policy flags; client prefers high-score; expose scores.  

   - Anti-phishing: colored trust badges, checksum microtext, confirm when using unpinned relay sets or unsigned alias.  

   - Media safety: size caps, MIME sniff + blocklist, transcoding to safe formats, deferred load for untrusted authors.  

   - Safe-mode defaults: allowlists, mute/blocklists, opt-in for unknown relays/storage; click-to-run for active content.  

   - Permissions UX: granular prompts for sandbox capabilities; remember per-origin policy with expiry.

5) **Performance Plan**  

   - Transport: QUIC/WebSocket with compression; multiplexed subs; partial/delta sync for feeds.  

   - Prefetch: manifests and referenced blobs; hash-dedupe; prioritize visible/next items; speculative fetch with cancellation.  

   - Cache tiers: mem → disk → optional object store; LRU + TTL; shard by content hash.  

   - Parallel fetch: relays + IPFS/Bt/Iroh/HTTPS; first-valid-wins; integrity gating.  

   - Edge: co-locate relay + CDN; serve hot blobs via CDN with client-side hash check; range requests for large media.  

   - Metrics: latency per relay, hit rates, verification failures; adaptive relay selection.

6) **Spam/Abuse Mitigation**  

   - Relay: NIP-42 auth, rate limits per pubkey/IP, PoW/fee gates, moderation hooks, policy tags on events.  

   - Client: block/mute lists, heuristic spam scoring, safe-mode filters, content warnings; relay reputation integration.  

   - Media: thumbnails via trusted transcoders; strip active content unless trusted.

7) **Evolve DAG (VC layer)**  

   - Node: {parents[], manifest-hash, metadata (author, timestamp, branch, message), signatures}.  

   - Manifests: describe immutable blobs (hash, size, MIME, URIs); optional patchsets.  

   - Heads/branches: signed pointers (events) addressable via Dream URLs; include TTL/version.  

   - Merge: CRDT mode for feeds; Git-like patch for artifacts; track provenance; conflict markers.  

   - Visualization: Gource-like timeline; per-commit/branch Dream URLs; diff views for text/media manifests; time-travel playback.  

   - Policy: immutable once published; revocation via signed tombstone with reason; clients respect tombstones unless overridden.

8) **Storage Stack (Grain Style, Zig path)**  

   - Phase 1: FFI to Rust Iroh; bitswap-like exchange; expose Zig API; verify all hashes client-side.  

   - Phase 2: native Zig minimal node: block store, hash-verify pipeline, libp2p-lite transport, UnixFS-ish manifests, optional Bittorrent seeding; pluggable stores (file/S3/mem+disk).  

   - Integrity: content-addressing mandatory; manifests signed; enforce hash algo negotiation.  

   - Concurrency: async I/O; bounded queues; backpressure; deterministic hashing.  

   - Resource caps: per-peer rate limits; disk quotas; GC of unpinned blocks; pin sets persisted.

9) **Relay (Zig) MVP**  

   - Protocol: NIP-01/11/45 compliant; WS/QUIC server.  

   - Storage: append-only log + indices by pubkey/kind/tag/time; optional inverted index for tags; compaction policy.  

   - Modes: archival vs ephemeral; retention windows; export/import snapshots.  

   - Controls: per-connection limits (subs, msgs/sec, bytes/sec); auth (optional NIP-42); PoW/fee gates; spam hooks.  

   - Observability: metrics (latency, errors, spam hits, store size); logs structured; reputation export feed.

10) **Bilingual Module**  

    - Names: `TwinTongue`, `DualVoice`, `Bilingo`, `DosLenguas`.  

    - Pipeline: LID → local MT (Marian/NLLB distilled) → fallback Google Translate API (paid, REST) when quality/offline issues.  

    - Features: cache translations; glossary for policy terms/names; tone presets (campaign voice); per-space language toggle; "translated from <lang>" badge; view-original toggle; user override edits stored as corrections.  

    - Privacy: prefer local when available; minimize data to cloud; redact PII fields per policy.

11) **Data Models (sketch)**  

    - Relay entry: {url, policy, reputation, last_seen, score, tags}.  

    - Manifest: {hash, algo, size, mime, uris[], ttl?, version?, signers[]}.  

    - Cache entry: {hash, state (fresh/stale/invalid), expires_at, last_verified, source_relay}.  

    - Trust pin: {alias, pubkey, relays[], created_at, last_used, verification_source (DNSSEC/TLS/manual)}.  

    - Sandbox policy: {capabilities[], allow_origins[], expiry}.  

    - Evolve commit: {id=hash, parents[], manifest_hash, author_pubkey, branch, ts, msg, sig}.

12) **State Machines (textual)**  

    - Resolver: INIT → BOOTSTRAP → FETCH (parallel) → VERIFY (sig+hash) → CACHE{fresh|stale} → RENDER; errors to RECOVER (retry/backoff) or FAIL (prompt user).  

    - Cache: MISS → FETCH → VERIFY → STORE(fresh); on TTL: STALE → REVALIDATE → {FRESH|INVALID}.  

    - Sandbox permission: REQUEST → PROMPT → {GRANT(temp/persist)|DENY}; audit log entries.

13) **Risk / Mitigation**  

    - Bootstrap friction: provide strong HTTPS bridge + DNS TXT/SRV; ship defaults.  

    - Relay quality variance: reputation scoring, multi-relay parallel fetch.  

    - Latency: co-lo relays/CDN, parallel transports, caching, QUIC.  

    - Spam: PoW/auth/rate limits + client filters; moderation hooks.  

    - Phishing: alias↔pubkey pinning, badges, checksums, warnings on mismatches.  

    - Mutability complexity: signed manifests with TTL/version; clear UI for stale content.  

    - Adoption: keep DNS/web compatibility; easy "Open in Dream" buttons.  

    - Active content risk: sandbox with explicit caps; default deny.

14) **Deliverables to produce now**  

    - v0 spec draft: Dream URLs, resolver rules, alias binding, manifest format, capability model.  

    - MVP plan: phases, deps, risks for relay, resolver SDK (Zig/JS), storage bridge, Evolve prototype.  

    - UX guidelines: trust/safety indicators, language toggle, offline/caching badges, permission prompts.  

    - Risk/mitigation table with owners and test probes.

15) **Implementation Phasing (suggested)**  

    - Phase A (spec + bridge): lock v0 spec; HTTPS bridge; DNS TXT/SRV format; basic resolver SDK (JS) with verification + caching.  

    - Phase B (relay + storage bridge): Zig relay MVP + Rust Iroh FFI bridge; integrity checks; reputation metrics.  

    - Phase C (Evolve alpha): DAG structs, signed commits, manifest heads, basic diff; Dream URL addressing.  

    - Phase D (perf + safety): QUIC, prefetch, cache tuning; sandboxed WASM runner; spam filters; UI trust affordances.  

    - Phase E (bilingual + polish): TwinTongue module, glossary, tone presets; UX refinement; telemetry and tuning.

---

## Constraints / Style

- Grain Style: explicit data structures; no hidden global mutable state; deterministic hashing; verifiable via signatures/hashes; composable modules with clear boundaries; backpressure and quotas explicit.  

- Do not break existing DNS/web; always provide a bridge/fallback.  

- Optimize for security, clarity, latency; keep user mental model simple (alias ↔ pubkey, verified badge, relay set).  

- Output must be concise but technically dense; numbered/structured OK; prefer actionability over prose.

---

## Integration Recommendations

**For Grain Aurora Agent**:
- This Dream Browser spec should be integrated into Aurora Agent's development plan
- Aurora Agent already has Dream Protocol foundation (Phase 0.3 Complete)
- This spec provides the comprehensive roadmap for Dream Browser implementation
- Consider adding new phases to Aurora Agent's plan based on this spec

**For Grain Core Agent**:
- Core Agent may need to provide infrastructure support (DNS resolution, network stack enhancements)
- Core Agent's HTTP Client (Phase 61 Complete) can support HTTPS bridge
- Core Agent's WebSocket support (Phase 61 Complete) can support Dream Protocol
- Core Agent may need to coordinate DNS/network infrastructure for Dream Browser

**For Grain Research Agent**:
- This research deliverable should be documented in Research Agent's plan
- Research Agent can continue to analyze and refine the spec
- Research Agent can track implementation progress against this spec

---

**Status**: Research Complete — Ready for Integration  
**Next Steps**: Integrate into Aurora Agent's plan, coordinate with Core Agent on infrastructure needs

