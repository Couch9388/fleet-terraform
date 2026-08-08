#!/bin/bash
set -e

# ============================================================================
# Fleet Terraform EXTREME Cost Optimization Deployment
# Target: $60-80/month (87-90% savings from original $600/month)
# ============================================================================

echo "🚀 Fleet Terraform EXTREME Cost Optimization"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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
echo "Ultra:     ~\$120-150/month (75-80% savings)"
echo -e "${GREEN}EXTREME:   ~\$60-80/month (87-90% savings!)${NC}"
echo ""

# Show what's different in EXTREME
echo -e "${YELLOW}⚡ EXTREME Optimizations:${NC}"
echo "✅ NO NAT Gateway (public subnets for ECS) - saves \$32/month"
echo "✅ NO Load Balancer (direct ECS access) - saves \$16/month"
echo "✅ Aurora fixed 0.5 ACU (no scaling) - saves \$15/month"
echo "✅ 1-day log retention - saves \$5/month"
echo "✅ 1-day backup retention - saves \$5/month"
echo "✅ 100% Fargate Spot"
echo "✅ No Redis/ElastiCache (in-memory cache only)"
echo "✅ No KMS encryption (AWS-managed keys)"
echo ""

# Show tradeoffs
echo -e "${RED}⚠️  EXTREME Tradeoffs:${NC}"
echo "❌ Public subnets (less network isolation)"
echo "❌ No Load Balancer (direct task IP access)"
echo "❌ No Redis cache (slower queries)"
echo "❌ No auto-scaling Aurora (fixed 0.5 ACU)"
echo "❌ 1-day backups only (minimal recovery)"
echo "❌ 1-day logs only (debugging difficult)"
echo "❌ More Spot interruptions (~5-10%)"
echo "❌ No KMS encryption (may not meet compliance)"
echo "❌ Minimal resources (slower under any load)"
echo ""

# Security warning
echo -e "${MAGENTA}🚨 SECURITY WARNING${NC}"
echo "==================="
echo "EXTREME mode deploys ECS tasks in PUBLIC subnets with PUBLIC IPs"
echo "This means your Fleet instance is directly exposed to the internet"
echo "Security relies entirely on security groups (no ALB as extra layer)"
echo ""
echo "ONLY use this for:"
echo "  • Testing/development environments"
echo "  • Very small deployments (10 devices max)"
echo "  • Environments where security is not critical"
echo ""

# Confirm understanding
read -p "Do you understand these EXTREME security tradeoffs? (yes/no): " SECURITY_UNDERSTAND

if [ "$SECURITY_UNDERSTAND" != "yes" ]; then
    echo "Please review extreme-low-cost.tfvars for details"
    exit 0
fi

echo ""

# Additional confirmation for public exposure
echo -e "${YELLOW}⚠️  PUBLIC SUBNET CONFIRMATION${NC}"
echo "================================"
echo "This deployment will:"
echo "  • Place ECS tasks in PUBLIC subnets (not private)"
echo "  • Assign PUBLIC IP addresses to Fleet tasks"
echo "  • Allow direct internet access to Fleet"
echo "  • Skip NAT Gateway entirely"
echo ""
read -p "Confirm public subnet deployment? (yes/no): " PUBLIC_CONFIRM

if [ "$PUBLIC_CONFIRM" != "yes" ]; then
    echo "Deployment cancelled for security review"
    exit 0
fi

echo ""

# Prompt for certificate ARN
echo "🔐 SSL Certificate Configuration"
echo "Note: You'll need to manually configure DNS after deployment"
echo "since there's no ALB with automatic DNS management"
read -p "Enter your ACM Certificate ARN: " CERT_ARN

if [ -z "$CERT_ARN" ]; then
    echo -e "${RED}❌ Certificate ARN required${NC}"
    exit 1
fi

echo ""

# Backup state
echo "💾 Backing up Terraform state..."
BACKUP_FILE="terraform-state-backup-extreme-$(date +%Y%m%d-%H%M%S).json"
terraform state pull > "$BACKUP_FILE" 2>/dev/null || echo "No existing state"
echo -e "${GREEN}✅ Backed up to: $BACKUP_FILE${NC}"
echo ""

