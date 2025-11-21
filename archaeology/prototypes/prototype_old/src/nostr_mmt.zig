const std = @import("std");
const Contracts = @import("contracts.zig").SettlementContracts;

pub const MMTCurrencyPayload = Contracts.TigerBankMMT;
pub const Policy = Contracts.Policy;
pub const Action = Contracts.Action;
pub const LoanTerms = Contracts.LoanTerms;

pub const max_encoded_len = Contracts.TigerBankMMT.max_encoded_len;

test "MMT payload serialization" {
    var payload = MMTCurrencyPayload{
        .npub = [_]u8{0} ** 32,
        .title = "SolsticeCredits",
        .policy = .{ .base_rate_bps = 150, .tax_rate_bps = 200 },
        .action = .{ .mint = 1_000_000 },
    };
    var buffer: [max_encoded_len]u8 = undefined;
    const slice = try payload.encode(&buffer);
    try std.testing.expect(slice.len > 0);
    try std.testing.expect(slice[32] == payload.title.len % 256);
}
