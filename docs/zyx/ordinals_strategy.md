# Grainseeds Ordinals Collection Strategy

## Collection Overview

**Name**: Grainseeds  
**Supply**: 10,000 unique ASCII grainseeds  
**Chain**: Bitcoin (Ordinals)  
**Marketplace**: Magic Eden  

## Why This Works

1. **Pure ASCII**: Like Noderocks, fully on-chain text art
2. **Generative**: Deterministic from seed number (1-10000)
3. **Bitcoin Culture Fit**: Retro, minimal, permanent
4. **Rarity System**: Height, lean, leaf count create natural scarcity

## Rarity Traits

| Trait | Values | Rarity |
|-------|--------|--------|
| Height | 5-15 segments | Taller = Rarer |
| Lean | Left/Straight/Right | Straight = Rarest |
| Leaf Count | 0-6 leaves | More = Rarer |
| Special | Perfect Straight + Max Height | Ultra Rare |

## Technical Implementation

### 1. Generation
```bash
# Generate all 10,000 grainseeds
zig build-exe src/grainseed_collection.zig
./grainseed_collection 1 10000
```

### 2. Inscription
- Use Ordinals inscription tools (Gamma, Ordinals Bot)
- Each grainseed = 1 inscription
- Cost: ~$5-20 per inscription (depending on BTC fees)
- Total cost: $50k-200k for full collection

### 3. Launch Strategy

**Phase 1: Genesis Drop (100 seeds)**
- Inscribe seeds #1-100
- Free mint to early supporters
- Build community

**Phase 2: Public Mint (9,900 seeds)**
- Inscribe remaining seeds
- Price: 0.001-0.005 BTC (~$100-500)
- List on Magic Eden

## Revenue Model

**Conservative Estimate**:
- Mint price: 0.002 BTC ($200)
- Supply: 10,000
- Gross: 20 BTC ($2M)
- Inscription costs: ~5 BTC ($500k)
- Net: 15 BTC ($1.5M)

**Royalties**: 5% on secondary sales

## Marketing

1. **Story**: "Code that grows. Grain that lasts."
2. **Aesthetic**: 90s retro, earnest optimism
3. **Community**: Zig developers, Bitcoin maximalists, ASCII art lovers
4. **Meme**: "Plant your grainseed on Bitcoin forever"

## Next Steps

1. Generate sample collection (seeds 1-100)
2. Create preview website
3. Build community on X/Discord
4. Partner with Ordinals inscription service
5. Launch genesis drop
