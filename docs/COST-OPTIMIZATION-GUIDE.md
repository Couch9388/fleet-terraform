# Fleet Terraform Cost Optimization Guide

## 📊 Cost Comparison

| Component | Before | After | Monthly Savings |
|-----------|--------|-------|-----------------|
| **Aurora MySQL** | db.t4g.large (2 instances) | Serverless v2 (0.5-2 ACU) | **$180-220** |
| **Redis/Cache** | 2x cache.t4g.small | 1x cache.t4g.micro (Valkey) | **$30-35** |
| **ECS Fargate** | Multi-task, 50/50 split | 1 task, 70% Spot | **$30-40** |
| **NAT Gateway** | 3 AZs (3 gateways) | 1 AZ (1 gateway) | **$64** |
| **VPC Flow Logs** | Enabled | Disabled | **$10-20** |
| **CloudWatch Logs** | 30-day retention | 5-7 day retention | **$5-10** |
| **Performance Insights** | Enabled | Disabled | **$10-15** |
| **Enhanced Monitoring** | Enabled | Disabled | **$5** |
| **Container Insights** | Enabled | Disabled | **$5-10** |
| **TOTAL SAVINGS** | | | **$339-419/month** |

### 💰 Final Cost Estimate

**Before:** ~$600/month  
**After:** ~$200-220/month  
**Savings:** ~65-70% reduction

---

## 🎯 Optimizations Applied

### 1. **Aurora Serverless v2** (Biggest Savings: ~$180-220/month)
- **Before:** 2x db.t4g.large instances (primary + replica) running 24/7
  - Cost: ~$0.156/hr × 2 = $0.312/hr = $224/month (compute only)
- **After:** Aurora Serverless v2 auto-scaling
  - Min: 0.5 ACU (~$0.06/hr during idle)
  - Max: 2 ACU (~$0.24/hr during peak)
  - Average for 10 devices: ~0.75 ACU = $0.09/hr = $65/month
- **Why it works:** 10 devices = very light query load, serverless scales down automatically

### 2. **Single Availability Zone** (Savings: ~$100+/month)
- **Before:** 3 AZs with cross-AZ traffic and multiple NAT gateways
- **After:** 1 AZ deployment
  - 1 NAT gateway instead of 3 = $64/month saved
  - No cross-AZ data transfer = $30-40/month saved
  - Simpler networking = easier to manage
- **Tradeoff:** No automatic AZ failover (acceptable for 10-device monitoring)

### 3. **Valkey Single Node** (Savings: ~$30-35/month)
- **Before:** 2x cache.t4g.small Redis nodes = $50-60/month
- **After:** 1x cache.t4g.micro Valkey node = $15-20/month
  - Valkey is 20% cheaper than Redis
  - Micro instance sufficient for 10 devices
- **Tradeoff:** No Redis HA (cache rebuild on failure takes 1-2 minutes)

### 4. **Aggressive Fargate Spot** (Savings: ~$30-40/month)
- **Before:** 50% Spot, 50% on-demand, multi-task scaling
- **After:** 70% Spot, 30% on-demand, fixed 1 task
  - Spot pricing: 50-70% discount vs on-demand
  - 1 task sufficient for 10 devices
- **Tradeoff:** Occasional Spot interruptions (1-2 min recovery)

### 5. **Disabled Monitoring Features** (Savings: ~$30-40/month)
- VPC Flow Logs: Disabled (not needed for 10 devices)
- Performance Insights: Disabled (basic CloudWatch metrics sufficient)
- Enhanced Monitoring: Disabled (1-minute metrics not needed)
- Container Insights: Disabled (basic ECS metrics sufficient)
- Log retention: 5-7 days instead of 30 days

### 6. **KMS Encryption** (Cost: +$3/month)
- Enabled for:
  - RDS storage encryption
  - RDS password secrets
  - Redis at-rest encryption
  - Fleet server private key
  - Software installers S3 bucket
- **3 KMS keys × $1/month = $3/month**

---

