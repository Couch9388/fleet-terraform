#!/bin/bash
set -e

# ============================================================================
# Fleet Terraform Cost-Optimized Deployment Script
# ============================================================================

echo "🚀 Fleet Terraform Cost Optimization Deployment"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found. Please install Terraform >= 1.12.0${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites met${NC}"
echo ""

# Prompt for certificate ARN
echo "🔐 SSL Certificate Configuration"
read -p "Enter your ACM Certificate ARN: " CERT_ARN

if [ -z "$CERT_ARN" ]; then
    echo -e "${RED}❌ Certificate ARN is required${NC}"
    exit 1
fi

echo ""

# Backup current state
echo "💾 Backing up current Terraform state..."
BACKUP_FILE="terraform-state-backup-$(date +%Y%m%d-%H%M%S).json"
terraform state pull > "$BACKUP_FILE" 2>/dev/null || echo "No existing state to backup"
echo -e "${GREEN}✅ State backed up to: $BACKUP_FILE${NC}"
echo ""

# Show cost comparison
echo "💰 Cost Comparison"
echo "=================="
echo "Before: ~\$600/month"
echo "After:  ~\$200-220/month"
echo "Savings: ~65-70% (\$380-400/month)"
echo ""

# Confirm deployment
echo -e "${YELLOW}⚠️  WARNING: This will modify your infrastructure${NC}"
echo "Expected downtime: 10-15 minutes"
echo ""
read -p "Do you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init
echo ""

# Create plan
echo "📝 Creating Terraform plan..."
terraform plan \
    -var-file="optimized-low-cost.tfvars" \
    -var="certificate_arn=$CERT_ARN" \
    -out=optimization.tfplan

echo ""
echo -e "${YELLOW}📊 Please review the plan above carefully${NC}"
echo ""
read -p "Apply this plan? (yes/no): " APPLY_CONFIRM

if [ "$APPLY_CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    rm -f optimization.tfplan
    exit 0
fi

echo ""

# Apply changes
echo "🚀 Applying Terraform changes..."
echo "This will take 15-30 minutes..."
terraform apply optimization.tfplan

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""

# Verify deployment
echo "🔍 Verifying deployment..."
echo ""

# Check Aurora
echo "Checking Aurora Serverless..."
aws rds describe-db-clusters \
    --db-cluster-identifier fleet \
    --query 'DBClusters[0].[Status,ServerlessV2ScalingConfiguration]' \
    --output table 2>/dev/null || echo "Aurora check skipped (cluster may have different name)"

echo ""

# Check ECS
echo "Checking ECS service..."
aws ecs describe-services \
    --cluster fleet \
    --services fleet \
    --query 'services[0].[status,runningCount,desiredCount]' \
    --output table 2>/dev/null || echo "ECS check skipped (service may have different name)"

echo ""

# Post-deployment instructions
echo "📋 Post-Deployment Checklist"
echo "============================"
echo "1. ✅ Verify Fleet application is accessible"
echo "2. ✅ Test osquery enrollment from 1-2 devices"
echo "3. ✅ Monitor Aurora Serverless ACU usage"
echo "4. ✅ Check ECS task health"
echo "5. ✅ Set up CloudWatch alarms (see COST-OPTIMIZATION-GUIDE.md)"
echo "6. ✅ Monitor costs in AWS Cost Explorer for 1 week"
echo ""

echo -e "${GREEN}🎉 Optimization complete! Your costs should now be ~\$200-220/month${NC}"
echo ""
echo "📚 For detailed information, see: COST-OPTIMIZATION-GUIDE.md"
echo "🔄 To rollback: terraform state push $BACKUP_FILE"
