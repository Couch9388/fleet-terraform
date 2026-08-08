# Migration Guide: ALB → No-ALB (extreme-no-logs)

This guide covers migrating an existing ALB-based Fleet deployment to the
`extreme-no-logs.tfvars` configuration (~$48-52/month).

> **Fresh install?** Skip this document and read
> [DEPLOYMENT-NO-ALB.md](./DEPLOYMENT-NO-ALB.md) instead.

## What changes

| Component          | Before (extreme-low-cost) | After (extreme-no-logs)      |
| ------------------ | ------------------------- | ---------------------------- |
| ALB                | ✔ created (~$16/mo)       | ❌ destroyed                  |
| ElastiCache        | ✔ t4g.micro (~$12/mo)     | ❌ destroyed                  |
| CloudWatch Logs    | 1-day retention           | ❌ no log groups / no driver  |
| ECS networking     | private subnet (ALB → task) | public subnet + public IP  |
| Fleet access       | `https://fleet.example.com` (ALB + ACM cert) | `http://<task-ip>:8080` or Route53 A record |
| TLS                | terminated at ALB         | none (plain HTTP) by default |

## 1. Pre-migration checklist

1. **Backup state**

   ```bash
   terraform state pull > terraform.state.backup.$(date +%Y%m%d-%H%M%S).json
   ```

2. **Note the current ALB DNS name** and any Route53 records pointing at it:

   ```bash
   terraform output -json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d)"
   ```

3. **Plan for downtime**: the ECS service is redeployed; expect ~2-5 minutes
   of unavailability.

4. **Notify device owners** (optional): osquery agents buffer results and
   reconnect automatically; nothing is lost during a short outage.

## 2. Automated migration (recommended)

```bash
./scripts/migrate-from-alb.sh
```

The script backs up state, shows the plan, asks for confirmation, applies,
discovers the new task public IP, and optionally syncs a Route53 record.

## 3. Manual migration

```bash
terraform plan -var-file=extreme-no-logs.tfvars -out=migration.plan
# review: ALB, NAT GW, ElastiCache and log groups should show as destroyed
terraform apply migration.plan
```

## 4. Post-migration

1. **Get the new endpoint**:

   ```bash
   # direct IP
   ./scripts/setup-route53.sh --help   # shows discovery logic, or:
   aws ecs list-tasks --cluster fleet --service-name fleet
   ```

2. **(Optional) Route53**: keep a low-TTL A record in sync:

   ```bash
   ./scripts/setup-route53.sh fleet.example.com
   # and via cron:
   */5 * * * * /path/to/scripts/setup-route53.sh fleet.example.com >>/tmp/fleet-dns.log 2>&1
   ```

3. **Update Fleet server settings**: In Fleet UI → Settings → Organization,
   set the server URL to the new address so agents enroll with the right URL.

4. **Verify agents reconnect** within ~10 minutes.

## 5. Rollback

If anything goes wrong, restore the pre-migration state and re-apply the old
configuration:

```bash
# Restore state backup (local backend)
cp terraform.state.backup.<timestamp>.json terraform.tfstate

# Re-apply previous config
terraform apply -var-file=extreme-low-cost.tfvars
```

With a remote backend (S3), use the backend's versioning to restore the
previous state version, then apply the previous tfvars.

## 6. Troubleshooting without logs

Fleet runs with no log driver in this configuration. To debug:

```bash
# Enable logs temporarily (default 3-day retention)
./scripts/emergency-logging.sh enable

aws logs tail /ecs/fleet --follow

# When done, resume cost savings:
./scripts/emergency-logging.sh disable
```

Health check without logs:

```bash
curl -s http://<task-ip>:8080/healthz
```
