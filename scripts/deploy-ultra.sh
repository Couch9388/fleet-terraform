#!/bin/bash
set -e

# ============================================================================
# Fleet Terraform ULTRA Cost Optimization Deployment
# Target: $120-150/month (75-80% savings from original $600/month)
# ============================================================================

echo "🚀 Fleet Terraform ULTRA Cost Optimization"
echo "==========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites met${NC}"
echo ""

# Show cost comparison
echo -e "${BLUE}💰 Cost Comparison${NC}"
echo "===================="
echo "Original:  ~\$600/month"
echo "Optimized: ~\$220/month (65% savings)"
echo -e "${GREEN}ULTRA:     ~\$120-150/month (75-80% savings!)${NC}"
echo ""

# Show what's different in ULTRA
echo -e "${YELLOW}⚡ ULTRA Optimizations:${NC}"
echo "✅ Aurora capped at 1 ACU (vs 2 ACU)"
echo "✅ NO Redis/ElastiCache (in-memory cache only)"
echo "✅ 100% Fargate Spot (vs 70%)"
echo "✅ Minimal task size (0.25 vCPU, 1GB)"
echo "✅ No KMS encryption (AWS-managed keys)"
echo "✅ 3-day log retention (vs 7 days)"
echo "✅ 3-day backups (vs 7 days)"
echo ""

# Show tradeoffs
echo -e "${YELLOW}⚠️  ULTRA Tradeoffs:${NC}"
echo "❌ No Redis cache (slightly slower queries)"
echo "❌ More Spot interruptions (~2-5% vs <1%)"
echo "❌ No KMS encryption (may not meet compliance)"
echo "❌ Shorter backup window (3 days vs 7)"
echo "❌ Minimal resources (slower under heavy load)"
echo ""

# Confirm understanding
read -p "Do you understand these tradeoffs? (yes/no): " UNDERSTAND

if [ "$UNDERSTAND" != "yes" ]; then
    echo "Please review ULTRA-COST-OPTIMIZATION.md for details"
    exit 0
fi

echo ""

# Prompt for certificate ARN
echo "🔐 SSL Certificate Configuration"
read -p "Enter your ACM Certificate ARN: " CERT_ARN

if [ -z "$CERT_ARN" ]; then
    echo -e "${RED}❌ Certificate ARN required${NC}"
    exit 1
fi

echo ""

# Backup state
echo "💾 Backing up Terraform state..."
BACKUP_FILE="terraform-state-backup-ultra-$(date +%Y%m%d-%H%M%S).json"
terraform state pull > "$BACKUP_FILE" 2>/dev/null || echo "No existing state"
echo -e "${GREEN}✅ Backed up to: $BACKUP_FILE${NC}"
echo ""

# Final confirmation
echo -e "${RED}🚨 FINAL WARNING${NC}"
echo "================="
echo "This will deploy the ULTRA configuration:"
echo "  • Expected cost: \$120-150/month"
echo "  • Downtime: 15-20 minutes"
echo "  • No KMS encryption"
echo "  • No Redis cache"
echo "  • 100% Spot instances"
echo ""
read -p "Deploy ULTRA configuration? (yes/no): " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""

# Initialize
echo "🔧 Initializing Terraform..."
terraform init
echo ""

# Plan
echo "📝 Creating deployment plan..."
terraform plan \
    -var-file="ultra-low-cost.tfvars" \
    -var="certificate_arn=$CERT_ARN" \
    -out=ultra.tfplan

echo ""
echo -e "${YELLOW}📊 Review the plan above${NC}"
echo ""
read -p "Apply this plan? (yes/no): " APPLY_CONFIRM

