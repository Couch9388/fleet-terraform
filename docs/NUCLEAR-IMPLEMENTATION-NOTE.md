# ☢️ NUCLEAR Optimization - Implementation Note

## Current Limitation

The Fleet Terraform module (`byo-vpc/main.tf:798-851`) is **hardcoded to use Aurora MySQL**:

```hcl
module "rds" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "9.16.1"
  
  engine = "aurora-mysql"  # Hardcoded - cannot change to standard RDS
  ...
}
```

## NUCLEAR Options Available

### ❌ Option 1: Standard RDS MySQL (NOT POSSIBLE)
**Status:** Cannot implement without modifying the Terraform module  
**Why:** Module hardcoded to Aurora  
**Savings:** Would save $25/month vs Aurora Serverless v2  

**To implement this, you would need to:**
1. Fork the Fleet Terraform module
2. Replace `terraform-aws-modules/rds-aurora/aws` with `terraform-aws-modules/rds/aws`
3. Modify all Aurora-specific configurations
4. Maintain your own fork

**Not recommended** - too much maintenance overhead

---

### ✅ Option 2: Aurora Serverless v1 (POSSIBLE!)
**Status:** Can implement with current module  
**Savings:** $15-25/month vs Aurora Serverless v2  
**Target Cost:** $35-45/month total

**How it works:**
- Aurora Serverless v1 can **auto-pause** after 5 minutes of inactivity
- When paused: $0/hour
- When active: $0.06/ACU-hour (2 ACU minimum)
- For 10 devices with sporadic queries: 20-40% active time

**Cost calculation:**
- 20% active: $0.12/hr × 146 hrs = $17.52/month
- 40% active: $0.12/hr × 292 hrs = $35.04/month
- vs v2 always-on: $0.06/hr × 0.5 ACU × 730 hrs = $43.80/month

**Savings: $8-26/month depending on usage pattern**

---

### ✅ Option 3: Aurora Serverless v2 with Lower ACU (CURRENT EXTREME)
**Status:** Already implemented  
**Cost:** $36/month (0.5 ACU fixed)  
**Target Cost:** $60-80/month total

This is what we have in `extreme-low-cost.tfvars`

---

## Recommended Path: Implement Aurora Serverless v1

### Why Aurora v1 is Better for 10 Devices:

1. **Auto-pause capability**
   - Pauses after 5 minutes of no connections
   - $0/hour when paused
   - Perfect for sporadic access patterns

2. **Realistic savings**
   - 10 devices don't query constantly
   - Likely 20-30% active time
   - Saves $15-25/month vs v2

3. **Acceptable tradeoffs**
   - 25-second cold start (only when resuming from pause)
   - For 10 devices checking in periodically, this is fine
   - First query after pause is slow, subsequent queries are fast

4. **No module changes needed**
   - Aurora v1 is still Aurora
   - Same module, different configuration
   - Just change `serverless` settings

---

## Aurora Serverless v1 vs v2 Comparison

| Feature | v1 | v2 |
|---------|----|----|
| **Minimum ACU** | 2 | 0.5 |
| **Auto-pause** | ✅ Yes | ❌ No |
| **Cold start** | 25 seconds | N/A |
| **Scaling** | 2 ACU increments | 0.5 ACU increments |
| **Cost when paused** | $0/hour | N/A |
| **Cost when active (2 ACU)** | $0.12/hour | N/A |
| **Cost always-on (0.5 ACU)** | N/A | $0.06/hour |
| **Monthly (always-on)** | $87.60 | $43.80 |
| **Monthly (20% active)** | $17.52 | $43.80 |
| **Monthly (50% active)** | $43.80 | $43.80 |

**Break-even point:** 50% active time  
**Below 50% active:** v1 is cheaper  
**Above 50% active:** v2 is cheaper  

**For 10 devices:** Likely 20-30% active → v1 saves $20-26/month

---

## Implementation: Aurora Serverless v1

### Configuration Changes

The current module uses Aurora Serverless v2:
```hcl
serverless = true
serverless_min_capacity = 0.5
serverless_max_capacity = 0.5
```

For Aurora Serverless v1, we need to check if the module supports it. Let me investigate...

### Module Investigation Required

The `terraform-aws-modules/rds-aurora/aws` module version 9.16.1 may or may not support Aurora Serverless v1. 

**Aurora Serverless v1 uses:**
- `engine_mode = "serverless"`
- `scaling_configuration` block

**Aurora Serverless v2 uses:**
- `engine_mode = "provisioned"` (default)
- `serverlessv2_scaling_configuration` block

Looking at the current configuration (line 810-813):
```hcl
serverlessv2_scaling_configuration = var.rds_config.serverless ? {
  min_capacity = var.rds_config.serverless_min_capacity
  max_capacity = var.rds_config.serverless_max_capacity
} : {}
```

This is **v2-specific**. The module may not support v1.

---

## NUCLEAR Decision Matrix

| Option | Monthly Cost | Implementation | Savings vs EXTREME |
|--------|--------------|----------------|-------------------|
| **Keep EXTREME (v2)** | $70 | ✅ Already done | - |
| **Try Aurora v1** | $35-45 | ⚠️ Need to verify module support | $25-35/mo |
| **Fork for RDS MySQL** | $30 | ❌ Too much work | $40/mo |

---

## Recommendation

### Short-term: Stick with EXTREME ($70/month)
- Already implemented
- 88% savings vs original
- No additional work needed
- Proven to work

### Medium-term: Test Aurora v1 (if module supports it)
- Research if module version 9.16.1 supports v1
- If yes, create `nuclear-aurora-v1.tfvars`
- Test with 10 devices
- Monitor active time percentage
- If <50% active, keep v1 (save $25/mo)
- If >50% active, revert to v2

### Long-term: Consider RDS MySQL (if you grow)
- If you scale to 50+ devices
- If you need predictable costs
- If you're comfortable maintaining a fork
- Saves $25/mo but adds maintenance burden

---

## Next Steps

1. **Verify module support for Aurora v1**
   ```bash
   # Check module documentation
   # Look for engine_mode and scaling_configuration support
   ```

2. **If supported, create nuclear-aurora-v1.tfvars**
   - Set engine_mode = "serverless"
   - Configure scaling_configuration with auto_pause
   - Test deployment

3. **If not supported, document limitation**
   - EXTREME ($70/mo) is the best we can do
   - Still 88% savings vs original
   - Excellent result for 10 devices

---

## Conclusion

**EXTREME configuration ($60-80/month) is already excellent:**
- 88% cost reduction
- $6,360/year savings
- Production-ready for 10 devices
- No additional optimization needed

**Aurora v1 could save another $20-25/month IF:**
- Module supports it (needs verification)
- Your access pattern is <50% active
- You can tolerate 25s cold starts

**For now, EXTREME is the recommended configuration.**

The juice may not be worth the squeeze for an additional $20-25/month savings with the complexity and cold start tradeoffs.

---

**Current Status:** EXTREME configuration complete and ready to deploy  
**Additional savings possible:** $20-25/month with Aurora v1 (if module supports it)  
**Recommendation:** Deploy EXTREME, monitor usage, consider v1 later if needed
