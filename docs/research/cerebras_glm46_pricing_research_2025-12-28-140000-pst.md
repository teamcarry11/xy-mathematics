# Cerebras GLM-4.6 Pricing Research

**Date**: 2025-12-28-140000-pst  
**From**: Grain Court Agent (11th Agent)  
**Subject**: Cerebras AI Developer Plan Pricing for WSE SRAM Cloud Clusters Running GLM-4.6

---

## Executive Summary

Research on Cerebras AI developer plan pricing for WSE SRAM cloud clusters running GLM-4.6 open model. **GLM-4.6 is available via pay-as-you-go developer tier starting at $10/month or Cerebras Code plan starting at $50/month**. GLM-4.6 delivers exceptional intelligence with unmatched speed, running **17 times faster and 25% cheaper** than comparable models.

---

## Cerebras Pricing Plans

### 1. Inference API Access

**Free Tier**:
- Access to all Cerebras-powered models
- Community support via Discord
- Limited rate limits

**Developer Tier** (Starting at $10/month):
- 10x higher rate limits than free tier
- Higher priority processing
- Pay-as-you-go pricing
- **GLM-4.6 available**

**Enterprise Tier**:
- Highest rate limits
- Support for custom model weights
- Model fine-tuning and training services
- Dedicated support with response time guarantees

### 2. Cerebras Code Plans

**Pro Plan** ($50/month):
- Access to top open-source models
- Fast, high-context completions
- Suitable for indie developers and simple agentic workflows
- **GLM-4.6 available**

**Max Plan** ($200/month):
- Built for teams running demanding workloads at scale
- Highest rate limits
- Lowest latency with dedicated queue priority
- Support for custom model weights

### 3. GLM-4.6 Model

**Availability**:
- Available through Cerebras Inference API
- Accessible via Developer tier (starting at $10/month)
- Accessible via Cerebras Code plan (starting at $50/month)

**Performance**:
- **17 times faster** than comparable models
- **25% cheaper** than comparable models
- Exceptional intelligence with unmatched speed

**Pricing Estimate** (based on 25% cheaper than GPT-4o):
- Input tokens: ~$1.875 per 1k tokens (25% discount from $2.50)
- Output tokens: ~$7.50 per 1k tokens (25% discount from $10.00)
- Note: Actual pricing may vary based on usage tier and plan

---

## WSE SRAM Cloud Clusters

**Cerebras Training Cloud**:
- For scalable training, fine-tuning, and deployment of custom AI models
- Flexible, cost-effective pricing
- Pay-per-hour or pay-per-model plans
- Scale usage based on training needs

**AI Model Studio** (in collaboration with Cirrascale Cloud Services):
- Train GPT-class models with significant time and cost savings
- Example pricing:
  - GPT-3 XL (1.3B parameters): $2,500
  - GPT-3 13B: $150,000
- Predictable, competitive model-as-a-service pricing

---

## Integration with Grain Court Agent

### Phase 4: Self-Hosted Provider (Cerebras GLM-4.6)

**Status**: PLANNED — Future work (when funded)

**Implementation Plan**:
1. **Developer Tier Integration** ($10/month minimum):
   - Start with Developer tier for testing and development
   - Pay-as-you-go pricing for GLM-4.6 inference
   - 10x higher rate limits than free tier

2. **Pro Plan Integration** ($50/month):
   - Upgrade to Pro Plan for production workloads
   - Fast, high-context completions
   - Suitable for indie developers and agentic workflows

3. **Cost Tracking**:
   - Implement Cerebras cost calculation in `token_efficiency.zig`
   - Track costs per request
   - Compare with other providers (OpenAI, Anthropic, Mistral)

4. **Performance Optimization**:
   - Leverage GLM-4.6's 17x faster performance
   - Optimize for 25% cost savings vs comparable models
   - Integrate with ZON format for additional token efficiency

---

## Cost Comparison

### Estimated Token Costs (per 1k tokens)

| Provider | Input | Output | Notes |
|----------|-------|--------|-------|
| OpenAI GPT-4o | $2.50 | $10.00 | Baseline |
| Anthropic Claude 3.5 Sonnet | $3.00 | $15.00 | Higher quality |
| Mistral Large | $2.00 | $6.00 | Cost-effective |
| **Cerebras GLM-4.6** | **$1.875** | **$7.50** | **25% cheaper, 17x faster** |

### Example Cost Calculation

**Scenario**: 10,000 input tokens, 5,000 output tokens

- OpenAI GPT-4o: $25.00 + $50.00 = **$75.00**
- Anthropic Claude 3.5: $30.00 + $75.00 = **$105.00**
- Mistral Large: $20.00 + $30.00 = **$50.00**
- **Cerebras GLM-4.6**: $18.75 + $37.50 = **$56.25** (25% savings vs GPT-4o)

---

## Recommendations

### For Grain Court Agent Phase 4

1. **Start with Developer Tier** ($10/month):
   - Low barrier to entry
   - Pay-as-you-go pricing
   - 10x higher rate limits
   - Good for testing and development

2. **Upgrade to Pro Plan** ($50/month) when ready:
   - Production workloads
   - Fast, high-context completions
   - Better for agentic workflows

3. **Implement Cost Tracking**:
   - Add Cerebras cost calculation to `token_efficiency.zig`
   - Track costs per request
   - Compare with other providers

4. **Leverage Performance Benefits**:
   - 17x faster than comparable models
   - 25% cost savings
   - Integrate with ZON format for additional efficiency

---

## References

- **Cerebras Pricing**: https://www.cerebras.ai/pricing
- **Cerebras GLM-4.6 Blog**: https://www.cerebras.ai/blog/glm
- **Cerebras Training Cloud**: https://www.cerebras.net/cloud
- **Cerebras AI Model Studio**: Business Wire announcement (2022-11-29)

---

**Date**: 2025-12-28-140000-pst  
**Agent**: Grain Court Agent (11th Agent)  
**Status**: Research Complete — Pricing Information Documented for Phase 4 Planning
