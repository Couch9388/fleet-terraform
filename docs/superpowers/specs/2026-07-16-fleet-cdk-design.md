# Fleet Terraform → AWS CDK Transformation Design

**Date:** 2026-07-16
**Status:** Approved
**Output location:** `/Users/leonxu/Desktop/fleetdm/fleet-cdk/` (new sibling repo, one level up from `fleet-terraform/`)

## 1. Summary

Transform the existing `fleet-terraform` repository (a Terraform root module + nested
submodules + 25 addon modules that deploy [Fleet](https://fleetdm.com) on AWS) into an
equivalent AWS CDK (TypeScript) application. This is a **1:1 translation**: the same
resources, same configuration surface (translated to TypeScript interfaces), and same
behavior — not a re-architecture. Scope covers the **entire** repository: the core
module chain (root → byo-vpc → byo-db → byo-ecs) and all 25+ addon modules.

## 2. Source Architecture (current Terraform)

### Module hierarchy

```
root module (main.tf, variables.tf, outputs.tf, versions.tf)
├── data sources: aws_caller_identity, aws_partition, aws_region
├── aws_kms_key/aws_kms_alias "vpc_flow_log_cloudwatch_log_group" (optional CMK)
├── module.vpc  (terraform-aws-modules/vpc/aws v5.1.2)
└── module.byo-vpc  (./byo-vpc)
    ├── 5x optional KMS keys/aliases (rds_storage, rds_password_secret,
    │   rds_observability, rds_cloudwatch_log_group, redis_at_rest,
    │   redis_cloudwatch_log_group)
    ├── module.rds  (terraform-aws-modules/rds-aurora/aws v9.16.1) — Aurora MySQL
    ├── module.redis  (cloudposse/elasticache-redis/aws >=1.9.1) — Redis/Valkey
    ├── module.secrets-manager-1  (lgallard/secrets-manager/aws v0.6.1) — DB password
    ├── aws_db_parameter_group.main / aws_rds_cluster_parameter_group.main
    ├── random_password.rds / random_id.rds_final_snapshot_identifier
    ├── aws_cloudwatch_log_group.redis (conditional, for log delivery configs)
    └── module.byo-db  (./byo-db)
        ├── 2x optional KMS keys/aliases (fargate_ephemeral_storage,
        │   cluster_cloudwatch_log_group)
        ├── module.cluster  (terraform-aws-modules/ecs/aws v7.4.0)
        ├── module.alb  (terraform-aws-modules/alb/aws v9.17.0)
        ├── aws_security_group.alb
        └── module.ecs  (./byo-ecs)
            ├── aws_ecs_task_definition.backend
            ├── aws_ecs_service.fleet
            ├── aws_appautoscaling_target/policy (cpu, memory)
            ├── aws_iam_role.main (task role) + aws_iam_role.execution
            ├── aws_iam_policy.main/execution/software_installers + attachments
            ├── aws_iam_role_policy_attachment.extras/execution_extras (caller-supplied)
            ├── aws_s3_bucket.software_installers + versioning + lifecycle +
            │   server_side_encryption + public_access_block + bucket_policy
            ├── aws_cloudwatch_log_group.main (app logs)
            ├── aws_secretsmanager_secret(_version).fleet_server_private_key
            ├── random_password.fleet_server_private_key
            ├── aws_security_group.main (ECS task SG, conditional)
            └── 3x optional KMS keys/aliases (application_logs,
                private_key_secret, software_installers)
```

### Addon modules (`addons/`, 25 total — independent, root-level modules)

`byo-cloudwatch-log-sharing`, `byo-file-carving`, `byo-firehose-logging-destination`,
`byo-kinesis-logging-destination`, `cloudfront-software-installers`,
`external-vuln-scans`, `geolite2`, `logging-alb`, `logging-destination-datadog`,
`logging-destination-firehose`, `logging-destination-snowflake`,
`logging-destination-splunk`, `mdm`, `mdmproxy`, `migrations`, `monitoring`,
`okta-conditional-access`, `osquery-carve`, `osquery-perf`, `private-registry`,
`saml-auth-proxy`, `ses`, `waf-alb`, `xrays-sidecar`.

Other top-level variants **out of scope for this migration** (not part of "the current
terraform" being transformed — confirm before ever touching): `gcp/` (GCP provider,
unrelated to AWS CDK), `k8s/` (Kubernetes manifests via Terraform, not AWS CDK), and
`example/` (usage example wiring root module — will get a CDK-equivalent
`bin/fleet.ts` example instead).

### Recurring KMS pattern

Nearly every KMS-capable resource in this codebase follows the same shape:

```hcl
xyz_kms = {
  cmk_enabled        = bool  (default false)
  kms_key_arn        = string|null
  kms_alias          = string
  extra_kms_policies = list(policy statement)
}
```

Behavior: if `cmk_enabled` and no `kms_key_arn` given → module creates a CMK + alias
with a policy built from: (a) `kms_base_policy` (defaults to root-account `kms:*`), (b)
`extra_kms_policies`, (c) module-required service-principal statements (e.g.
`logs.<region>.amazonaws.com` for CloudWatch Logs, `rds.amazonaws.com` for RDS, etc). If
`kms_key_arn` is given, the module uses it as-is (caller owns the key policy). If
`cmk_enabled` is false, AWS-managed keys are used.

This pattern will be extracted into one shared CDK helper (see §5) instead of being
hand-rolled per construct.

## 3. Target Structure (new `fleet-cdk` repo)

```
fleet-cdk/
├── src/
│   ├── core/
│   │   ├── fleet-stack.ts            # top-level Stack, wires everything together
│   │   ├── vpc-construct.ts          # VPC (native CDK Vpc, mirrors terraform-aws-modules/vpc)
│   │   └── flow-log-kms.ts           # VPC flow log KMS key/alias (optional CMK)
│   ├── byo-vpc/
│   │   ├── byo-vpc-construct.ts      # composes rds + redis + secrets + param groups
│   │   ├── rds-construct.ts          # Aurora MySQL cluster + related KMS
│   │   ├── redis-construct.ts        # ElastiCache replication group + related KMS
│   │   └── db-password-secret.ts     # Secrets Manager DB password
│   ├── byo-db/
│   │   ├── byo-db-construct.ts       # composes ecs cluster + alb + byo-ecs
│   │   ├── ecs-cluster-construct.ts  # ECS Cluster + cluster-level KMS
│   │   └── alb-construct.ts          # ALB + listeners + target groups + SG
│   ├── byo-ecs/
│   │   ├── byo-ecs-construct.ts      # composes task def + service + autoscaling
│   │   ├── fleet-task-definition.ts  # FargateTaskDefinition + container def
│   │   ├── fleet-service.ts          # FargateService + autoscaling policies
│   │   ├── iam.ts                    # task role, execution role, policies
│   │   ├── s3-installers.ts          # software installers bucket (+ policy)
│   │   ├── app-logs.ts               # app CloudWatch log group + KMS
│   │   └── private-key-secret.ts     # Fleet server private key secret + KMS
│   ├── addons/
│   │   ├── byo-cloudwatch-log-sharing/
│   │   ├── byo-file-carving/
│   │   ├── byo-firehose-logging-destination/
│   │   ├── byo-kinesis-logging-destination/
│   │   ├── cloudfront-software-installers/
│   │   ├── external-vuln-scans/
│   │   ├── geolite2/
│   │   ├── logging-alb/
│   │   ├── logging-destination-datadog/
│   │   ├── logging-destination-firehose/
│   │   ├── logging-destination-snowflake/
│   │   ├── logging-destination-splunk/
│   │   ├── mdm/
│   │   ├── mdmproxy/
│   │   ├── migrations/
│   │   ├── monitoring/
│   │   ├── okta-conditional-access/
│   │   ├── osquery-carve/
│   │   ├── osquery-perf/
│   │   ├── private-registry/
│   │   ├── saml-auth-proxy/
│   │   ├── ses/
│   │   ├── waf-alb/
│   │   └── xrays-sidecar/
│   │       (each: `<name>-construct.ts` + `types.ts` + `README.md`)
│   └── shared/
│       ├── kms-helper.ts             # buildCmk(): base+extra+service statements → Key+Alias
│       ├── types.ts                  # KmsConfig and other shared interfaces
│       └── naming.ts                 # small helpers mirroring TF locals/defaults
├── bin/
│   └── fleet.ts                      # CDK app entry point / usage example
├── test/
│   ├── core/
│   ├── byo-vpc/
│   ├── byo-db/
│   ├── byo-ecs/
│   └── addons/
├── package.json
├── tsconfig.json
├── jest.config.ts
├── cdk.json
└── README.md
```

## 4. Config Interfaces

Each Terraform `variable` block becomes a TypeScript `interface`, colocated with its
primary construct, preserving the same field names (camelCase) and the same defaults.
Nested optional objects (e.g. `*_kms`, `observability`, `networking`) become nested
optional interfaces.

Shared KMS shape (`src/shared/types.ts`):

```typescript
export interface KmsConfig {
  readonly cmkEnabled?: boolean;             // default: false
  readonly kmsKeyArn?: string;               // default: undefined
  readonly kmsAlias?: string;                // per-resource default, e.g. "fleet-rds-storage"
  readonly extraKmsPolicies?: iam.PolicyStatement[]; // default: []
}
```

Top-level interfaces and their Terraform source:

| Interface | Terraform variable | Construct |
|---|---|---|
| `VpcConfig` | `var.vpc` | `core/vpc-construct.ts` |
| `RdsConfig` | `var.rds_config` | `byo-vpc/rds-construct.ts` |
| `RedisConfig` | `var.redis_config` | `byo-vpc/redis-construct.ts` |
| `EcsClusterConfig` | `var.ecs_cluster` | `byo-db/ecs-cluster-construct.ts` |
| `AlbConfig` | `var.alb_config` | `byo-db/alb-construct.ts` |
| `FleetConfig` | `var.fleet_config` | `byo-ecs/byo-ecs-construct.ts` |
| `MigrationConfig` | `var.migration_config` | `byo-ecs/byo-ecs-construct.ts` |
| `KmsBasePolicyStatement[]` | `var.kms_base_policy` | `shared/kms-helper.ts` |

All defaults are copied verbatim from the Terraform `default = {...}` blocks and
`optional(type, default)` declarations. Terraform `validation` blocks become either:
constructor-time assertions (`throw new Error(...)`) for cross-field validation, or
TypeScript type constraints where the shape alone can enforce it (e.g. string literal
unions for `private_key_delivery_method: 'ecs' | 'iam'`).

## 5. Construct Decomposition (Terraform resource → CDK L1/L2)

### `src/core/`

| Terraform | CDK |
|---|---|
| `data.aws_caller_identity.current` | `Stack.of(this).account` |
| `data.aws_region.current` | `Stack.of(this).region` |
| `data.aws_partition.current` | `Aws.PARTITION` / `Stack.of(this).partition` |
| `aws_kms_key`/`alias.vpc_flow_log_cloudwatch_log_group` | `kms.Key` + `kms.Alias` via shared helper |
| `module.vpc` | `ec2.Vpc` (L2) with subnet configuration matching public/private/database/elasticache subnet groups (CDK subnet groups + `reserved`/`cidrMask` config, or manual `ec2.CfnSubnet` for the 4-tier layout if `Vpc` L2 subnet grouping can't express elasticache/database tiers directly — use `ec2.Vpc` with 4 `subnetConfiguration` groups) |

### `src/byo-vpc/`

| Terraform | CDK |
|---|---|
| `module.rds` (rds-aurora) | `rds.DatabaseCluster` (`aws-cdk-lib/aws-rds`), engine `DatabaseClusterEngine.auroraMysql`, `instances` from `rds_config.replicas`, `serverlessV2` scaling if `serverless=true` |
| `aws_db_parameter_group.main` | `rds.ParameterGroup` (instance-level) |
| `aws_rds_cluster_parameter_group.main` | `rds.ParameterGroup` (cluster-level) |
| `random_password.rds` | CDK-generated `secretsmanager.Secret` with `generateSecretString`, or `DatabaseCluster`'s built-in credential generation |
| `module.secrets-manager-1` | `secretsmanager.Secret` storing DB password |
| `module.redis` (cloudposse) | `elasticache.CfnReplicationGroup` + `CfnSubnetGroup` (no stable L2 for ElastiCache — use L1 `Cfn*`) |
| `aws_cloudwatch_log_group.redis` | `logs.LogGroup` (conditional on log delivery config) |
| 5x KMS key/alias pairs | `kms.Key`/`kms.Alias` via shared helper, one call per surface |

### `src/byo-db/`

| Terraform | CDK |
|---|---|
| `module.cluster` (ecs) | `ecs.Cluster` (L2), `addCapacity`/capacity providers mirroring `fargate_capacity_providers`/`autoscaling_capacity_providers` |
| `module.alb` | `elbv2.ApplicationLoadBalancer` (L2) + `addListener`/`addTargetGroups`, HTTP→HTTPS redirect, HTTPS listener rules from `https_listener_rules` |
| `aws_security_group.alb` | `ec2.SecurityGroup` with matching ingress/egress rules |
| 2x KMS key/alias pairs | shared helper |

### `src/byo-ecs/`

| Terraform | CDK |
|---|---|
| `aws_ecs_task_definition.backend` | `ecs.FargateTaskDefinition` + `addContainer` (env vars, secrets, port mappings, log config, ulimits, mount points, volumes, sidecars) |
| `aws_ecs_service.fleet` | `ecs.FargateService` with `loadBalancers` (multiple target group attachments incl. `extra_load_balancers`) |
| `aws_appautoscaling_target`/`policy_memory`/`policy_cpu` | `service.autoScaleTaskCount()` + `.scaleOnMemoryUtilization()` / `.scaleOnCpuUtilization()` |
| `aws_iam_role.main` (task role) | `iam.Role` (conditional creation if no `iam_role_arn` supplied — mirrors Terraform `count`) |
| `aws_iam_role.execution` | `iam.Role` |
| `aws_iam_policy.main/execution/software_installers` + attachments | `iam.Policy`/`PolicyStatement` attached to respective roles |
| `aws_iam_role_policy_attachment.extras/execution_extras` | `role.addManagedPolicy(...)` loop over caller-supplied ARNs |
| `aws_s3_bucket.software_installers` + versioning + lifecycle + SSE + public access block + bucket policy | `s3.Bucket` (L2) with `encryptionKey`, `versioned`, `lifecycleRules`, `blockPublicAccess: BLOCK_ALL`, and an added `DenyNonHTTPS` + conditional CloudFront-read bucket policy statement |
| `aws_cloudwatch_log_group.main` | `logs.LogGroup` |
| `aws_secretsmanager_secret(_version).fleet_server_private_key` + `random_password` | `secretsmanager.Secret` with generated secret string |
| `aws_security_group.main` | `ec2.SecurityGroup` (conditional, mirrors Terraform `count`) |
| 3x KMS key/alias pairs | shared helper |

### `src/addons/*`

Each addon module gets a 1:1 construct translation following the same pattern:
Terraform `variables.tf` → props interface, `main.tf` resources → CDK L1/L2 resources,
`outputs.tf` → public readonly properties on the construct. Addons are structurally
simple (1–10 resources each) relative to the core chain.

## 6. Shared KMS Helper

`src/shared/kms-helper.ts` centralizes the repeated "base policy + extra policies +
service statements → CMK + alias" pattern used ~10 times across the codebase:

```typescript
export interface BuildCmkProps {
  readonly description: string;
  readonly aliasName: string;
  readonly basePolicyStatements: iam.PolicyStatement[]; // from kmsBasePolicy or default root stmt
  readonly extraPolicyStatements?: iam.PolicyStatement[];
  readonly servicePolicyStatements: iam.PolicyStatement[]; // module-required, e.g. logs.*.amazonaws.com
}

export function buildCmk(scope: Construct, id: string, props: BuildCmkProps): kms.Key;
```

Each construct calls `buildCmk(...)` conditionally (only when `cmkEnabled === true &&
kmsKeyArn === undefined`), matching the Terraform `count` conditionals exactly.

## 7. Stack Wiring

A single top-level `FleetStack` (in `src/core/fleet-stack.ts`) instantiates the
construct tree, threading outputs from one construct into the props of the next —
directly replacing Terraform's `merge()`-based variable wiring with plain
TypeScript object composition and construct property references (e.g.
`rdsConstruct.cluster.clusterEndpoint.hostname` → `fleetConfig.database.address`).

`bin/fleet.ts` is the CDK App entry point and doubles as the canonical usage example
(replacing `example/main.tf`).

Addon constructs are consumed independently — instantiated either inside `FleetStack`
or in separate example stacks, mirroring how Terraform addons are separately-invoked
modules today.

## 8. Testing Strategy

- **Unit/snapshot tests** (`test/**/*.test.ts`) — one suite per construct, using
  `aws-cdk-lib/assertions` (`Template.fromStack`).
- **Fine-grained assertions** — verify key resource properties per construct (engine
  type, encryption settings, IAM policy statements, KMS conditional creation logic).
- **Conditional-creation parity tests** — explicitly test the "cmkEnabled + no arn →
  creates CMK", "cmkEnabled + arn given → uses provided key, no CMK created", "cmkEnabled
  false → no CMK" matrix for every KMS surface, mirroring the Terraform `count` logic.
- **Validation tests** — construct-time errors for the equivalent of Terraform
  `validation` blocks (e.g. `backtrackWindow` range, `databaseInsightsMode` enum,
  `privateKeyDeliveryMethod` enum).

## 9. Out of Scope / Explicit Non-Goals

- No architectural improvements or restructuring — this is a 1:1 behavioral port.
- `gcp/` and `k8s/` directories are not part of this migration (different provider /
  different IaC target).
- No automated Terraform state import / migration tooling in this phase (new stacks
  are deployed fresh; existing Terraform-managed infrastructure is left as-is unless
  a follow-up migration project is requested).
- No CI/CD pipeline setup for the new repo beyond what's needed to run `cdk synth`
  and tests locally, unless requested later.

## 10. Delivery Order

Given the scope ("everything"), implementation proceeds in dependency order:

1. Repo scaffold (`fleet-cdk/` — package.json, tsconfig, cdk.json, jest config)
2. `shared/` (KMS helper, shared types)
3. `core/` (VPC, flow log KMS)
4. `byo-vpc/` (RDS, Redis, secrets, parameter groups, KMS)
5. `byo-db/` (ECS cluster, ALB, KMS)
6. `byo-ecs/` (task def, service, IAM, S3, logs, private key, KMS)
7. `bin/fleet.ts` top-level wiring + example
8. Addon modules (25), roughly ordered by dependency/complexity
9. Full test suite pass + `cdk synth` validation across the whole app
