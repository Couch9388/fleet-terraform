# Deployment Guide: Fleet with no ALB, no NAT, no Redis, no logs

`extreme-no-logs.tfvars` deploys Fleet at **~$48-52/month** by removing every
component that isn't strictly required for a ~10-device deployment:

| Component          | Config                              | Monthly cost |
| ------------------ | ----------------------------------- | ------------ |
| Aurora Serverless  | 0.5 ACU min / 1.0 ACU max           | ~$36         |
| ECS Fargate Spot   | 0.25 vCPU / 1GB, 1 task, 100% Spot  | ~$9-13       |
| Secrets Manager    | 2 secrets                           | ~$0.80       |
| S3 installers      | 1 bucket, no versioning             | ~$0.50       |
| Data transfer      | light                               | ~$1          |
| ALB                | **removed**                         | $0           |
| NAT Gateway        | **removed**                         | $0           |
| ElastiCache        | **removed**                         | $0           |
| CloudWatch Logs    | **removed**                         | $0           |
| **Total**          |                                     | **~$48-52**  |

## Architecture

```
                internet
                    │
                    │  :8080 (0.0.0.0/0)
                    ▼
        ┌───────────────────────┐
        │ ECS Fargate Spot task │  public subnet, public IP
        │  fleetdm/fleet        │
        └───────────┬───────────┘
                    │  :3306 (VPC-internal)
                    ▼
        ┌───────────────────────┐
        │ Aurora Serverless v2  │  database subnet (private)
        │ 0.5 - 1.0 ACU         │
        └───────────────────────┘
```

There is no TLS termination point. Fleet serves **plain HTTP on :8080**.

> ⚠️ **Security note**: traffic between you/agents and Fleet is unencrypted.
> For a personal/lab deployment this is usually acceptable; the Fleet server
> private key and DB credentials stay inside AWS. If you need TLS, see
> "Adding TLS" below.

## Prerequisites

- Terraform ≥ 1.12, AWS CLI, credentials with admin-ish rights
- No ACM certificate needed (there is no HTTPS listener)

## Deploy

```bash
terraform init
terraform apply -var-file=extreme-no-logs.tfvars
```

Wait ~5-10 minutes for Aurora + the first ECS task.

## Access Fleet

### Option A — direct IP

```bash
# discover the task public IP
TASK=$(aws ecs list-tasks --cluster fleet --service-name fleet --query 'taskArns[0]' --output text)
ENI=$(aws ecs describe-tasks --cluster fleet --tasks "$TASK" \
  --query "tasks[0].attachments[?status=='ATTACHED']|[0].details[?name=='networkInterfaceId'].value | [0]" --output text)
IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI" \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
echo "http://$IP:8080"
```

Then set Fleet's server URL (Settings → Organization) to `http://<IP>:8080`
so newly enrolled agents get the right address.

### Option B — Route53 (recommended)

```bash
./scripts/setup-route53.sh fleet.example.com          # one-shot
# or keep in sync automatically:
*/5 * * * * /path/to/scripts/setup-route53.sh fleet.example.com >>/tmp/fleet-dns.log 2>&1
```

The record uses TTL=60s; the script re-resolves the task IP on each run, so
DNS follows Spot restarts within ~5 minutes.

## Debugging (no logs by default)

```bash
./scripts/emergency-logging.sh enable        # adds awslogs driver, /ecs/fleet, 3-day retention
aws logs tail /ecs/fleet --follow
./scripts/emergency-logging.sh disable       # removes driver + deletes log group
```

Each enable/disable registers a new task-definition revision and forces a
redeployment (~1 min downtime).

## Adding TLS (optional)

The cheapest TLS option without an ALB is Fleet's built-in TLS
(`FLEET_SERVER_TLS=true` plus cert files). That requires baking certs into the
image or mounting them, which is out of scope for this configuration. A
pragmatic middle ground:

1. Put a **CloudFront distribution** in front of the task IP (~$1-3/month at
   low traffic) — CloudFront terminates TLS with its own cert and forwards to
   the origin over HTTP inside the AWS backbone. Note CloudFront adds latency
   for osquery's long-polling; test before committing.
2. Or re-enable the ALB (`alb_config.enabled = true` + `certificate_arn`)
   which restores managed TLS for ~$16/month.

## Reverting to a load balancer

Set `alb_config.enabled = true` in your tfvars (and provide
`certificate_arn`) and re-apply. Terraform moves existing state automatically
via the `moved` blocks in `byo-vpc/byo-db/moved.tf` — the ALB is recreated,
not orphaned.
