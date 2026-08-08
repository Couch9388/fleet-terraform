# ============================================================================
# EXTREME NO-LOGS / NO-ALB FLEET TERRAFORM CONFIGURATION
# Target: $45-55/month (down from ~$600/month - 90%+ savings!)
# Use Case: 10 devices, absolute minimum cost, acceptable tradeoffs
# ============================================================================
#
# WHAT THIS CONFIG REMOVES vs extreme-low-cost.tfvars:
# - ALB entirely (alb_config.enabled = false)        - SAVES ~$16/month
# - ElastiCache entirely (redis_config.enabled = false) - SAVES ~$12/month
# - ALL CloudWatch Logs (cluster + application)      - SAVES ~$3-5/month
#
# ACCESS: Fleet is reached directly via the ECS task's public IP on port 8080
#         (plain HTTP - see DEPLOYMENT-NO-ALB.md for TLS options).
#         Optional: scripts/setup-route53.sh keeps a DNS record in sync.
#
# TRADEOFFS:
# - No TLS termination (plain HTTP on :8080 unless you add certs to Fleet)
# - Task public IP changes on every task restart (use Route53 sync script)
# - No logs for debugging (use scripts/emergency-logging.sh to re-enable)
# ============================================================================

# ----------------------------------------------------------------------------
# VPC Configuration - PUBLIC subnets only, no NAT Gateway
# ----------------------------------------------------------------------------
vpc = {
  name = "fleet-extreme"
  cidr = "10.10.0.0/16"

  # Single AZ
  azs = ["us-east-2a"]

  # ECS tasks run in the public subnet with public IPs (no NAT needed).
  # Leave private_subnets empty so the root module falls back to public.
  private_subnets     = []
  public_subnets      = ["10.10.11.0/24"]
  database_subnets    = ["10.10.21.0/24"] # Aurora stays private
  elasticache_subnets = ["10.10.31.0/24"] # Unused (redis disabled) but required

  # NO NAT Gateway - saves $32/month
  enable_nat_gateway     = false
  single_nat_gateway     = false
  one_nat_gateway_per_az = false

  # All monitoring disabled
  enable_flow_log                      = false
  create_flow_log_cloudwatch_log_group = false
  create_flow_log_cloudwatch_iam_role  = false

  # Standard settings
  create_database_subnet_group          = false
  create_database_subnet_route_table    = true
  create_elasticache_subnet_group       = true
  create_elasticache_subnet_route_table = true
  enable_vpn_gateway                    = false
  enable_dns_hostnames                  = true # Needed for public DNS hostnames
  enable_dns_support                    = true
}

# ----------------------------------------------------------------------------
# Aurora MySQL Configuration - FIXED 0.5 ACU (no scaling)
# ----------------------------------------------------------------------------
rds_config = {
  name           = "fleet"
  engine_version = "8.0.mysql_aurora.3.08.2"

  # 0.5 ACU min, capped at 1.0 ACU max (AWS does not allow max < 1).
  # Idles at 0.5 ACU = ~$36/month baseline; may scale to 1 ACU under load.
  serverless              = true
  serverless_min_capacity = 0.5
  serverless_max_capacity = 1.0

  # No replicas
  replicas = 0

  # All monitoring disabled
  monitoring_interval = 0
  apply_immediately   = true

  # 1-day backup retention (minimum)
  backup_retention_period   = 1
  skip_final_snapshot       = false
  final_snapshot_identifier = "fleet-extreme-final"

  # Disable Performance Insights
  observability = {
    performance_insights_enabled = false
    retention_period             = null
    database_insights_mode       = null
    kms = {
      cmk_enabled        = false
      kms_key_arn        = null
      kms_alias          = "fleet-rds-performance-insights"
      extra_kms_policies = []
    }
  }

  # No KMS CMKs (use AWS-managed keys)
  storage_kms = {
    cmk_enabled        = false
    kms_key_arn        = null
    kms_alias          = "fleet-rds-storage"
    extra_kms_policies = []
  }

  password_secret_kms = {
    cmk_enabled        = false
    kms_key_arn        = null
    kms_alias          = "fleet-rds-password-secret"
    extra_kms_policies = []
  }

  # No RDS CloudWatch Logs export
  enabled_cloudwatch_logs_exports = []
  cloudwatch_log_group = {
    retention_in_days = null
    skip_destroy      = false
    kms = {
      cmk_enabled        = false
      kms_key_arn        = null
      kms_alias          = "fleet-rds-logs"
      extra_kms_policies = []
    }
  }
}

# ----------------------------------------------------------------------------
# Redis/ElastiCache - COMPLETELY REMOVED (not just unused)
# ----------------------------------------------------------------------------
redis_config = {
  enabled = false # No ElastiCache cluster is created at all - saves ~$12/month

  # Remaining fields are ignored when enabled = false, kept for schema shape
  name                       = "fleet"
  engine                     = "valkey"
  engine_version             = "7.2"
  family                     = "valkey7"
  cluster_size               = 1
  instance_type              = "cache.t4g.micro"
  automatic_failover_enabled = false
  apply_immediately          = true
  at_rest_encryption_enabled = false
  transit_encryption_enabled = false
  log_delivery_configuration = []
  parameter                  = []
  tags                       = {}
}