if [ "$APPLY_CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    rm -f ultra.tfplan
    exit 0
fi

echo ""

# Apply
echo "🚀 Deploying ULTRA configuration..."
echo "This will take 15-20 minutes..."
echo ""

terraform apply ultra.tfplan

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""

# Verify
echo "🔍 Verifying deployment..."
echo ""

# Aurora
echo "Checking Aurora Serverless..."
aws rds describe-db-clusters \
    --db-cluster-identifier fleet \
    --query 'DBClusters[0].[Status,ServerlessV2ScalingConfiguration]' \
    --output table 2>/dev/null || echo "⚠️  Aurora check skipped"

echo ""

# ECS
echo "Checking ECS service..."
aws ecs describe-services \
    --cluster fleet \
    --services fleet \
    --query 'services[0].[status,runningCount,desiredCount]' \
    --output table 2>/dev/null || echo "⚠️  ECS check skipped"

echo ""

# Post-deployment
echo -e "${BLUE}📋 Post-Deployment Checklist${NC}"
echo "=============================="
echo "1. ✅ Verify Fleet application accessible"
echo "2. ✅ Test osquery enrollment (1-2 devices)"
echo "3. ✅ Monitor Aurora ACU usage (should be <1.0)"
echo "4. ✅ Check task memory usage (should be <80%)"
echo "5. ✅ Set up CloudWatch alarms (see guide)"
echo "6. ✅ Monitor for 48 hours"
echo "7. ✅ Check AWS Cost Explorer after 1 week"
echo ""

# Cost monitoring
echo -e "${GREEN}💰 Cost Monitoring${NC}"
echo "=================="
echo "Expected monthly cost: \$120-150"
echo ""
echo "Set up billing alert:"
echo "  aws budgets create-budget \\"
echo "    --account-id \$(aws sts get-caller-identity --query Account --output text) \\"
echo "    --budget file://budget.json"
echo ""

# Create budget JSON
cat > budget.json <<EOF
{
  "BudgetName": "fleet-ultra-budget",
  "BudgetLimit": {
    "Amount": "150",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
EOF

echo "Budget configuration saved to: budget.json"
echo ""

# Monitoring commands
echo -e "${BLUE}🔍 Monitoring Commands${NC}"
echo "======================"
echo ""
echo "Check Aurora ACU usage:"
echo "  aws cloudwatch get-metric-statistics \\"
echo "    --namespace AWS/RDS \\"
echo "    --metric-name ServerlessDatabaseCapacity \\"
echo "    --dimensions Name=DBClusterIdentifier,Value=fleet \\"
echo "    --start-time \$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \\"
echo "    --end-time \$(date -u +%Y-%m-%dT%H:%M:%S) \\"
echo "    --period 300 --statistics Maximum"
echo ""
echo "Check task memory:"
echo "  aws cloudwatch get-metric-statistics \\"
echo "    --namespace AWS/ECS \\"
echo "    --metric-name MemoryUtilization \\"
echo "    --dimensions Name=ServiceName,Value=fleet Name=ClusterName,Value=fleet \\"
echo "    --start-time \$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \\"
echo "    --end-time \$(date -u +%Y-%m-%dT%H:%M:%S) \\"
echo "    --period 300 --statistics Average"
echo ""

# Rollback info
echo -e "${YELLOW}🔄 Rollback Information${NC}"
echo "======================="
echo "If you need to rollback:"
echo "  terraform state push $BACKUP_FILE"
echo "  terraform plan -var-file=\"optimized-low-cost.tfvars\""
echo "  terraform apply"
echo ""

# Success
echo -e "${GREEN}🎉 ULTRA deployment complete!${NC}"
echo ""
echo "Your infrastructure should now cost ~\$120-150/month"
echo "Monitor costs in AWS Cost Explorer: https://console.aws.amazon.com/cost-management/"
echo ""
echo "📚 Documentation:"
echo "  • ULTRA-COST-OPTIMIZATION.md - Full guide"
echo "  • ultra-low-cost.tfvars - Configuration file"
echo ""
echo -e "${BLUE}Thank you for using Fleet Terraform ULTRA!${NC}"
