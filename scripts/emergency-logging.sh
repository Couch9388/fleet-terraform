#!/bin/bash
# ============================================================================
# emergency-logging.sh - Temporarily enable/disable CloudWatch Logs for Fleet
# ============================================================================
# The extreme-no-logs configuration ships with NO container logging to save
# ~$3-5/month. When you need to debug Fleet, run this script to temporarily
# attach the awslogs driver to the running service, then disable it again
# when finished (to resume full cost savings).
#
# Usage:
#   ./scripts/emergency-logging.sh enable [retention-days]   # default 3 days
#   ./scripts/emergency-logging.sh disable
#   ./scripts/emergency-logging.sh status
#
# Environment overrides:
#   FLEET_CLUSTER    (default: fleet)
#   FLEET_SERVICE    (default: fleet)
#   FLEET_LOG_GROUP  (default: /ecs/fleet)
#   AWS_REGION       (default: aws cli default)
# ============================================================================
set -euo pipefail

CLUSTER="${FLEET_CLUSTER:-fleet}"
SERVICE="${FLEET_SERVICE:-fleet}"
LOG_GROUP="${FLEET_LOG_GROUP:-/ecs/fleet}"
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo us-east-2)}"
RETENTION="${2:-3}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

require() { command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ '$1' not found${NC}"; exit 1; }; }
require aws
require python3

current_task_def() {
  aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" \
    --query 'services[0].taskDefinition' --output text
}

register_task_def() {
  # $1 = "with-logs" | "without-logs" ; prints new task definition ARN
  local mode="$1" td new_td_json
  td=$(current_task_def)
  if [ -z "$td" ] || [ "$td" = "None" ]; then
    echo -e "${RED}❌ Could not find service ${SERVICE} in cluster ${CLUSTER}${NC}" >&2
    exit 1
  fi

  new_td_json=$(aws ecs describe-task-definition --task-definition "$td" --region "$REGION" \
    | MODE="$mode" LOG_GROUP="$LOG_GROUP" REGION="$REGION" python3 -c '
import json, os, sys

td = json.load(sys.stdin)["taskDefinition"]
mode, log_group, region = os.environ["MODE"], os.environ["LOG_GROUP"], os.environ["REGION"]

for c in td["containerDefinitions"]:
    if mode == "with-logs":
        c["logConfiguration"] = {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": log_group,
                "awslogs-region": region,
                "awslogs-stream-prefix": "fleet",
            },
        }
    else:
        c.pop("logConfiguration", None)

# register-task-definition only accepts a subset of describe output fields
out = {k: td[k] for k in (
    "family", "taskRoleArn", "executionRoleArn", "networkMode",
    "containerDefinitions", "requiresCompatibilities", "cpu", "memory",
) if k in td}
for opt in ("volumes", "placementConstraints", "pidMode", "ipcMode", "ephemeralStorage", "runtimePlatform"):
    if opt in td and td[opt]:
        out[opt] = td[opt]
print(json.dumps(out))
')

  aws ecs register-task-definition --cli-input-json "$new_td_json" --region "$REGION" \
    --query 'taskDefinition.taskDefinitionArn' --output text
}

case "${1:-}" in
  enable)
    echo -e "${YELLOW}📝 Enabling CloudWatch Logs for ${SERVICE} (${LOG_GROUP}, ${RETENTION}-day retention)...${NC}"
    aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$REGION" 2>/dev/null || true
    aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days "$RETENTION" --region "$REGION"
    NEW_TD=$(register_task_def with-logs)
    echo "   New task definition: $NEW_TD"
    aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" \
      --task-definition "$NEW_TD" --force-new-deployment --region "$REGION" >/dev/null
    echo -e "${GREEN}✅ Logs enabled. Tail with:${NC}"
    echo "   aws logs tail $LOG_GROUP --follow --region $REGION"
    echo -e "${YELLOW}⚠️  Remember to run '$0 disable' when done to resume cost savings.${NC}"
    ;;
  disable)
    echo -e "${YELLOW}🧹 Disabling CloudWatch Logs for ${SERVICE}...${NC}"
    NEW_TD=$(register_task_def without-logs)
    echo "   New task definition: $NEW_TD"
    aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" \
      --task-definition "$NEW_TD" --force-new-deployment --region "$REGION" >/dev/null
    aws logs delete-log-group --log-group-name "$LOG_GROUP" --region "$REGION" 2>/dev/null || true
    echo -e "${GREEN}✅ Logs disabled and log group deleted. Cost savings resumed.${NC}"
    ;;
  status)
    TD=$(current_task_def)
    aws ecs describe-task-definition --task-definition "$TD" --region "$REGION" \
      --query 'taskDefinition.containerDefinitions[0].logConfiguration' --output json
    ;;
  *)
    echo "Usage: $0 <enable [retention-days]|disable|status>"
    exit 1
    ;;
esac
