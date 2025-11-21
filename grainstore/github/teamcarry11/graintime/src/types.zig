//! types: grainbranch data structures
//!
//! What makes up a moment in graintime? Not just calendar date
//! and clock time, but astronomical context that connects our
//! work to cycles larger than ourselves.

const std = @import("std");

// A grainbranch captures temporal and astronomical context.
//
// Think of it as a timestamp with cosmic awareness. When did
// this work happen? Where was the moon? What sign was rising?
// These aren't decorations - they're coordinates in time.
pub const GrainBranch = struct {
    // Gregorian calendar date and time
    year: u16, // holocene calendar (12025 = 2025 CE + 10000)
    month: u8, // 1-12
    day: u8, // 1-31
    hour: u8, // 0-23
    minute: u8, // 0-59
    timezone: []const u8, // "pdt", "utc", etc.
    
    // Astronomical context
    moon_nakshatra: []const u8, // vedic lunar mansion
    asc_sign: []const u8, // rising sign (4 chars)
    asc_degrees: u8, // 0-29 degrees into sign
    sun_house: u8, // 1-12 (sun's position)
    
    // Author attribution
    author: []const u8, // who created this branch
};

// Timezone abbreviations we commonly use.
//
// All lowercase for grain style aesthetic consistency.
pub const Timezone = enum {
    pdt, // pacific daylight time
    pst, // pacific standard time
    utc, // coordinated universal time
    edt, // eastern daylight time
    est, // eastern standard time
};

// The 27 vedic nakshatras (lunar mansions).
//
// Following Mantreshwara's classical tradition from
// Phaladeepika, where Krittika aligns with 0° Aries.
//
// Note: Since Mantreshwara's time, precession has shifted
// the alignment between nakshatras and tropical zodiac.
// This is work in progress - future versions will calculate
// the current alignment more precisely.
//
// Each nakshatra is 13°20' of arc. The moon moves through
// all 27 in approximately 27.3 days.
pub const nakshatras = [_][]const u8{
    "krittika", // 1st - aligned with 0° aries
    "rohini",
    "mrigashira",
    "ardra",
    "punarvasu",
    "pushya",
    "ashlesha",
    "magha",
    "purva_phalguni",
    "uttara_phalguni",
    "hasta",
    "chitra",
    "swati",
    "vishakha",
    "anuradha",
    "jyeshtha",
    "mula",
    "purva_ashadha",
    "uttara_ashadha",
    "shravana",
    "dhanishta",
    "shatabhisha",
    "purva_bhadrapada",
    "uttara_bhadrapada",
    "revati",
    "ashwini",
    "bharani", // 27th - completes the cycle
};

// The 12 zodiac signs (sidereal).
//
// Abbreviated to 4 characters for consistent formatting.
pub const zodiac_signs = [_][]const u8{
    "arie", // aries
    "taur", // taurus
    "gemi", // gemini
    "canc", // cancer
    "leo_", // leo (with underscore for 4 chars)
    "virg", // virgo
    "libr", // libra
    "scor", // scorpio
    "sagi", // sagittarius
    "capr", // capricorn
    "aqua", // aquarius
    "pisc", // pisces
};

// Abbreviate nakshatra names to fit 73-char graincard width.
//
// Why abbreviate? Grainbranch names must fit in 73-character
// graincards (75 chars wide with 1-char borders). The longest
// nakshatras like "uttara_bhadrapada" would push us over.
//
// We remove vowels and keep consonants for recognition while
// maintaining reasonable length. Does this make sense?
pub fn abbreviate_nakshatra(name: []const u8) []const u8 {
    // Short names stay as-is
    if (name.len <= 10) return name;
    
    // Long names get abbreviated
    if (std.mem.eql(u8, name, "purva_phalguni")) return "prvphlgn";
    if (std.mem.eql(u8, name, "uttara_phalguni")) return "utrphlgn";
    if (std.mem.eql(u8, name, "purva_ashadha")) return "prvashd";
    if (std.mem.eql(u8, name, "uttara_ashadha")) return "utrashd";
    if (std.mem.eql(u8, name, "purva_bhadrapada")) return "prvbhdrpd";
    if (std.mem.eql(u8, name, "uttara_bhadrapada")) return "utrbhdrpd";
    
    // Default: return as-is
    return name;
}

