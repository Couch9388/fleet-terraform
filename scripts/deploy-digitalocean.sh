#!/bin/bash
set -e

# ============================================================================
# Fleet DigitalOcean Deployment — 10 Devices
# Target: ~$30/month
# ============================================================================

echo "🚀 Fleet DigitalOcean Deployment (10 Devices)"
echo "=============================================="
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
    echo "Install: brew install hashicorp/tap/terraform"
    exit 1
fi

if [ -z "$DIGITALOCEAN_TOKEN" ]; then
    echo -e "${RED}❌ DIGITALOCEAN_TOKEN not set${NC}"
    echo "Set it with: export DIGITALOCEAN_TOKEN=\"dop_v1_your_token\""
    echo "Get one at: https://cloud.digitalocean.com/account/api/tokens"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites met${NC}"
echo ""

# Show cost estimate
echo -e "${BLUE}💰 Estimated Monthly Cost: ~\$30${NC}"
echo "=================================="
echo "  App Platform (1 GiB):     \$10"
echo "  Managed MySQL (1 GB):     \$15"
echo "  Spaces (250 GB):           \$5 (or free)"
echo "  VPC, DNS, TLS:             Free"
echo ""

# Show what's included
echo -e "${YELLOW}📦 What's Included:${NC}"
echo "✅ App Platform with automatic TLS"
echo "✅ Managed MySQL with daily backups"
echo "✅ Spaces bucket for software installers"
echo "✅ VPC private networking"
echo "✅ DNS zone + CNAME record"
echo "✅ Database firewall (app-only access)"
echo "✅ Pre-deploy database migrations"
echo ""

# Show what's not included
echo -e "${YELLOW}⚡ Optimizations:${NC}"
echo "• No Redis cache (Fleet uses in-memory for 10 devices)"
echo "• Single app instance (sufficient for 10 devices)"
echo "• Single database node (fine for 10 devices)"
echo ""

# Prompt for domain
echo "🌐 Domain Configuration"
echo "======================"
echo "You need a domain name for your Fleet instance."
echo "The DNS zone will be created in DigitalOcean."
echo ""
read -p "Enter your Fleet domain (e.g., fleet.example.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    echo -e "${RED}❌ Domain name required${NC}"
    exit 1
fi

echo ""

# Optional: Fleet license key
read -p "Fleet license key (optional, press Enter to skip): " LICENSE_KEY

echo ""

# Optional: Spaces keys
echo "📦 Spaces Configuration"
echo "======================="
echo "Spaces keys are needed for the software installers bucket."
echo "Generate them at: https://cloud.digitalocean.com/spaces/access_keys"
echo ""

if [ -z "$SPACES_ACCESS_KEY_ID" ]; then
    read -p "Spaces Access Key ID: " SPACES_ACCESS_KEY_ID
    export SPACES_ACCESS_KEY_ID
fi

if [ -z "$SPACES_SECRET_ACCESS_KEY" ]; then
    read -p "Spaces Secret Access Key: " SPACES_SECRET_ACCESS_KEY
    export SPACES_SECRET_ACCESS_KEY
fi

echo ""

# Confirm
echo -e "${BLUE}📋 Deployment Summary${NC}"
echo "====================="
echo "  Domain:     $DOMAIN_NAME"
echo "  Region:     nyc3 (default)"
echo "  App:        1 GiB RAM, 1 instance"
echo "  Database:   Managed MySQL 8, 1 GB RAM"
echo "  Cache:      Disabled (in-memory)"
echo "  Storage:    Spaces bucket"
echo "  Est. Cost:  ~\$30/month"
echo ""

read -p "Deploy Fleet for 10 devices? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""

# Navigate to digitalocean directory
cd "$(dirname "$0")/../digitalocean"

# Initialize
echo "🔧 Initializing Terraform..."
terraform init

echo ""

# Build var args
VAR_ARGS="-var=domain_name=$DOMAIN_NAME -var-file=fleet-10.tfvars"

if [ -n "$LICENSE_KEY" ]; then
    VAR_ARGS="$VAR_ARGS -var=fleet_config={\"image_tag\":\"fleetdm/fleet:v4.90.0\",\"instance_size_slug\":\"basic-xs\",\"instance_count\":1,\"debug_logging\":false,\"exec_migration\":true,\"license_key\":\"$LICENSE_KEY\",\"extra_env_vars\":{\"FLEET_REDIS_ADDRESS\":\"\"}}"
fi

# Plan
echo "📝 Creating deployment plan..."
terraform plan $VAR_ARGS -out=fleet-10.tfplan

echo ""
echo -e "${YELLOW}📊 Review the plan above${NC}"
echo ""
read -p "Apply this plan? (yes/no): " APPLY_CONFIRM

if [ "$APPLY_CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    rm -f fleet-10.tfplan
    exit 0
fi

echo ""

# Apply
echo "🚀 Deploying Fleet..."
echo "This will take 10-15 minutes..."
echo ""

terraform apply fleet-10.tfplan

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""

# Get outputs
echo "📋 Deployment Details"
echo "====================="
echo ""

APP_URL=$(terraform output -raw fleet_application_url 2>/dev/null || echo "N/A")
APP_INGRESS=$(terraform output -raw app_default_ingress 2>/dev/null || echo "N/A")
DB_MODE=$(terraform output -raw database_mode 2>/dev/null || echo "N/A")

echo "  Fleet URL:       $APP_URL"
echo "  Default Ingress: $APP_INGRESS"
echo "  Database Mode:   $DB_MODE"
echo ""

# DNS instructions
echo -e "${YELLOW}🌐 DNS Setup Required${NC}"
echo "======================"
echo "Point your domain to DigitalOcean's name servers:"
echo "  ns1.digitalocean.com"
echo "  ns2.digitalocean.com"
echo "  ns3.digitalocean.com"
echo ""
echo "Or create a CNAME record:"
echo "  $DOMAIN_NAME → $APP_INGRESS"
echo ""

# Next steps
echo -e "${BLUE}📋 Next Steps${NC}"
echo "============="
echo "1. ✅ Wait for DNS propagation (5-30 minutes)"
echo "2. ✅ Visit $APP_URL to complete Fleet setup"
echo "3. ✅ Create admin account"
echo "4. ✅ Enroll your 10 devices"
echo "5. ✅ (Optional) Set up Fleet GitOps for configuration"
echo ""

# Monitoring
echo -e "${BLUE}🔍 Monitoring${NC}"
echo "============="
echo "Check app status:"
echo "  doctl apps list"
echo ""
echo "View app logs:"
echo "  doctl apps logs <app-id> --type run"
echo ""
echo "Check database:"
echo "  doctl databases list"
echo ""

# Cost monitoring
echo -e "${GREEN}💰 Cost Monitoring${NC}"
echo "=================="
echo "Expected monthly cost: ~\$30"
echo "View billing: https://cloud.digitalocean.com/billing"
echo ""

echo -e "${GREEN}🎉 Fleet for 10 devices deployed successfully!${NC}"
echo ""
echo "Access your Fleet instance at: $APP_URL"
