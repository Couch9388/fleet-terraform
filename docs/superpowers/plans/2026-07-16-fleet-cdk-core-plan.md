# Fleet CDK — Core Stack Implementation Plan

**Date:** 2026-07-16
**Design doc:** `../specs/2026-07-16-fleet-cdk-design.md`
**Output repo:** `/Users/leonxu/Desktop/fleetdm/fleet-cdk/`

## Scope

This plan covers delivery-order items 1–7 from the design doc: scaffold → shared utilities → core VPC → byo-vpc → byo-db → byo-ecs → FleetStack wiring. Addon modules (items 8–9) are deferred to a follow-up plan.

## Task Dependency Graph

```
 1 (scaffold)
  └─ 2 (shared/types.ts)
      └─ 3 (shared/kms-helper.ts)
          └─ 4 (core/flow-log-kms.ts)
              └─ 5 (core/vpc-construct.ts)
                  └─ 6 (core/fleet-stack.ts - VPC only)
              └─ 7 (byo-vpc/rds-construct.ts)
              └─ 8 (byo-vpc/redis-construct.ts)
              └─ 9 (byo-vpc/db-password-secret.ts)
                  └─ 10 (byo-vpc/byo-vpc-construct.ts)
                      └─ 11 (byo-db/ecs-cluster-construct.ts)
                      └─ 12 (byo-db/alb-construct.ts)
                          └─ 13 (byo-db/byo-db-construct.ts)
                          └─ 14 (byo-ecs/iam.ts)
                          └─ 15 (byo-ecs/s3-installers.ts)
                          └─ 16 (byo-ecs/app-logs.ts)
                          └─ 17 (byo-ecs/private-key-secret.ts)
                          └─ 18 (byo-ecs/byo-ecs-construct.ts)
                              └─ 19 (bin/fleet.ts + FleetStack wiring)
```

## Build / Test

Each task includes "verify" instructions. At the end of every task, run:
```bash
cd /Users/leonxu/Desktop/fleetdm/fleet-cdk/
npm run build
```
Fix any compilation errors before marking the task complete.

When `cdk.json` and `bin/fleet.ts` are wired (task 19), also run:
```bash
npx cdk synth
```

---

## Task 1 — Repo Scaffold

**Directory:** `/Users/leonxu/Desktop/fleetdm/fleet-cdk/`

### Steps

1. Create `cdk init` app and strip unwanted files:
```bash
mkdir -p /Users/leonxu/Desktop/fleetdm/fleet-cdk/
cd /Users/leonxu/Desktop/fleetdm/fleet-cdk/
npx cdk init app --language=typescript
```

2. If `cdk init` not available, scaffold manually. Write these files:

**`package.json`**:
```json
{
  "name": "fleet-cdk",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "build": "tsc",
    "watch": "tsc -w",
    "test": "jest",
    "cdk": "cdk"
  },
  "devDependencies": {
    "@types/jest": "^29.5.14",
    "@types/node": "^22.0.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.2.0",
    "typescript": "~5.7.0",
    "aws-cdk": "^2.180.0"
  },
  "dependencies": {
    "aws-cdk-lib": "^2.180.0",
    "constructs": "^10.4.0",
    "source-map-support": "^0.5.21"
  }
}
```