## 📋 Detailed Monthly Cost Breakdown (After Optimization)

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| **Aurora Serverless v2** | 0.5-2 ACU, avg 0.75 ACU | $50-80 |
| **Aurora Storage** | ~50GB @ $0.10/GB | $5 |
| **Aurora I/O** | Light workload | $3-5 |
| **Aurora Backups** | 7 days, ~50GB | $5 |
| **ElastiCache (Valkey)** | 1x cache.t4g.micro | $12-15 |
| **ECS Fargate** | 1 task, 0.5 vCPU, 2GB, 70% Spot | $20-30 |
| **ALB** | Hourly + minimal LCU | $16-20 |
| **NAT Gateway** | 1 gateway + data transfer | $32-40 |
| **S3 (Software Installers)** | Minimal storage | $1-3 |
| **KMS Keys** | 3 keys | $3 |
| **CloudWatch Logs** | 5-7 day retention | $2-5 |
| **Data Transfer** | Minimal | $3-5 |
| **TOTAL** | | **$152-211/month** |

**Target Range: $200-220/month** (includes buffer for spikes)

---

## 🚀 Deployment Instructions

### Prerequisites
1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.12.0 installed
3. Valid SSL certificate ARN for ALB HTTPS listener

### Step 1: Backup Current State
```bash
# Backup current Terraform state
terraform state pull > terraform-state-backup-$(date +%Y%m%d).json

# Export current infrastructure (optional)
terraform show > current-infrastructure.txt
```

### Step 2: Review the Optimized Configuration
```bash
# Review the optimized tfvars
cat optimized-low-cost.tfvars

# Compare with current configuration
diff dev.tfvars.example optimized-low-cost.tfvars
```

### Step 3: Plan the Changes
```bash
# Initialize Terraform (if not already done)
terraform init

# Create a plan using the optimized configuration
terraform plan \
  -var-file="optimized-low-cost.tfvars" \
  -var="certificate_arn=arn:aws:acm:us-east-2:ACCOUNT_ID:certificate/CERT_ID" \
  -out=optimization.tfplan

# Review the plan carefully
# Look for:
# - Resources being destroyed (replicas, extra AZs)
# - Resources being modified (Aurora -> Serverless)
# - Cost impact of changes
```

### Step 4: Apply Changes (CAUTION)
```bash
# Apply the optimized configuration
terraform apply optimization.tfplan

# Monitor the deployment
# This will take 15-30 minutes for Aurora Serverless migration
```

### Step 5: Verify Deployment
```bash
# Check Aurora Serverless status
aws rds describe-db-clusters \
  --db-cluster-identifier fleet \
  --query 'DBClusters[0].[Status,ServerlessV2ScalingConfiguration]'

# Check ECS service
aws ecs describe-services \
  --cluster fleet \
  --services fleet \
  --query 'services[0].[status,runningCount,desiredCount]'

# Check ElastiCache
aws elasticache describe-cache-clusters \
  --cache-cluster-id fleet \
  --query 'CacheClusters[0].[CacheClusterStatus,NumCacheNodes]'

# Test Fleet application
curl -k https://YOUR_FLEET_DOMAIN/healthz
```

---

## ⚠️ Important Considerations

### Downtime Expectations
- **Aurora Migration:** 5-10 minutes of database downtime during Serverless conversion
- **Redis Migration:** 1-2 minutes for cache rebuild
- **ECS Tasks:** Rolling deployment, minimal downtime
- **Total Expected Downtime:** 10-15 minutes

### Data Safety
- ✅ Aurora final snapshot created before migration
- ✅ 7-day backup retention maintained
- ✅ All data encrypted with KMS
- ✅ Terraform state backed up

### Performance Impact
- **Query Response Time:** Minimal impact for 10 devices
  - Aurora Serverless scales up in <1 second under load
  - Cache hit ratio remains high with single Redis node
- **Spot Interruptions:** <1% of time, 1-2 minute recovery
- **Cold Start:** First query after idle may take 2-5 seconds (rare)

### Monitoring Recommendations
Even with reduced monitoring, you should still track:
1. **Aurora Serverless ACU usage** - ensure it stays within 0.5-2 ACU range
2. **ECS task health** - monitor task restarts
3. **ALB 5xx errors** - catch application issues
4. **Redis memory usage** - ensure cache isn't full

```bash
# Set up basic CloudWatch alarms (recommended)
aws cloudwatch put-metric-alarm \
  --alarm-name fleet-aurora-high-acu \
  --alarm-description "Alert when Aurora ACU exceeds 1.5" \
  --metric-name ServerlessDatabaseCapacity \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 1.5 \
  --comparison-operator GreaterThanThreshold

aws cloudwatch put-metric-alarm \
  --alarm-name fleet-ecs-task-count \
  --alarm-description "Alert when ECS tasks drop to 0" \
  --metric-name RunningTaskCount \
  --namespace AWS/ECS \
  --statistic Average \
  --period 60 \
  --threshold 1 \
  --comparison-operator LessThanThreshold
```

