# Grain OS Library Recommendations

> Libraries to fork/mirror for Grain OS Wayland compositor development

## ⚠️ License Considerations

**Critical**: All libraries must have **permissive licenses** (MIT, Apache 2.0, BSD, ISC) for direct forking. GPL-licensed code can be studied for inspiration but cannot be directly forked into our codebase.

## 🎯 Primary Recommendations

### 1. River Compositor (Reference Only - GPL-3.0)

**Repository**: https://codeberg.org/river/river  
**Stars**: 598  
**Language**: 92.7% Zig  
**License**: **GPL-3.0-or-later** ⚠️ (NOT permissive - copyleft)  
**Status**: Active, latest release v0.3.12  
**Zig Version**: 0.15  

**Why**: Excellent reference for Wayland compositor architecture in Zig.  
**Action**: Mirror for study/inspiration only - cannot directly fork code due to GPL license.  
**Protocols**: The `protocol/` directory contains ISC-licensed protocols (permissive) that we can reference.

**Mirror Command**:
```bash
# Download release tarball
cd grainstore/codeberg
mkdir -p river/river
cd river/river
wget https://codeberg.org/river/river/releases/download/v0.3.12/river-0.3.12.tar.gz
wget https://codeberg.org/river/river/releases/download/v0.3.12/river-0.3.12.tar.gz.sig
tar -xzf river-0.3.12.tar.gz
mv river-0.3.12/* .
rmdir river-0.3.12
rm river-0.3.12.tar.gz*
```

**Key Features to Study**:
- Wayland protocol implementation
- wlroots integration patterns
- Window management architecture
- Layout generator separation (policy vs. compositor core)
- Runtime configuration via `riverctl`

### 2. Wayland Protocol Libraries

**Status**: ⚠️ **Limited options found** - Zig-native Wayland libraries are rare  
**License Requirement**: MIT/Apache/BSD/ISC  
**Findings**:
- Most Wayland work in Zig uses wlroots (C library) via bindings
- River uses wlroots directly (C library, MIT license)
- No pure Zig Wayland protocol implementations found with permissive licenses

**Recommendation**: 
- **Option A**: Create our own Zig-native Wayland protocol implementation
- **Option B**: Create Zig bindings for wlroots (wlroots is MIT, permissive)
- **Option C**: Study River's protocol handling (GPL-3.0, inspiration only)

### 3. wlroots (C Library - MIT License)

**Repository**: https://gitlab.freedesktop.org/wlroots/wlroots  
**License**: **MIT** ✅ (Permissive)  
**Status**: Active, widely used  
**Language**: C (not Zig)  

**Why**: Industry-standard Wayland compositor library  
**Action**: 
- Can be used directly (MIT license allows it)
- Consider creating Zig bindings for wlroots
- Or study wlroots architecture for our Zig-native implementation

**Note**: Using wlroots would add a C dependency. For zero dependencies, we should implement our own Wayland compositor in pure Zig.

## 📚 Additional Zig Libraries to Consider

### GUI/Windowing Libraries

1. **Mach Engine** (if permissive license)
   - GPU-first framework
   - Window creation, input handling
   - Check license before mirroring

2. **zigimg** (Already in grainstore)
   - Location: `grainstore/github/zigimg/zigimg/`
   - License: MIT ✅
   - Status: Already mirrored

### Protocol/Networking

3. **Wayland Protocol XML Files**
   - Source: wayland-protocols (MIT/X11)
   - Can be mirrored for protocol definitions
   - Generate Zig code from XML

## 🔍 Search Strategy

1. **GitHub/GitLab/Codeberg Search**:
   - Query: `wayland zig language:zig stars:>50`
   - Filter by license: MIT, Apache-2.0, BSD, ISC
   - Check for active maintenance

2. **Awesome Zig Repository**:
   - https://github.com/zigcc/awesome-zig
   - Look for "GUI", "Wayland", "Windowing" sections

3. **Ziglist.org**:
   - https://ziglist.org/top
   - Filter by category and license

## 📋 Mirroring Checklist

For each library to mirror:

- [ ] Verify license is permissive (MIT/Apache/BSD/ISC)
- [ ] Check GitHub stars/activity (prefer >100 stars, recent commits)
- [ ] Verify Zig version compatibility (0.15+)
- [ ] Check dependencies (prefer zero or minimal dependencies)
- [ ] Mirror to appropriate location in `grainstore/`
- [ ] Document in this file with license and status

## 🚫 Libraries to Avoid

- **GPL-licensed code**: Cannot be directly forked (copyleft)
- **LGPL-licensed code**: Generally avoid (some exceptions possible)
- **Unlicensed code**: Avoid (legal uncertainty)

## 📝 Current Status

### Mirrored Libraries

1. **zigimg** ✅
   - Location: `grainstore/github/zigimg/zigimg/`
   - License: MIT
   - Status: Active

2. **grain-tls** ✅
   - Location: `grainstore/github/kae3g/grain-tls/`
   - License: Check LICENSE file
   - Status: Active

### To Mirror

1. **River Compositor** (reference only - GPL-3.0) 📋
   - Location: `grainstore/codeberg/river/river/`
   - Purpose: Study architecture, not direct code use
   - Action: Run `scripts/mirror_river.sh` to mirror
   - License: GPL-3.0-or-later (study/inspiration only)

2. **Wayland Protocol XML** (if needed)
   - Source: wayland-protocols
   - License: MIT/X11 ✅
   - Purpose: Protocol definitions
   - Action: Can mirror if needed for protocol generation

## 🎯 Recommended Approach

Given the limited availability of permissively-licensed Zig Wayland libraries:

1. **Mirror River** for architectural reference (GPL-3.0, study only)
2. **Implement our own** Zig-native Wayland compositor (we've already started!)
3. **Reference Wayland protocol specs** (MIT/X11 licensed)
4. **Study wlroots architecture** (MIT, can reference design patterns)

**Current Implementation**: We're already building a pure Zig Wayland compositor in `src/grain_os/` - this is the right approach for zero dependencies!

## 🔗 Useful Links

- River Compositor: https://codeberg.org/river/river
- River Release v0.3.12: https://codeberg.org/river/river/releases/tag/v0.3.12
- Wayland Protocol: https://wayland.freedesktop.org/
- wlroots: https://gitlab.freedesktop.org/wlroots/wlroots (MIT license)
- Awesome Zig: https://github.com/zigcc/awesome-zig
- Ziglist: https://ziglist.org/top

## 📌 Next Steps

1. **Mirror River** for reference (GPL-3.0, study only)
2. **Search for** Zig-native Wayland protocol libraries
3. **Evaluate** wlroots Zig bindings or create our own
4. **Document** all mirrored libraries with licenses
5. **Implement** our own Wayland compositor inspired by River's architecture