**`tsconfig.json`**:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "declaration": true,
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "inlineSourceMap": true,
    "inlineSources": true,
    "experimentalDecorators": true,
    "strictPropertyInitialization": false,
    "outDir": "lib",
    "rootDir": ".",
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "exclude": ["node_modules", "cdk.out", "lib"]
}
```

**`jest.config.ts`**:
```typescript
import type { Config } from 'jest';
const config: Config = {
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  testMatch: ['**/*.test.ts'],
  transform: { '^.+\\.tsx?$': 'ts-jest' },
};
export default config;
```

**`cdk.json`**:
```json
{
  "app": "npx ts-node bin/fleet.ts",
  "watch": { "include": ["**"], "exclude": ["README.md", "cdk*.json", "**/*.d.ts", "**/*.js", "tsconfig.json", "package*.json", "yarn.lock", "node_modules", "test"] },
  "context": {
    "@aws-cdk/aws-lambda:recognizeLayerVersion": true,
    "@aws-cdk/core:checkSecretUsage": true,
    "@aws-cdk/core:target-partitions": ["aws", "aws-cn"],
    "@aws-cdk-containers/ecs-service-extensions:enableDefaultLogDriver": true,
    "@aws-cdk/aws-ec2:uniqueImdsv2TemplateName": true,
    "@aws-cdk/aws-ecs:arnFormatIncludesClusterName": true,
    "@aws-cdk/aws-iam:minimizePolicies": true,
    "@aws-cdk/core:validateSnapshotRemovalPolicy": true,
    "@aws-cdk/aws-codepipeline:crossAccountKeyAliasStackSafeResourceName": true,
    "@aws-cdk/aws-s3:createDefaultLoggingPolicy": false,
    "@aws-cdk/aws-sns-subscriptions:restrictSqsDescryption": true,
    "@aws-cdk/aws-apigateway:disableCloudWatchRole": true,
    "@aws-cdk/core:enablePartitionLiterals": true,
    "@aws-cdk/aws-events:eventsTargetQueueSameAccount": true,
    "@aws-cdk/aws-ecs:disableExplicitDeploymentControllerForCircuitBreaker": true,
    "@aws-cdk/aws-iam:importedRoleStackSafeDefaultPolicyName": true,
    "@aws-cdk/aws-s3:serverAccessLogsUseBucketPolicy": true,
    "@aws-cdk/aws-route53-patters:useCertificate": true,
    "@aws-cdk/customresources:installLatestAwsSdkDefault": false,
    "@aws-cdk/aws-rds:databaseProxyUniqueResourceName": true,
    "@aws-cdk/aws-codedeploy:removeAlarmsFromDeploymentGroup": true,
    "@aws-cdk/aws-apigateway:authorizerChangeDeploymentLogicalId": true,
    "@aws-cdk/aws-ec2:launchTemplateDefaultUserData": true,
    "@aws-cdk/aws-secretsmanager:useAttachedSecretResourcePolicyForSecretTargetAttachments": true,
    "@aws-cdk/aws-redshift:columnId": true,
    "@aws-cdk/aws-stepfunctions-tasks:enableEmrServicePolicyV2": true,
    "@aws-cdk/aws-cloudfront:defaultSecurityPolicyTLSv1.2_2021": true,
    "@aws-cdk/aws-ec2:restrictDefaultSecurityGroup": true,
    "@aws-cdk/aws-apigateway:requestValidatorUniqueId": true,
    "@aws-cdk/aws-kms:aliasNameRef": true,
    "@aws-cdk/aws-autoscaling:generateLaunchTemplateInsteadOfLaunchConfig": true,
    "@aws-cdk/core:includePrefixInUniqueNameGeneration": true,
    "@aws-cdk/aws-efs:denyAnonymousAccess": true,
    "@aws-cdk/aws-opensearchservice:enableOpensearchMultiAzWithStandby": true,
    "@aws-cdk/aws-lambda-nodejs:useLatestRuntimeVersion": true,
    "@aws-cdk/aws-efs:mountTargetOrderInsensitiveLogicalId": true,
    "@aws-cdk/aws-rds:auroraClusterChangeScopeOfInstanceParameterGroupWithEachParameters": true,
    "@aws-cdk/aws-appsync:useArnForSourceApiAssociationIdentifier": true,
    "@aws-cdk/aws-rds:preventRenderingDeprecatedCredentials": true,
    "@aws-cdk/aws-codepipeline-actions:useNewDefaultBranchForCodeCommitSource": true,
    "@aws-cdk/aws-cloudwatch-actions:changeLambdaPermissionLogicalIdForLambdaAction": true,
    "@aws-cdk/aws-codepipeline:crossAccountKeysDefaultValueToFalse": true,
    "@aws-cdk/aws-codepipeline:defaultPipelineTypeToV2": true,
    "@aws-cdk/aws-kms:reduceCrossAccountRegionPolicyScope": true,
    "@aws-cdk/aws-eks:nodegroupNameAttribute": true,
    "@aws-cdk/aws-ec2:ebsDefaultGp3Volume": true,
    "@aws-cdk/aws-ecs:removeDefaultDeploymentAlarm": true
  }
}
```

3. Create the source directory tree:
```bash
mkdir -p src/{core,byo-vpc,byo-db,byo-ecs,shared,addons}
mkdir -p test/{core,byo-vpc,byo-db,byo-ecs}
mkdir -p bin
```

4. Create a minimal `bin/fleet.ts` placeholder:
```typescript
#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
const app = new cdk.App();
```

5. **Verify:** `npm install && npm run build && npm test` — no errors.

6. Commit scaffold (when user asks).

---

## Task 2 — Shared Types (`src/shared/types.ts`)

**File:** `src/shared/types.ts`

Translate the recurring KMS+policy shapes from Terraform into TypeScript interfaces.

### Steps

Write `src/shared/types.ts` containing:

1. **`KmsConfig`** — mirrors the Terraform `*_kms` object pattern:
   - `cmkEnabled?: boolean` (default `false`)
   - `kmsKeyArn?: string`
   - `kmsAlias?: string`
   - `extraKmsPolicies?: iam.PolicyStatement[]`
   (Note: `iam.PolicyStatement` from `aws-cdk-lib/aws-iam` — this requires the import.)

2. **`PolicyStatementShape`** — mirrors the Terraform `locals.kms_base_policy_statements` structure (plain object shape used for building policy documents):
   - `sid: string`
   - `effect: string`
   - `principals: { type: string; identifiers: string[] }`
   - `actions: string[]`
   - `resources: string[]`
   - `conditions?: { test: string; variable: string; values: string[] }[]`

3. **`VpcConfig`** — all fields from `var.vpc` in camelCase:
   - `name`, `cidr`, `azs`, `privateSubnets`, `publicSubnets`, `databaseSubnets`, `elasticacheSubnets`
   - Subnet group flags: `createDatabaseSubnetGroup`, `createDatabaseSubnetRouteTable`, `createElasticacheSubnetGroup`, `createElasticacheSubnetRouteTable`
   - Gateway: `enableVpnGateway`, `oneNatGatewayPerAz`, `singleNatGateway`, `enableNatGateway`
   - DNS: `enableDnsHostnames`, `enableDnsSupport`
   - Flow logs: `enableFlowLog`, `createFlowLogCloudwatchLogGroup`, `createFlowLogCloudwatchIamRole`, `flowLogMaxAggregationInterval`, `flowLogCloudwatchLogGroupNamePrefix`, `flowLogCloudwatchLogGroupNameSuffix`, `flowLogCloudwatchLogGroupRetentionInDays`, `flowLogCloudwatchLogGroupKms: KmsConfig`, `vpcFlowLogTags`
   - Default NACL: `manageDefaultNetworkAcl`, `defaultNetworkAclIngress`, `defaultNetworkAclEgress`
   - Defaults match `variable "vpc"` exactly.

4. **`BaseStackProps`** extending `cdk.StackProps`:
   - All top-level config props: `vpc: VpcConfig`, `certificateArn: string`, `kmsBasePolicy?: PolicyStatementShape[]`, `rdsConfig`, `redisConfig`, `ecsCluster`, `fleetConfig`, `albConfig`, `migrationConfig`
   - Full interfaces for each nested config (see Terraform variables.tf).

**Exact interface list** (derived from `variables.tf`):
- `VpcConfig`
- `KmsConfig`, `PolicyStatementShape`
- `RdsConfig`, `RdsStorageKms`, `RdsPasswordSecretKms`, `RdsObservabilityConfig`, `RdsCloudwatchLogGroupConfig`
- `RedisConfig`, `RedisAtRestKms`, `RedisCloudwatchLogGroupConfig`
- `EcsClusterConfig`, `EcsClusterCloudwatchLogGroupConfig`
- `AlbConfig`, `AlbFleetTargetGroupConfig`, `AlbHealthCheckConfig`
- `FleetConfig`, `FleetDatabaseConfig`, `FleetRedisConfig`, `FleetAwslogsConfig`, `FleetServiceConfig`, `FleetAutoscalingConfig`, `FleetIamConfig`, `FleetIamRoleConfig`, `FleetIamExecutionConfig`, `FleetNetworkingConfig`, `FleetIngressSourcesConfig`, `FleetSoftwareInstallersConfig`, `FleetEphemeralStorageConfig`
- `MigrationConfig`
- `FleetStackProps` — top-level interface extending `StackProps` with the above.

**Verify:**
```bash
npm run build
```

---

## Task 3 — Shared KMS Helper (`src/shared/kms-helper.ts`)

**File:** `src/shared/kms-helper.ts`

Centralizes the repetitive "base policy + extra policies + service statements → CMK + alias" pattern.

### Steps

Write `src/shared/kms-helper.ts`:

1. **`BuildCmkProps`** interface:
   - `description: string`
   - `aliasName: string`
   - `basePolicyStatements: PolicyStatementShape[]` (from `kmsBasePolicy` or default root stmt)
   - `extraPolicyStatements?: PolicyStatementShape[]`
   - `servicePolicyStatements: PolicyStatementShape[]`

2. **`buildCmk(scope, id, props) → kms.Key`** function:
   - Creates `kms.Key` with key policy assembled from: base + extra + service statements
   - Creates `kms.Alias` targeting the key (`alias/${props.aliasName}`)
   - Returns the `kms.Key`
   - Helper function `statementsFromShapes(...arrays)` converts `PolicyStatementShape[]` → `iam.PolicyStatement[]` using `iam.PolicyStatement.fromJson()` (or manual construction mapping sid/effect/principals/actions/resources/conditions).

3. **`resolveCmkKeyArn(cmkEnabled, kmsKeyArn, cmk?) → string | undefined`** utility:
   - Returns the resolved KMS key ARN mirroring the Terraform ternary pattern:
     - If `!cmkEnabled` → `undefined`
     - If `kmsKeyArn` given → `kmsKeyArn`
     - Else → `cmk.keyArn` (the CMK we created)
   - `resolveCmkKeyArn` handles the `null` coalescing.

**Verify:**
```bash
npm run build
```

---

## Task 4 — VPC Flow Log KMS Construct (`src/core/flow-log-kms.ts`)

**File:** `src/core/flow-log-kms.ts`

Mirrors the VPC flow log CMK logic from root `main.tf`.

### Steps

1. **Props interface:** `VpcFlowLogKmsProps`
   - `enableFlowLog: boolean`
   - `createFlowLogCloudwatchLogGroup: boolean`
   - `kmsConfig: KmsConfig`
   - `kmsBasePolicy: PolicyStatementShape[]`

2. **Construct class** `FlowLogKmsConstruct` extending `Construct`:
   - Conditionally creates CMK + alias via `buildCmk()` when:
     `enableFlowLog && createFlowLogCloudwatchLogGroup && cmkEnabled && !kmsKeyArn`
   - Exposes `readonly kmsKeyArn?: string` — resolved via `resolveCmkKeyArn()`
   - Creates the CloudWatch Logs service statement (`logs.<region>.amazonaws.com`).

3. **No CMK created when:** flow logs disabled, log group not created, cmk disabled, or kmsKeyArn provided (caller-managed).

**Verify:** `npm run build`

---

## Task 5 — VPC Construct (`src/core/vpc-construct.ts`)

**File:** `src/core/vpc-construct.ts`

Mirrors `module.vpc` from `main.tf`.

### Steps

1. **Props interface:** `VpcConstructProps`
   - `config: VpcConfig`
   - `flowLogKmsKeyArn?: string` (output from FlowLogKmsConstruct)

2. **Construct class** `VpcConstruct` extending `Construct`:
   - Creates `ec2.Vpc` with `ipAddresses: ec2.IpAddresses.cidr(config.cidr)`
   - 4 `subnetConfiguration` groups:
     - `public`: `config.publicSubnets` → `ec2.SubnetType.PUBLIC`
     - `private` (for ECS/ALB): `config.privateSubnets` → `ec2.SubnetType.PRIVATE_WITH_EGRESS`
     - `database`: `config.databaseSubnets` → `ec2.SubnetType.PRIVATE_ISOLATED`
     - `elasticache`: `config.elasticacheSubnets` → `ec2.SubnetType.PRIVATE_ISOLATED`
   - **Important:** CDK `ec2.Vpc` with 4 groups may require manual subnet creation to match exact CIDRs. If the L2 `subnetConfiguration` approach can't express exact CIDR allocation (each tier gets specific CIDRs), use `ec2.CfnSubnet` directly to mirror the Terraform module's exact subnets.
   - NAT: `natGateways: config.oneNatGatewayPerAz ? config.azs.length : config.singleNatGateway ? 1 : config.enableNatGateway ? config.azs.length : 0`
   - Flow logs: `vpc.addFlowLog(...)` with `kmsKeyId` from props
   - DNS: `enableDnsHostnames`, `enableDnsSupport`
   - Default NACL management skipped (matches Terraform `manage_default_network_acl`)
   
3. **Expose** `readonly vpc: ec2.IVpc`

**Verify:** `npm run build`

---

## Task 6 — FleetStack Skeleton (`src/core/fleet-stack.ts`, partial)

**File:** `src/core/fleet-stack.ts`

Start wiring the top-level stack with just VPC working for now.

### Steps

1. **Props:** `FleetStackProps` from shared types
2. Create `FleetStack` extending `cdk.Stack`:
   ```typescript
   // VPC
   const flowLogKms = new FlowLogKmsConstruct(this, 'FlowLogKms', { ... });
   const vpcConstruct = new VpcConstruct(this, 'Vpc', {
     config: props.vpc,
     flowLogKmsKeyArn: flowLogKms.kmsKeyArn,
   });
   ```
3. Update `bin/fleet.ts`:
   ```typescript
   import { FleetStack } from '../src/core/fleet-stack';
   const app = new cdk.App();
   new FleetStack(app, 'FleetStack', { ... }); // default props
   ```
4. Expose `vpc` as public readonly on stack.

**Verify:** `npm run build && npx cdk synth`

---

## Task 7 — RDS Construct (`src/byo-vpc/rds-construct.ts`)

**File:** `src/byo-vpc/rds-construct.ts`

Mirrors the RDS Aurora module from `byo-vpc/main.tf`.

### Steps

1. **Props:** `RdsConstructProps` with `RdsConfig`, `vpcId`, and KMS-related settings.

2. **Construct class** `RdsConstruct`:
   - Creates `rds.ParameterGroup` (instance-level, `aurora-mysql8.0` family) with dynamic parameters from config
   - Creates `rds.ParameterGroup` (cluster-level, same family)
   - Creates `rds.DatabaseCluster` with engine `DatabaseClusterEngine.AURORA_MYSQL`
   - Uses `serverlessV2MinCapacity`/`serverlessV2MaxCapacity` when `config.serverless`
   - Builds replica instances from `config.replicas`
   - `storageEncrypted: true`, `storageEncryptionKey` from KMS resolution
   - Performance Insights: `performanceInsightEnabled`, `performanceInsightEncryptionKey`, `performanceInsightRetentionPeriod`
   - CloudWatch log exports: `cloudwatchLogsExports`
   - Security group rules from `allowedSecurityGroups` + `allowedCidrBlocks`
   - Mirror all parameters from Terraform's `module.rds` call.

3. **Conditional KMS** via `buildCmk()`/`resolveCmkKeyArn()` for:
   - Storage KMS
   - Password secret KMS (for password secret in Secrets Manager)
   - Observability KMS (PI)
   - CloudWatch log group KMS

4. **Expose:** `cluster`, `clusterEndpoint`, `clusterReaderEndpoint`, `masterPassword`, `storageKmsKeyArn`, `observabilityKmsKeyArn`, `cloudwatchLogGroupKmsKeyArn`, `passwordSecretKmsKeyArn`

**Verify:** `npm run build`

---

## Task 8 — Redis Construct (`src/byo-vpc/redis-construct.ts`)

**File:** `src/byo-vpc/redis-construct.ts`

Mirrors the ElastiCache Redis module from `byo-vpc/main.tf`.

### Steps

1. **Props:** `RedisConstructProps` with `RedisConfig`, `vpcId`, `kmsBasePolicy`

2. **Construct class** `RedisConstruct`:
   - Creates `elasticache.CfnSubnetGroup`
   - Creates `elasticache.CfnReplicationGroup` (no stable L2 for ElastiCache)
   - Parameters: `engine`, `engineVersion`, `replicationGroupId`, `numNodeGroups` (cluster_size), `replicasPerNodeGroup: 0`, `instanceType`, `automaticFailoverEnabled`, `atRestEncryptionEnabled`, `transitEncryptionEnabled`, `cacheSubnetGroupName`, `securityGroupIds`, `tags`
   - `kmsKeyId` from resolved KMS ARN
   - Parameter group via `cacheParameterGroupName` from family + custom params
   - Log delivery configs from `logDeliveryConfiguration`

3. **Conditional KMS** for:
   - At-rest encryption KMS
   - CloudWatch log group KMS (via `buildCmk`)
   - CloudWatch log group `logs.LogGroup` (conditional on `logDeliveryConfiguration` having cloudwatch-logs destinations)

4. **Expose:** `endpoint`, `port`, `replicationGroup`, `atRestKmsKeyArn`, `cloudwatchLogGroupKmsKeyArn`

**Verify:** `npm run build`

---

## Task 9 — DB Password Secret (`src/byo-vpc/db-password-secret.ts`)

**File:** `src/byo-vpc/db-password-secret.ts`

Mirrors `random_password.rds` + `module.secrets-manager-1` from `byo-vpc/main.tf`.

### Steps

1. **Props:** `DbPasswordSecretProps` — `rdsConfig`, `masterPassword: string` (from RDS), `kmsKeyArn?: string`

2. **Construct class** `DbPasswordSecretConstruct`:
   - Creates `secretsmanager.Secret` with:
     - `secretName: ${config.name}-database-password`
     - `secretStringValue: cdk.SecretValue.cfnInit(config.masterPassword)` — actually, since we generate the password with `random_password` in Terraform but use `rds.DatabaseCluster`'s built-in credential in CDK, we get `cluster.secret` from the RDS construct and replicate it as a separate secret (mirroring the Terraform pattern).
     - `encryptionKey: kms.Key.fromKeyArn(...)` or `undefined`
     - `recoveryWindowInDays: 0`
   - The random password generation is handled by RDS's auto-gen; we store the auto-generated password in the secret.

**Alternative:** Skip this construct and use `rds.DatabaseCluster.secret` directly. But the Terraform creates a separate `secrets-manager-1` module storing the password — so for 1:1 parity we replicate it.

3. **Expose:** `secret: secretsmanager.ISecret`, `secretArn: string`

**Verify:** `npm run build`

---

## Task 10 — byo-vpc Construct (`src/byo-vpc/byo-vpc-construct.ts`)

**File:** `src/byo-vpc/byo-vpc-construct.ts`

Composes RDS + Redis + Secrets + parameter groups + KMS keys.

### Steps

1. **Props:** `ByoVpcConstructProps` — `vpcConfig`, `rdsConfig`, `redisConfig`, `ecsCluster`, `fleetConfig`, `albConfig`, `migrationConfig`, `kmsBasePolicy`

2. **Construct class** `ByoVpcConstruct`:
   - Instantiates `RdsConstruct`, `RedisConstruct`, `DbPasswordSecretConstruct`
   - Wires VPC outputs (`vpcId`, `subnets`) into their props
   - Performs the Terraform `merge()` wiring for `fleetConfig.database` and `fleetConfig.redis`:
     - `database.address = rdsConstruct.clusterEndpoint`
     - `database.rrAddress = rdsConstruct.clusterReaderEndpoint`
     - `redis.address = ${redisConstruct.endpoint}:${redisConstruct.port}`
   - Exposes outputs matching Terraform's `byo-vpc/outputs.tf`

3. **Expose:** `byoDbConstruct` (will be ByoDbConstruct once built), `rdsConstruct`, `redisConstruct`, `secrets`, `rdsPasswordSecretKmsKeyArn`

**Verify:** `npm run build`

---

## Task 11 — ECS Cluster Construct (`src/byo-db/ecs-cluster-construct.ts`)

**File:** `src/byo-db/ecs-cluster-construct.ts`

Mirrors `module.cluster` and related KMS from `byo-db/main.tf`.

### Steps

1. **Props:** `EcsClusterConstructProps` — `ecsClusterConfig: EcsClusterConfig`, `vpcId`, `kmsBasePolicy`, `fleetConfig`

2. **Construct class** `EcsClusterConstruct`:
   - Creates `ecs.Cluster` with `vpc: ec2.Vpc.fromLookup(...)` or from props
   - `enableFargateCapacityProviders: true`
   - `containerInsights` from `config.clusterSettings`
   - `executeCommandConfiguration` from `config.clusterConfiguration`
   - Capacity providers: `FARGATE` and `FARGATE_SPOT` with weights (mirror Terraform's fargate_capacity_providers)
   - Autoscaling capacity providers from config.

3. **Conditional KMS:**
   - `fargate_ephemeral_storage_kms`: Creates CMK via `buildCmk()` with Fargate service statements (GenerateDataKeyWithoutPlaintext + CreateGrant with clusterAccount/clusterName conditions)
   - `cluster_cloudwatch_log_group_kms`: Creates CMK with CloudWatch Logs service statement
   - Merges KMS config into `clusterConfiguration` (cloudwatch encryption, managed storage KMS key)

4. **Expose:** `cluster: ecs.ICluster`, `clusterName: string`, `ephemeralStorageKmsKeyArn?`, `cloudwatchLogGroupKmsKeyArn?`

**Verify:** `npm run build`

---

## Task 12 — ALB Construct (`src/byo-db/alb-construct.ts`)

**File:** `src/byo-db/alb-construct.ts`

Mirrors `module.alb` + `aws_security_group.alb` from `byo-db/main.tf`.

### Steps

1. **Props:** `AlbConstructProps` — `albConfig: AlbConfig`, `vpcId`, `certificateArn`

2. **Construct class** `AlbConstruct`:
   - Creates `ec2.SecurityGroup` for ALB with:
     - Ingress: 443 (HTTPS) and 80 (HTTP redirect) from `allowedCidrs`/`allowedIpv6Cidrs`
     - Egress: all traffic from `egressCidrs`/`egressIpv6Cidrs`
   - Creates `elbv2.ApplicationLoadBalancer`:
     - `internetFacing: true` (unless `internal`)
     - Security groups from SG + `securityGroups` config
     - Access logs, idle timeout, deletion protection
   - HTTP listener: port 80, redirect to HTTPS 301
   - HTTPS listener: port 443, with TLS policy, certificate from `certificateArn`, forward to primary TG
   - Target groups: primary `tg-0` from `fleetTargetGroup` + `extraTargetGroups`
   - HTTPS listener rules from `httpsListenerRules` (with condition→action mapping matching Terraform's complex mapping)
   - `xffHeaderProcessingMode`

3. **Expose:** `alb: elbv2.ApplicationLoadBalancer`, `securityGroupId: string`, `targetGroups`, `targetGroupArns`, `targetGroupNames`, `dnsName`, `zoneId`

**Verify:** `npm run build`

---

## Task 13 — byo-db Construct (`src/byo-db/byo-db-construct.ts`)

**File:** `src/byo-db/byo-db-construct.ts`

Composes ECS cluster + ALB + byo-ecs construct.

### Steps

1. **Props:** `ByoDbConstructProps` — `vpcId`, `ecsClusterConfig`, `fleetConfig` (pre-merged with DB/Redis info), `albConfig`, `kmsBasePolicy`

2. **Construct class** `ByoDbConstruct`:
   - Instantiates `EcsClusterConstruct`, `AlbConstruct`, `ByoEcsConstruct`
   - Wires ALB TG ARN into `fleetConfig.loadbalancer.arn`
   - Wires ALB SG into `fleetConfig.networking.ingressSources.securityGroups`
   - Mirror of Terraform's `byo-db/main.tf` locals merge logic

3. **Expose:** `byoEcsConstruct`, `cluster`, `alb`, `ecsService`, `iamRoleArn`, etc. matching `outputs.tf`

**Verify:** `npm run build`

---

## Task 14 — IAM Construct (`src/byo-ecs/iam.ts`)

**File:** `src/byo-ecs/iam.ts`

Mirrors `iam.tf` from `byo-ecs`.

### Steps

1. **Props:** `IamConstructProps` — `fleetConfig`, `taskRoleName` (resolved), `fleetConfig.softwareInstallers.createBucket`, etc.

2. **Construct class** `IamConstruct`:
   - **Assume role policy** for ECS task execution: `ecs-tasks.amazonaws.com`
   - **Task role** (`iam.Role`): conditional on `iamRoleArn == null`
     - Name from `config.iam.role.name`
     - **Task policy** (`iam.Policy`): CloudWatch PutMetricData + conditional private-key/password KMS and secret policies
   - **Execution role** (`iam.Role`): always created
     - Name from `config.iam.execution.name`
     - Managed policy: `AmazonECSTaskExecutionRolePolicy`
     - **Execution policy** (`iam.Policy`): DB password secret access + conditional ECS private key access + conditional KMS policies
   - **Extra policy attachments:** `extraIamPolicies` → role.addManagedPolicy for each, `extraExecutionIamPolicies` → execution role
   - **Software installers policy** (conditional on bucket creation):
     - S3 read/write to `software_installers_bucket`
     - KMS decrypt/describe if kms_key_arn provided (non-module-managed)

3. **Expose:** `taskRole?: iam.IRole`, `executionRole: iam.IRole`, `taskRoleName: string`, `softwareInstallersPolicy`

**Verify:** `npm run build`

---

## Task 15 — S3 Software Installers Construct (`src/byo-ecs/s3-installers.ts`)

**File:** `src/byo-ecs/s3-installers.ts`

Mirrors the S3 bucket resources from `byo-ecs/main.tf`.

### Steps

1. **Props:** `S3InstallersConstructProps` — `softwareInstallersConfig`, `kmsKeyId?`, `kmsKeyArn?`

2. **Construct class** `S3InstallersConstruct`:
   - Creates `s3.Bucket` (conditional on `createBucket`):
     - Bucket name/prefix, force destroy, tags
     - Server-side encryption: `encryption: s3.BucketEncryption.KMS`, `encryptionKey` from KMS
     - Versioning: conditional
     - Lifecycle rule: conditional on `expireNoncurrentVersions`
     - Public access block: `blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL`
     - Bucket policy: DenyNonHTTPS + conditional CloudFront read-only access

3. **Expose:** `bucket?: s3.IBucket`, `bucketName$: string` (resolved), `kmsKeyId$: string` (resolved)

**Verify:** `npm run build`

---

## Task 16 — App Logs Construct (`src/byo-ecs/app-logs.ts`)

**File:** `src/byo-ecs/app-logs.ts`

Mirrors the application CloudWatch log group + KMS from `byo-ecs/main.tf`.

### Steps

1. **Props:** `AppLogsConstructProps` — `awslogsConfig`, `kmsBasePolicy`

2. **Construct class** `AppLogsConstruct`:
   - Conditional KMS via `buildCmk()` when `cmkEnabled && create && !kmsKeyArn`
   - Creates `logs.LogGroup` (conditional on `awslogs.create`): name, retention, kms key
   - Resolves `logGroupName$`, `region$`, `prefix` for container log config

3. **Expose:** `logGroup?: logs.ILogGroup`, `logGroupName$: string`, `logRegion$: string`, `logPrefix: string`, `kmsKeyArn?: string`

**Verify:** `npm run build`

---

## Task 17 — Private Key Secret (`src/byo-ecs/private-key-secret.ts`)

**File:** `src/byo-ecs/private-key-secret.ts`

Mirrors `random_password.fleet_server_private_key` + `aws_secretsmanager_secret.*` + `aws_secretsmanager_secret_version.*` + KMS from `byo-ecs/main.tf`.

### Steps

1. **Props:** `PrivateKeySecretConstructProps` — `fleetConfig`, `kmsBasePolicy`, `executionRoleArn`

2. **Construct class** `PrivateKeySecretConstruct`:
   - Conditional creation (only when `privateKeySecretArn == null`)
   - Conditional KMS via `buildCmk()` when `cmkEnabled && !kmsKeyArn`
   - Creates `secretsmanager.Secret` with generated password (`generateSecretString`)
   - Recovery window: 0 days, create_before_destroy lifecycle

3. **Expose:** `secret?: secretsmanager.ISecret`, `secretArn: string`, `kmsKeyArn?: string`

**Verify:** `npm run build`

---

## Task 18 — byo-ecs Construct (`src/byo-ecs/byo-ecs-construct.ts`)

**File:** `src/byo-ecs/byo-ecs-construct.ts`

Mirrors `byo-ecs/main.tf` composing task definition, service, autoscaling, and all sub-constructs.

### Steps

1. **Props:** `ByoEcsConstructProps` — `fleetConfig` (fully merged), `ecsClusterName`, `vpcId`, `kmsBasePolicy`

2. **Construct class** `ByoEcsConstruct`:
   - Instantiates `IamConstruct`, `S3InstallersConstruct`, `AppLogsConstruct`, `PrivateKeySecretConstruct`
   - **Task definition:**
     - Creates `ecs.FargateTaskDefinition` with:
       - `cpu`/`memory` from config
       - `taskRole` from IAM construct
       - `executionRole` from IAM construct
       - `ephemeralStorageSize` (conditional)
     - `addContainer('fleet', ...)`:
       - Image from config, port 8080, environment variables (DB, Redis, S3, TLS, private key ARN if IAM delivery), secrets (password from ARN, private key if ECS delivery), log config from AppLogs, ulimits, mount points, dependsOn, repository credentials
       - Sidecars: `addContainer(...)` for each sidecar in `config.sidecars`
     - Volumes from config
   - **ECS Service:**
     - Creates `ecs.FargateService`:
       - Service name, cluster, task definition, desired count 1
       - Min/max health percent: 100/200
       - Health check grace period: 30
       - `assignPublicIp`, `securityGroups`, `vpcSubnets` from `networking`
       - `loadBalancers`: primary TG + `extraLoadBalancers`
   - **Autoscaling:**
     - `service.autoScaleTaskCount({ minCapacity, maxCapacity })`
     - `.scaleOnMemoryUtilization('MemoryScaling', { targetUtilizationPercent })`
     - `.scaleOnCpuUtilization('CpuScaling', { targetUtilizationPercent })`
   - **Security group** (conditional on `networking.securityGroups == null`):
     - Ingress: 8080/TCP from `ingressSources`
     - Egress: all traffic

3. **Expose:** `service: ecs.FargateService`, `taskDefinition: ecs.FargateTaskDefinition`, `iamRoleArn: string`, `executionIamRoleArn: string`, `loggingConfig`, `securityGroups: string[]`, `softwareInstallersConfig`, `fleetServerPrivateKeySecretArn`, matching `outputs.tf`

**Verify:** `npm run build`

---

## Task 19 — bin/fleet.ts + FleetStack Full Wiring

**Files:** `bin/fleet.ts`, `src/core/fleet-stack.ts`

Complete the top-level stack wiring all constructs together.

### Steps

1. **Update `src/core/fleet-stack.ts`:**
   - Instantiate `FlowLogKmsConstruct`, `VpcConstruct` (as before)
   - Wire VPC outputs → `ByoVpcConstruct`:
     - `vpcConfig: { vpcId: vpcConstruct.vpc.vpcId, networking: { subnets: vpcConstruct.vpc.privateSubnets.map(...) } }`
     - `rdsConfig.subnets = vpcConstruct.vpc.databaseSubnets`
     - `redisConfig.subnets = vpcConstruct.vpc.elasticacheSubnets`
     - `redisConfig.allowedCidrs = vpcConstruct.vpc.privateSubnets.map(s => s.ipv4CidrBlock)`
     - `redisConfig.elasticacheSubnetGroupName = ...`
     - `redisConfig.availabilityZones = props.vpc.azs`
     - `albConfig.subnets = vpcConstruct.vpc.publicSubnets`
     - `albConfig.certificateArn = props.certificateArn`
   - Instantiate `ByoVpcConstruct`
   - Expose all constructs as public readonly

2. **Update `bin/fleet.ts`:**
   - Create `cdk.App`
   - Create `FleetStack` with full `FleetStackProps` (using Terraform defaults)
   - `cdk.Tags.of(app).add('Source', 'fleet-cdk')` (or similar)

3. **Verify:**
```bash
npm run build
npx cdk synth
```
   - Confirm CloudFormation template output contains all expected resources: VPC, RDS cluster, Redis, ECS cluster, ALB, ECS task def, service, IAM roles, S3 bucket, CloudWatch log groups, KMS keys, autoscaling

4. **Optional:** Write a snapshot test at `test/core/fleet-stack.test.ts`:
   - `Template.fromStack(fleetStack)` → matchCount assertions for key resources
