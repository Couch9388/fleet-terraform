#!/bin/bash
# ============================================================================
# migrate-from-alb.sh - Migrate an existing ALB-based Fleet deployment to the
# ALB-free extreme-no-logs configuration (~$48-52/month).
# ============================================================================
# What it does:
#   1. Backs up the Terraform state file
#   2. Runs terraform plan with extreme-no-logs.tfvars
#   3. On confirmation, applies (this DESTROYS the ALB, NAT GW, ElastiCache,
#      and CloudWatch log groups, and recreates the ECS service with a
#      public IP and no log driver)
#   4. Prints the new direct access URL
#   5. Optionally syncs a Route53 record via setup-route53.sh
#
# Usage:
#   ./scripts/migrate-from-alb.sh [--tfvars path] [--yes]
#
# Prerequisites: terraform >= 1.12, aws cli, valid AWS credentials.
# ============================================================================
set -euo pipefail

TFVARS="extreme-no-logs.tfvars"
ASSUME_YES=false
while [ $# -gt 0 ]; do
  case "$1" in
    --tfvars) TFVARS="$2"; shift 2 ;;
    --yes)    ASSUME_YES=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ terraform not found${NC}"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ aws cli not found${NC}"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

echo -e "${BLUE}🚀 Fleet migration: ALB -> direct public IP (${TFVARS})${NC}"
echo ""

# --- Step 1: State backup ---------------------------------------------------
echo -e "${YELLOW}Step 1/5: Backing up Terraform state...${NC}"
BACKUP="terraform.state.backup.$(date +%Y%m%d-%H%M%S).json"
if terraform state pull > "$BACKUP" 2>/dev/null && [ -s "$BACKUP" ]; then
  echo -e "${GREEN}✅ State backed up to ${BACKUP}${NC}"
else
  echo -e "${YELLOW}⚠️  No existing state found (fresh deployment?) - continuing.${NC}"
  rm -f "$BACKUP"
fi
echo ""

# --- Step 2: Plan ------------------------------------------------------------
echo -e "${YELLOW}Step 2/5: Planning changes...${NC}"
terraform plan -var-file="$TFVARS" -input=false -out=migration.plan
echo ""

# --- Step 3: Confirm ---------------------------------------------------------
echo -e "${RED}⚠️  This will DESTROY the ALB, NAT gateway(s), ElastiCache cluster and"
echo -e "   CloudWatch log groups. Fleet will briefly be unreachable while the"
echo -e "   ECS service is redeployed with a public IP.${NC}"
if [ "$ASSUME_YES" = false ]; then
  read -r -p "Continue? Type 'yes' to proceed: " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    rm -f migration.plan
    echo "Migration cancelled."
    exit 1
  fi
fi

# --- Step 4: Apply -----------------------------------------------------------
echo -e "${YELLOW}Step 3/5: Applying...${NC}"
terraform apply -input=false migration.plan
rm -f migration.plan
echo -e "${GREEN}✅ Applied.${NC}"
echo ""

# --- Step 5: Access info -----------------------------------------------------
echo -e "${YELLOW}Step 4/5: Discovering new Fleet endpoint...${NC}"
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo us-east-2)}"
CLUSTER="fleet"; SERVICE="fleet"

for i in $(seq 1 24); do
  TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --region "$REGION" \
    --query 'taskArns[0]' --output text 2>/dev/null || true)
  if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
    ENI_ID=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" --region "$REGION" \
      --query "tasks[0].attachments[?status=='ATTACHED']|[0].details[?name=='networkInterfaceId'].value | [0]" \
      --output text 2>/dev/null || true)
    if [ -n "$ENI_ID" ] && [ "$ENI_ID" != "None" ]; then
      PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --region "$REGION" \
        --query 'NetworkInterfaces[0].Association.PublicIp' --output text 2>/dev/null || true)
    fi
    [ -n "${PUBLIC_IP:-}" ] && [ "${PUBLIC_IP:-}" != "None" ] && break
  fi
  echo "   waiting for task public IP... ($i/24)"
  sleep 10
done

if [ -z "${PUBLIC_IP:-}" ] || [ "${PUBLIC_IP:-}" = "None" ]; then
  echo -e "${RED}❌ Could not determine task public IP yet. Check the ECS console,${NC}"
  echo "   then run scripts/setup-route53.sh once the task is running."
  exit 1
fi

echo -e "${GREEN}✅ Fleet is reachable at: http://${PUBLIC_IP}:8080${NC}"
echo ""

# --- Optional Route53 sync ----------------------------------------------------
echo -e "${YELLOW}Step 5/5: Route53 setup (optional)${NC}"
if [ "$ASSUME_YES" = false ]; then
  read -r -p "Point a DNS record at this IP now? (yes/no): " SETUP_DNS
else
  SETUP_DNS="no"
fi
if [ "$SETUP_DNS" = "yes" ]; then
  read -r -p "Domain (e.g. fleet.example.com): " DOMAIN
  read -r -p "Hosted zone ID (blank to auto-detect): " ZONE_ID
  "${SCRIPT_DIR}/setup-route53.sh" "$DOMAIN" ${ZONE_ID:+"$ZONE_ID"}
  echo ""
  echo -e "${YELLOW}Tip: add a cron entry to keep DNS in sync on task restarts:${NC}"
  echo "  */5 * * * * ${SCRIPT_DIR}/setup-route53.sh ${DOMAIN} ${ZONE_ID:-} >>/tmp/fleet-dns.log 2>&1"
fi

echo ""
echo -e "${GREEN}🎉 Migration complete. Estimated new cost: ~\$48-52/month.${NC}"
