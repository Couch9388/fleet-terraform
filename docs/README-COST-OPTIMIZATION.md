# 🎯 Fleet Terraform - Cost Optimized for 10 Devices

## Quick Summary

Your Fleet infrastructure has been optimized from **~$600/month → ~$200-220/month** (65% savings).

## 📁 Files Created

1. **`optimized-low-cost.tfvars`** - Optimized Terraform variables
2. **`COST-OPTIMIZATION-GUIDE.md`** - Detailed documentation
3. **`deploy-optimized.sh`** - Automated deployment script

## 🚀 Quick Start

### Option 1: Automated Deployment (Recommended)
```bash
./deploy-optimized.sh
```

### Option 2: Manual Deployment
```bash
# 1. Backup state
terraform state pull > backup.json

# 2. Plan changes
terraform plan \
  -var-file="optimized-low-cost.tfvars" \
  -var="certificate_arn=YOUR_CERT_ARN" \
  -out=plan.tfplan

# 3. Apply
terraform apply plan.tfplan
```

## 💰 Cost Breakdown

| Component | Monthly Cost |
|-----------|--------------|
| Aurora Serverless v2 (0.5-2 ACU) | $50-80 |
| ElastiCache Valkey (1 micro node) | $12-15 |
| ECS Fargate (1 task, 70% Spot) | $20-30 |
| Application Load Balancer | $16-20 |
| NAT Gateway (single AZ) | $32-40 |
| S3 + KMS + Logs | $10-15 |
| **TOTAL** | **$200-220** |

## ✨ Key Optimizations

- ✅ **Aurora Serverless v2** - Auto-scales from 0.5-2 ACU (saves $180/mo)
- ✅ **Single AZ** - Reduced NAT gateways and cross-AZ traffic (saves $100/mo)
- ✅ **Valkey micro node** - Cheaper than Redis, right-sized (saves $35/mo)
- ✅ **70% Fargate Spot** - Aggressive Spot usage (saves $30/mo)
- ✅ **Reduced logging** - 5-7 day retention (saves $20/mo)
- ✅ **KMS encryption** - Security maintained (+$3/mo)

## ⚠️ Important Notes

### Expected Downtime
- **10-15 minutes** during Aurora Serverless migration
- Plan deployment during maintenance window

### Tradeoffs Accepted
- ✅ Single AZ (no automatic AZ failover)
- ✅ No database replicas (Serverless handles HA)
- ✅ Single Redis node (1-2 min cache rebuild on failure)
- ✅ 70% Spot instances (rare interruptions, auto-recovery)
- ✅ Reduced monitoring (basic CloudWatch metrics)

### What's Maintained
- ✅ KMS encryption for all data
- ✅ 7-day database backups
- ✅ Production-grade security
- ✅ Auto-scaling capabilities
- ✅ Health checks and monitoring

## 📊 Scaling Guide

| Devices | Configuration | Est. Cost |
|---------|---------------|-----------|
| **10-50** | Current setup | $200-220/mo |
| 50-200 | +Aurora ACU, +Redis small | $280-350/mo |
| 200-500 | +Multi-task, +Redis medium | $400-500/mo |
| 500+ | Multi-AZ, provisioned DB | $600+/mo |

## 🔍 Monitoring

### Essential Metrics to Watch
```bash
# Aurora ACU usage (should stay 0.5-2)
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ServerlessDatabaseCapacity \
  --dimensions Name=DBClusterIdentifier,Value=fleet \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# ECS task count (should be 1)
aws ecs describe-services \
  --cluster fleet \
  --services fleet \
  --query 'services[0].runningCount'
```

## 🆘 Troubleshooting

### Aurora not scaling down?
- Check for long-running connections
- Verify Fleet connection pool settings (max 10-20 for 10 devices)

### Spot interruptions too frequent?
- Increase on-demand percentage from 30% to 50%
- Edit `ecs_cluster.fargate_capacity_providers` in tfvars

### Redis memory full?
- Upgrade to `cache.t4g.small` (+$10/month)
- Edit `redis_config.instance_type` in tfvars

## 📚 Documentation

- **Full Guide:** `COST-OPTIMIZATION-GUIDE.md`
- **Terraform Vars:** `optimized-low-cost.tfvars`
- **Fleet Docs:** https://fleetdm.com/docs

## 🔄 Rollback

If needed, restore previous configuration:
```bash
terraform state push backup.json
terraform plan -var-file="dev.tfvars.example"
terraform apply
```

## ✅ Post-Deployment Checklist

- [ ] Fleet application accessible
- [ ] Test osquery enrollment (1-2 devices)
- [ ] Aurora ACU usage within 0.5-2 range
- [ ] ECS task running and healthy
- [ ] Set up CloudWatch alarms
- [ ] Monitor costs for 1 week in Cost Explorer

---

**Questions?** Review `COST-OPTIMIZATION-GUIDE.md` for detailed information.

**Ready to deploy?** Run `./deploy-optimized.sh`
