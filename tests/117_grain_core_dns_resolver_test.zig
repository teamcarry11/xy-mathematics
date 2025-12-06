const std = @import("std");
const testing = std.testing;
const dns_resolver = @import("grain_core").dns_resolver;

test "dns resolver init" {
    const resolver = dns_resolver.DnsResolver.init(3600);
    std.debug.assert(resolver.cache_len == 0);
    std.debug.assert(resolver.cache_ttl == 3600);
}

test "dns resolver add cache entry" {
    var resolver = dns_resolver.DnsResolver.init(3600);
    const hostname = "example.com";
    const ip_address = [_]u8{ 93, 184, 216, 34 };
    const added = resolver.add_cache_entry(
        hostname,
        dns_resolver.DnsRecordType.a,
        &ip_address,
        1000,
    );
    std.debug.assert(added);
    std.debug.assert(resolver.cache_len == 1);
}

test "dns resolver find cache entry" {
    var resolver = dns_resolver.DnsResolver.init(3600);
    const hostname = "example.com";
    const ip_address = [_]u8{ 93, 184, 216, 34 };
    _ = resolver.add_cache_entry(
        hostname,
        dns_resolver.DnsRecordType.a,
        &ip_address,
        1000,
    );
    const entry = resolver.find_cache_entry(
        hostname,
        dns_resolver.DnsRecordType.a,
        1500,
    );
    std.debug.assert(entry != null);
    std.debug.assert(entry.?.hostname_len == hostname.len);
    std.debug.assert(entry.?.ip_address_len == ip_address.len);
}

test "dns resolver cache expiration" {
    var resolver = dns_resolver.DnsResolver.init(3600);
    const hostname = "example.com";
    const ip_address = [_]u8{ 93, 184, 216, 34 };
    _ = resolver.add_cache_entry(
        hostname,
        dns_resolver.DnsRecordType.a,
        &ip_address,
        1000,
    );
    const entry = resolver.find_cache_entry(
        hostname,
        dns_resolver.DnsRecordType.a,
        5000,
    );
    std.debug.assert(entry == null);
}

test "dns resolver clear expired cache" {
    var resolver = dns_resolver.DnsResolver.init(3600);
    const hostname = "example.com";
    const ip_address = [_]u8{ 93, 184, 216, 34 };
    _ = resolver.add_cache_entry(
        hostname,
        dns_resolver.DnsRecordType.a,
        &ip_address,
        1000,
    );
    const cleared = resolver.clear_expired_cache(5000);
    std.debug.assert(cleared == 1);
    std.debug.assert(!resolver.cache[0].active);
}

test "dns resolver resolve hostname from cache" {
    var resolver = dns_resolver.DnsResolver.init(3600);
    const hostname = "example.com";
    const ip_address = [_]u8{ 93, 184, 216, 34 };
    _ = resolver.add_cache_entry(
        hostname,
        dns_resolver.DnsRecordType.a,
        &ip_address,
        1000,
    );
    var ip_out: [dns_resolver.MAX_IP_ADDRESS_LEN]u8 = undefined;
    const resolved = resolver.resolve_hostname(
        hostname,
        dns_resolver.DnsRecordType.a,
        1500,
        &ip_out,
    );
    std.debug.assert(resolved);
    var i: u32 = 0;
    while (i < ip_address.len) : (i += 1) {
        std.debug.assert(ip_out[i] == ip_address[i]);
    }
}