# Final confirmation
echo -e "${RED}🚨 FINAL WARNING - EXTREME COST DEPLOYMENT${NC}"
echo "==========================================="
echo "This will deploy the EXTREME configuration:"
echo "  • Expected cost: \$60-80/month"
echo "  • Downtime: 20-30 minutes"
echo "  • NO NAT Gateway (public subnets)"
echo "  • NO Load Balancer (direct IP access)"
echo "  • NO KMS encryption"
echo "  • NO Redis cache"
echo "  • 100% Spot instances"
echo "  • 1-day backups and logs"
echo ""
read -p "Deploy EXTREME configuration? (yes/no): " FINAL_CONFIRM

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
    -var-file="extreme-low-cost.tfvars" \
    -var="certificate_arn=$CERT_ARN" \
    -out=extreme.tfplan

echo ""
echo -e "${YELLOW}📊 Review the plan above${NC}"
echo "Key things to check:"
echo "  • ECS tasks will be in PUBLIC subnets"
echo "  • No NAT Gateway will be created"
echo "  • No Load Balancer will be created"
echo "  • Aurora fixed at 0.5 ACU"
echo ""
read -p "Apply this EXTREME plan? (yes/no): " APPLY_CONFIRM

if [ "$APPLY_CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    rm -f extreme.tfplan
    exit 0
fi

echo ""

# Apply
echo "🚀 Deploying EXTREME configuration..."
echo "This will take 20-30 minutes..."
echo ""

terraform apply extreme.tfplan

echo ""
echo -e "${GREEN}✅ EXTREME Deployment complete!${NC}"
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

# Get ECS task public IP
echo "🌐 Getting ECS Task Public IP..."
echo "================================"
echo "Since there's no Load Balancer, you'll need to access Fleet directly:"
echo ""

TASK_ARN=$(aws ecs list-tasks --cluster fleet --service-name fleet --query 'taskArns[0]' --output text 2>/dev/null || echo "")

if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
    TASK_ID=$(echo "$TASK_ARN" | cut -d'/' -f3)
    echo "Task ID: $TASK_ID"
    
    # Get network details
    TASK_DETAILS=$(aws ecs describe-tasks --cluster fleet --tasks "$TASK_ARN" --query 'tasks[0].attachments[0].details' 2>/dev/null || echo "[]")
    
    PUBLIC_IP=$(echo "$TASK_DETAILS" | jq -r '.[] | select(.name=="networkInterfaceId") | .value' 2>/dev/null || echo "")
    
    if [ -n "$PUBLIC_IP" ]; then
        # Get public IP from network interface
        PUBLIC_IP=$(aws ec2 describe-network-interfaces \
            --network-interface-ids "$PUBLIC_IP" \
            --query 'NetworkInterfaces[0].Association.PublicIp' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
            echo ""
            echo -e "${GREEN}✅ Fleet Task Public IP: $PUBLIC_IP${NC}"
            echo ""
            echo "Access Fleet at: http://$PUBLIC_IP:8080"
            echo "Or set up DNS: your-domain.com → $PUBLIC_IP"
            echo ""
            echo -e "${YELLOW}⚠️  Note: IP changes when task restarts (rare with Spot)${NC}"
            echo "Set up Route53 or your DNS provider to auto-update"
        else
            echo "⚠️  Could not retrieve public IP"
            echo "Check: aws ecs describe-tasks --cluster fleet --tasks $TASK_ARN"
        fi
    else
        echo "⚠️  Could not retrieve network interface"
    fi
else
    echo "⚠️  No running tasks found"
    echo "Task may still be starting..."
fi

echo ""

# Post-deployment
echo -e "${BLUE}📋 Post-Deployment Checklist${NC}"
echo "=============================="
echo "1. ✅ Get ECS task public IP (see above)"
echo "2. ✅ Test Fleet access via http://PUBLIC_IP:8080"
echo "3. ✅ Set up DNS record (optional but recommended)"
echo "4. ✅ Configure osquery enrollment (1-2 devices)"
echo "5. ✅ Monitor Aurora ACU usage (should stay at 0.5)"
echo "6. ✅ Check task memory usage (should be <80%)"
echo "7. ✅ Set up billing alert (see below)"
echo "8. ✅ Monitor for 48 hours"
echo "9. ✅ Check AWS Cost Explorer after 1 week"
echo ""

# Cost monitoring
echo -e "${GREEN}💰 Cost Monitoring${NC}"
echo "=================="
echo "Expected monthly cost: \$60-80"
echo ""

# Create budget JSON
BUDGET_FILE="fleet-extreme-budget.json"
cat > "$BUDGET_FILE" <<EOF
{
  "BudgetName": "fleet-extreme-budget",
  "BudgetLimit": {
    "Amount": "80",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {
    "TagKey": ["Project"],
    "TagValue": ["fleet"]
  }
}
EOF

echo "Budget configuration saved to: $BUDGET_FILE"
echo ""
echo "Set up billing alert:"
echo "  aws budgets create-budget \\"
echo "    --account-id \$(aws sts get-caller-identity --query Account --output text) \\"
echo "    --budget file://$BUDGET_FILE"
echo ""

# DNS Setup instructions
echo -e "${YELLOW}🌐 DNS Setup (Recommended)${NC}"
echo "==========================="
echo "Since there's no ALB, you have two options:"
echo ""
echo "Option 1: Manual DNS (simplest)"
echo "  1. Get task public IP from above"
echo "  2. Create A record: your-domain.com → PUBLIC_IP"
echo "  3. Update DNS when IP changes (rare)"
echo ""
echo "Option 2: Route53 with Lambda (advanced)"
echo "  1. Create Lambda function to monitor ECS tasks"
echo "  2. Update Route53 A record on task changes"
echo "  3. More complex but fully automated"
echo ""

# Monitoring commands
echo -e "${BLUE}🔍 Monitoring Commands${NC}"
echo "======================"
echo ""
echo "Check Aurora ACU usage (should be 0.5):"
echo "  aws cloudwatch get-metric-statistics \\"
echo "    --namespace AWS/RDS \\"
echo "    --metric-name ServerlessDatabaseCapacity \\"
echo "    --dimensions Name=DBClusterIdentifier,Value=fleet \\"
echo "    --start-time \$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \\"
echo "    --end-time \$(date -u +%Y-%m-%dT%H:%M:%S) \\"
echo "    --period 300 --statistics Maximum"
echo ""
echo "Check task memory (should be <80%):"
echo "  aws cloudwatch get-metric-statistics \\"
echo "    --namespace AWS/ECS \\"
echo "    --metric-name MemoryUtilization \\"
echo "    --dimensions Name=ServiceName,Value=fleet Name=ClusterName,Value=fleet \\"
echo "    --start-time \$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \\"
echo "    --end-time \$(date -u +%Y-%m-%dT%H:%M:%S) \\"
echo "    --period 300 --statistics Average"
echo ""

# Security recommendations
echo -e "${RED}🔒 Security Recommendations${NC}"
echo "============================"
echo "Since you're using PUBLIC subnets:"
echo "  • Use strong admin passwords"
echo "  • Enable MFA on Fleet admin accounts"
echo "  • Consider IP whitelisting in security groups"
echo "  • Monitor CloudTrail for unusual activity"
echo "  • Use Fleet's RBAC features"
echo ""

# Rollback info
echo -e "${YELLOW}🔄 Rollback Information${NC}"
echo "======================="
echo "If you need to rollback to higher availability:"
echo "  terraform state push $BACKUP_FILE"
echo "  terraform plan -var-file=\"optimized-low-cost.tfvars\""
echo "  terraform apply"
echo ""

# Success
echo -e "${GREEN}🎉 EXTREME deployment complete!${NC}"
echo ""
echo "Your infrastructure should now cost ~\$60-80/month"
echo "Monitor costs in AWS Cost Explorer: https://console.aws.amazon.com/cost-management/"
echo ""
echo "📚 Documentation:"
echo "  • extreme-low-cost.tfvars - Configuration file"
echo "  • This script - Deployment automation"
echo ""
echo -e "${MAGENTA}⚠️  Remember: This is EXTREME cost optimization with security tradeoffs${NC}"
echo -e "${BLUE}Thank you for using Fleet Terraform EXTREME!${NC}"