# ----------------------------------------------------------------------------
# ECS Cluster Configuration - NO CloudWatch log group at all
# ----------------------------------------------------------------------------
ecs_cluster = {
  cluster_name = "fleet"

  # NO cluster log group created - saves log ingestion/storage
  cloudwatch_log_group = {
    create            = false
    retention_in_days = null
    kms = {
      cmk_enabled        = false
      kms_key_arn        = null
      kms_alias          = "fleet-ecs-cluster-logs"
      extra_kms_policies = []
    }
  }

  # Container Insights disabled
  cluster_settings = {
    name  = "containerInsights"
    value = "disabled"
  }

  # 100% Fargate Spot
  fargate_capacity_providers = {
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  default_capacity_provider_use_fargate = true
  create                                = true
}

# ----------------------------------------------------------------------------
# Fleet Application Configuration - MINIMAL + public IP + NO logs
# ----------------------------------------------------------------------------
fleet_config = {
  # Minimum Fargate task size
  task_mem = 1024 # 1GB
  task_cpu = 256  # 0.25 vCPU
  mem      = 768  # 768MB
  cpu      = 128  # 0.125 vCPU

  image  = "fleetdm/fleet:v4.88.1"
  family = "fleet"

  # NO application logs: create=false AND name=null removes the
  # logConfiguration from the container definition entirely.
  # Re-enable for debugging with: scripts/emergency-logging.sh
  awslogs = {
    name      = null # null name + create=false => no log driver at all
    region    = null
    create    = false
    prefix    = "fleet"
    retention = null
    kms = {
      cmk_enabled = false
      kms_key_arn = null
      kms_alias   = "fleet-application-logs"
    }
  }

  # Fixed single task
  autoscaling = {
    max_capacity                 = 1
    min_capacity                 = 1
    memory_tracking_target_value = 80
    cpu_tracking_target_value    = 80
  }

  # No KMS for secrets
  private_key_secret_kms = {
    cmk_enabled        = false
    kms_key_arn        = null
    kms_alias          = "fleet-server-private-key"
    extra_kms_policies = []
  }

  # Minimal S3 installers bucket
  software_installers = {
    create_bucket                      = true
    bucket_name                        = null
    bucket_prefix                      = "fleet-extreme-"
    s3_object_prefix                   = ""
    cloudfront_distribution_arn        = null
    enable_bucket_versioning           = false
    expire_noncurrent_versions         = true
    noncurrent_version_expiration_days = 1
    create_kms_key                     = false
    kms_key_arn                        = null
    kms_alias                          = "fleet-software-installers"
    extra_kms_policies                 = []
    tags                               = {}
  }

  # Redis address is injected as "" automatically when redis_config.enabled = false,
  # so Fleet uses in-memory caching. No extra env var needed.

  # Public subnet placement with public IP (root module falls back to public
  # subnets automatically because vpc.private_subnets is empty).
  networking = {
    subnets          = null # Filled by the root module (public subnets)
    security_groups  = null # Module-created security group
    assign_public_ip = true # Get a public IP (no NAT, no ALB)
    ingress_sources = {
      cidr_blocks      = ["0.0.0.0/0"] # Fully open (per requirements)
      ipv6_cidr_blocks = ["::/0"]
      security_groups  = []
      prefix_list_ids  = []
    }
  }
}

# ----------------------------------------------------------------------------
# ALB Configuration - COMPLETELY REMOVED
# ----------------------------------------------------------------------------
alb_config = {
  enabled = false # No ALB is created - saves ~$16/month + no ACM cert needed

  # Remaining fields are ignored when enabled = false
  name                       = "fleet-extreme"
  internal                   = false
  idle_timeout               = 60
  allowed_cidrs              = ["0.0.0.0/0"]
  allowed_ipv6_cidrs         = ["::/0"]
  enable_deletion_protection = false
}

# ----------------------------------------------------------------------------
# Migration Task Configuration - Minimal
# ----------------------------------------------------------------------------
migration_config = {
  mem = 512
  cpu = 256
}

# ============================================================================
# ESTIMATED MONTHLY COST (us-east-2)
# ============================================================================
# Aurora Serverless v2 (0.5 ACU fixed, 24/7)   ~$36.00
# ECS Fargate Spot (256 CPU / 1GB, 1 task)     ~$9-13
# S3 installers bucket                          ~$0.50
# Secrets Manager (2 secrets)                   ~$0.80
# Data transfer (light)                         ~$1.00
# CloudWatch Logs                               $0.00 (disabled)
# ALB                                           $0.00 (removed)
# NAT Gateway                                   $0.00 (removed)
# ElastiCache                                   $0.00 (removed)
# ----------------------------------------------------------------------------
# TOTAL                                        ~$48-52/month
# ============================================================================
