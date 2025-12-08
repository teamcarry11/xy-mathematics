const std = @import("std");
const Contracts = @import("contracts.zig").SettlementContracts;

/// Grain Lattice — Dag-based settlement architecture distilled from Djinn.
/// Static data only; perfect for tests, docs, and CLI introspection.
pub const GrainLattice = struct {
    pub const codename = "Grain Lattice";
    pub const author = "Djinn";

    pub const goals = [_][]const u8{
        "Deterministic finality in seconds.",
        "Small, stake-weighted validator set; open submission for clients.",
        "High throughput with parallel ingestion (DAG, not blocks).",
        "Strong resilience to Sybil/spam, eclipses, adaptive corruption.",
        "Verifiable ordering proofs for light clients.",
    };

    pub const non_goals = [_][]const u8{
        "General compute privacy (MPC/ZK) — layer later.",
        "Unlimited hot-history retention — prune after checkpoints.",
    };

    pub const assumptions = struct {
        pub const validator_threshold =
            "≥2/3 stake-weighted validators honest per epoch.";
        pub const adversary =
            "Millions of Sybils, eclipses/DoS, partial stake, latency games.";
        pub const network = "Eventually synchronous; tolerate short partitions.";
        pub const keys =
            "Validators: HSM/MPC friendly; Clients: ECDSA/EdDSA.";
    };

    pub const roles = [_][]const u8{
        "Clients submit transactions (and may verify lightly).",
        "Gateways rate-limit, account fees, shield validators.",
        "Validators create DAG events, run virtual voting, finalize order.",
        "Observers replicate DAG for analytics/indexing.",
        "Anchors checkpoint roots onto external chains/time services.",
    };

    pub const components = struct {
        pub const networking = "QUIC/TCP gossip, multi-path, signed envelopes.";
        pub const event_builder = "Bundles tx → event_id, parents[2..k], sig.";
        pub const dag_store = "Content-addressed, bounded depth, erasure-coded.";
        pub const virtual_voting = "Rounds, witnesses, fame, deterministic order.";
        pub const finality =
            "Emit finalized batches + checkpoints anchored externally.";
        pub const stake_epoch =
            "Registry, VRF rotation, unbonding, slashing rules.";
        pub const evidence = "Equivocation detection → gossip → penalty.";
        pub const anti_spam = "Fees, quotas, surge pricing, orphan decay.";
        pub const data_availability = "N-of-K replication, pruning, archives.";
        pub const light_interface =
            "Checkpoint+signature verification, inclusion proofs.";
        pub const observability =
            "Fanout metrics, latency, DA %, slashing alarms, tracing.";
    };

    pub const data_structures = struct {
        pub const Transaction = Contracts.OptionalModules.ProofOfSales;
        pub const event_shape = "event_id, creator_id, parents[2..k], tx_root, sig.";
        pub const checkpoint_shape =
            "epoch, ordered_root, dag_digest, validator_set_hash, agg_sig.";
    };

    pub const parameters = struct {
        pub const gossip_fanout = "8-12 peers/event.";
        pub const parents_per_event = "k = 2-4 parents.";
        pub const event_size = "64-256 KiB cap.";
        pub const epoch_length = "10-30 minutes (VRF rotation).";
        pub const finality_p95 = "< 5 seconds target.";
        pub const checkpoint_cadence = "Every 60 s or 10k tx.";
        pub const da_replication = "K=12, N=7.";
        pub const admission = "200 tx/s burst per key, refill 20 tx/s.";
    };

    pub const interface = struct {
        pub const client_rpc = [_][]const u8{
            "SubmitTx(tx) → TxAccepted(tx_id)",
            "GetFinality(tx_id) → status {pending|final, batch_id, pos}",
            "GetProof(tx_id) → {checkpoint_hdr, agg_sig, inclusion_path, order}",
        };
        pub const validator_p2p = [_][]const u8{
            "Gossip(Event)",
            "GetParents(missing_ids)",
            "Gossip(Evidence)",
            "GetCheckpoint(epoch)",
        };
        pub const ops = [_][]const u8{
            "Prom metrics for fanout, delays, finality, DA coverage.",
            "Tracing hooks (OpenTelemetry), health beacons, circuit breakers.",
        };
    };

    pub const security_controls = [_]SecurityControl{
        .{ .risk = "Equivocation", .control = "Evidence & Slashing; Event Builder" },
        .{ .risk = "Sybil/Spam", .control = "Fees & Rate-Limits; Gateways" },
        .{ .risk = "Eclipse/Partition", .control = "Networking; Epoch Manager" },
        .{ .risk = "Adaptive corruption", .control = "Epoch Manager; Keys" },
        .{ .risk = "Timestamp/order games", .control = "Virtual Voting Engine" },
        .{ .risk = "Data availability", .control = "DA & Pruning; Finality" },
        .{ .risk = "Long-range attacks", .control = "Finality & Anchors" },
        .{ .risk = "DoS on council", .control = "Networking QoS; Anycast" },
        .{ .risk = "Randomness grinding", .control = "Epoch Manager" },
    };

    pub const slo = struct {
        pub const ordering = "No post-checkpoint forks for finalized tx.";
        pub const latency = "Finality p95 < 5 s, p99 < 10 s.";
        pub const availability = "≥99.9% finalized output per month.";
        pub const da = "≥99.99% reconstructability for last N rounds.";
    };

    pub fn summarize(writer: anytype) !void {
        try writer.print("{s} — goals ({d}):\n", .{ codename, goals.len });
        for (goals) |goal| try writer.print("  - {s}\n", .{goal});
        try writer.print("Components snapshot:\n", .{});
        try writer.print("  Networking: {s}\n", .{components.networking});
        try writer.print("  Voting: {s}\n", .{components.virtual_voting});
        try writer.print("  Finality: {s}\n", .{components.finality});
    }

    pub fn settlementEnvelope(envelope: Contracts.Envelope, buffer: []u8) ![]const u8 {
        return envelope.encode(buffer);
    }
};

pub const SecurityControl = struct {
    risk: []const u8,
    control: []const u8,
};

test "grain lattice summarize prints goals" {
    var backing: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&backing);
    try GrainLattice.summarize(stream.writer());
    const written = stream.getWritten();
    try std.testing.expect(written.len > 0);
}

test "settlement envelope encodes CDN payload" {
    const payload = Contracts.TigerBankCDN{
        .tier = .pro,
        .subscriber_npub = [_]u8{0} ** 32,
        .start_timestamp_seconds = 1700000000,
        .seats = 3,
        .autopay_enabled = true,
    };
    const envelope = Contracts.Envelope{ .tigerbank_cdn = payload };
    var buffer: [Contracts.kind_tag_len + Contracts.TigerBankCDN.encoded_len]u8 = undefined;
    const slice = try GrainLattice.settlementEnvelope(envelope, &buffer);
    try std.testing.expect(slice.len == Contracts.kind_tag_len + Contracts.TigerBankCDN.encoded_len);
    try std.testing.expect(slice[0] == @intFromEnum(Contracts.Kind.tigerbank_cdn));
}