---

## 🔄 Rollback Plan

If you need to rollback to the previous configuration:

```bash
# Restore from Terraform state backup
terraform state push terraform-state-backup-YYYYMMDD.json

# Or revert to previous configuration
terraform plan -var-file="dev.tfvars.example" -var="certificate_arn=..."
terraform apply
```

---

## 📈 Scaling Guidance

### When to Scale Up

**If you grow beyond 10 devices:**

| Devices | Aurora ACU | Redis Instance | Fargate Tasks | Est. Cost |
|---------|------------|----------------|---------------|-----------|
| 10-50 | 0.5-2 ACU | cache.t4g.micro | 1 task | $200-220/mo |
| 50-200 | 1-4 ACU | cache.t4g.small | 1-2 tasks | $280-350/mo |
| 200-500 | 2-8 ACU | cache.t4g.medium | 2-3 tasks | $400-500/mo |
| 500-1000 | 4-16 ACU | cache.r6g.large | 3-5 tasks | $600-800/mo |
| 1000+ | Consider provisioned | Multi-node cluster | Auto-scaling | $1000+/mo |

### Scaling Actions

**To scale up Aurora Serverless:**
```hcl
rds_config = {
  serverless_min_capacity = 1    # Increase from 0.5
  serverless_max_capacity = 4    # Increase from 2
}
```

**To add Redis HA:**
```hcl
redis_config = {
  cluster_size                = 2    # Add replica
  automatic_failover_enabled  = true
}
```

**To enable multi-AZ:**
```hcl
vpc = {
  azs = ["us-east-2a", "us-east-2b"]  # Add second AZ
  one_nat_gateway_per_az = true       # Add second NAT
}
```

---

## 🎓 Key Learnings

### What Makes This Cost-Effective
1. **Right-sizing for workload:** 10 devices don't need enterprise HA
2. **Serverless auto-scaling:** Pay only for what you use
3. **Spot instances:** 70% discount with minimal risk
4. **Single AZ:** Acceptable risk for small deployments
5. **Reduced logging:** 5-7 days sufficient for troubleshooting

### What We Kept for Production Safety
1. **KMS encryption:** Security compliance maintained
2. **7-day backups:** Data recovery capability
3. **30% on-demand Fargate:** Stability during Spot interruptions
4. **ALB health checks:** Automatic failure detection
5. **Final snapshots:** Safety net before changes

---

## 📞 Support & Troubleshooting

### Common Issues

**Issue: Aurora Serverless not scaling down**
```bash
# Check for long-running connections
aws rds describe-db-clusters \
  --db-cluster-identifier fleet \
  --query 'DBClusters[0].ServerlessV2ScalingConfiguration'

# Solution: Ensure Fleet connection pooling is configured properly
# Set max_connections in Fleet config to 10-20 for 10 devices
```

**Issue: Spot instance interruptions**
```bash
# Check Spot interruption rate
aws ec2 describe-spot-price-history \
  --instance-types fargate \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --product-descriptions "Linux/UNIX"

# Solution: Increase on-demand percentage if interruptions > 5%
```

**Issue: Redis memory full**
```bash
# Check Redis memory usage
aws elasticache describe-cache-clusters \
  --cache-cluster-id fleet \
  --show-cache-node-info

# Solution: Upgrade to cache.t4g.small (+$10/month)
```

---

## 📚 Additional Resources

- [Aurora Serverless v2 Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)
- [Fargate Spot Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/fargate-spot.html)
- [Fleet Documentation](https://fleetdm.com/docs)
- [AWS Cost Explorer](https://console.aws.amazon.com/cost-management/home)

---

## ✅ Post-Deployment Checklist

- [ ] Verify Fleet application is accessible
- [ ] Test osquery enrollment from 1-2 devices
- [ ] Confirm Aurora Serverless ACU usage is within expected range
- [ ] Check ECS task is running and healthy
- [ ] Verify Redis cache is functioning
- [ ] Set up basic CloudWatch alarms
- [ ] Monitor costs in AWS Cost Explorer for 1 week
- [ ] Document any custom configurations
- [ ] Update team documentation with new architecture

---

**Questions or Issues?**  
Review the Terraform plan output carefully before applying changes.  
Always test in a non-production environment first if possible.
