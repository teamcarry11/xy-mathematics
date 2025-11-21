const std = @import("std");
const Contracts = @import("contracts.zig").SettlementContracts;

pub const Tier = Contracts.Tier;
pub const TierConfig = Contracts.TierConfig;
pub const Catalog = Contracts.TierCatalog;
pub const SubscriptionRequest = Contracts.TigerBankCDN;
pub const BundleManifest = struct {
    pub const bundles = [_][]const u8{
        "cdn/basic",
        "cdn/pro",
        "cdn/premier",
        "cdn/ultra",
    };
};

test "subscription encode length is stable" {
    var buffer: [SubscriptionRequest.encoded_len]u8 = undefined;
    var request = SubscriptionRequest{
        .tier = .pro,
        .subscriber_npub = [_]u8{0xaa} ** 32,
        .start_timestamp_seconds = 1699999999,
        .seats = 2,
        .autopay_enabled = true,
    };
    const slice = try request.encode(&buffer);
    try std.testing.expect(slice.len == SubscriptionRequest.encoded_len);
    try std.testing.expect(slice[32] == @intFromEnum(Tier.pro));
    try std.testing.expect(slice[SubscriptionRequest.encoded_len - 1] == 1);
}
