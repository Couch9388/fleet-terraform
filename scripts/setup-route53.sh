#!/bin/bash
# ============================================================================
# setup-route53.sh - Point a Route53 DNS record at the Fleet ECS task public IP
# ============================================================================
# With no ALB, the Fleet task's public IP changes whenever the task restarts
# (Spot reclaim, deployment, etc.). This script discovers the current public
# IP and upserts an A record with a low TTL (60s).
#
# Usage:
#   ./scripts/setup-route53.sh <fleet.example.com> [hosted-zone-id]
#
# Environment overrides:
#   FLEET_CLUSTER  (default: fleet)
#   FLEET_SERVICE  (default: fleet)
#   RECORD_TTL     (default: 60)
#   AWS_REGION     (default: aws cli default)
#
# Tip: run from cron every 5 minutes to keep the record fresh:
#   */5 * * * * /path/to/scripts/setup-route53.sh fleet.example.com Z123456 >>/tmp/fleet-dns.log 2>&1
# ============================================================================
set -euo pipefail

DOMAIN="${1:-}"
ZONE_ID="${2:-}"
CLUSTER="${FLEET_CLUSTER:-fleet}"
SERVICE="${FLEET_SERVICE:-fleet}"
TTL="${RECORD_TTL:-60}"
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo us-east-2)}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <fleet.example.com> [hosted-zone-id]"
  exit 1
fi

command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ aws cli not found${NC}"; exit 1; }

echo "🔍 Looking up current Fleet task public IP (cluster=$CLUSTER service=$SERVICE region=$REGION)..."

TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --region "$REGION" \
  --query 'taskArns[0]' --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
  echo -e "${RED}❌ No running tasks found for service ${SERVICE}${NC}"
  exit 1
fi

ENI_ID=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" --region "$REGION" \
  --query "tasks[0].attachments[?status=='ATTACHED']|[0].details[?name=='networkInterfaceId'].value | [0]" \
  --output text)

if [ -z "$ENI_ID" ] || [ "$ENI_ID" = "None" ]; then
  echo -e "${RED}❌ Could not find network interface for task ${TASK_ARN}${NC}"
  exit 1
fi

PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --region "$REGION" \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "None" ]; then
  echo -e "${RED}❌ Task has no public IP (assign_public_ip not enabled?)${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Task public IP: ${PUBLIC_IP}${NC}"

# Resolve hosted zone ID from the domain if not provided
if [ -z "$ZONE_ID" ]; then
  # Walk up the domain labels until a hosted zone matches (e.g. fleet.example.com -> example.com)
  NAME="$DOMAIN"
  while [ -n "$NAME" ]; do
    ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "${NAME}." \
      --query "HostedZones[?Name=='${NAME}.'] | [0].Id" --output text 2>/dev/null | cut -d/ -f3)
    [ -n "$ZONE_ID" ] && [ "$ZONE_ID" != "None" ] && break
    NAME="${NAME#*.}"   # strip left-most label
    [[ "$NAME" != *.* ]] && { ZONE_ID=""; break; }
  done
  if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "None" ]; then
    echo -e "${RED}❌ No Route53 hosted zone found for ${DOMAIN}${NC}"
    echo "   Pass the zone ID explicitly: $0 $DOMAIN <zone-id>"
    exit 1
  fi
fi

echo "🌐 Upserting A record: ${DOMAIN} -> ${PUBLIC_IP} (zone ${ZONE_ID}, TTL ${TTL})"

aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "{
  \"Changes\": [{
    \"Action\": \"UPSERT\",
    \"ResourceRecordSet\": {
      \"Name\": \"${DOMAIN}\",
      \"Type\": \"A\",
      \"TTL\": ${TTL},
      \"ResourceRecords\": [{\"Value\": \"${PUBLIC_IP}\"}]
    }
  }]
}" >/dev/null

echo -e "${GREEN}✅ Done. Access Fleet at: http://${DOMAIN}:8080${NC}"
echo -e "${YELLOW}⚠️  Note: plain HTTP only unless Fleet TLS certs are configured.${NC}"
