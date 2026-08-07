# ============================================================================
# COST-OPTIMIZED FLEET TERRAFORM CONFIGURATION
# Target: $200-220/month (down from ~$600/month)
# Use Case: 10 devices, light monitoring, production-safe single-AZ
# ============================================================================

# ----------------------------------------------------------------------------
# VPC Configuration - Single AZ for cost savings
# Savings: ~$100+/month (reduced NAT gateways, cross-AZ traffic)
# ----------------------------------------------------------------------------
vpc = {
  name                = "fleet-optimized"
  cidr                = "10.10.0.0/16"
  
  # COST OPTIMIZATION: Use only 1 AZ instead of 3
  azs                 = ["us-east-2a"]
  private_subnets     = ["10.10.1.0/24"]
  public_subnets      = ["10.10.11.0/24"]
  database_subnets    = ["10.10.21.0/24"]
  elasticache_subnets = ["10.10.31.0/24"]
  
  # Single NAT gateway (saves $32/month per additional NAT)
  single_nat_gateway     = true
  enable_nat_gateway     = true
  one_nat_gateway_per_az = false
  
  # Disable VPC Flow Logs (saves ~$10-20/month)
  enable_flow_log                      = false
  create_flow_log_cloudwatch_log_group = false
  create_flow_log_cloudwatch_iam_role  = false
  
  # Standard settings
  create_database_subnet_group      = false
  create_database_subnet_route_table = true
  create_elasticache_subnet_group   = true
  create_elasticache_subnet_route_table = true
  enable_vpn_gateway                = false
  enable_dns_hostnames              = false
  enable_dns_support                = true
}

# ----------------------------------------------------------------------------
# Aurora MySQL Configuration - Serverless v2 for auto-scaling
# Savings: ~$150-180/month vs provisioned db.t4g.large
# ----------------------------------------------------------------------------
rds_config = {
  name           = "fleet"
  engine_version = "8.0.mysql_aurora.3.08.2"
  
  # COST OPTIMIZATION: Use Aurora Serverless v2
  serverless              = true
  serverless_min_capacity = 0.5   # Scales down to 0.5 ACU during idle (~$0.06/hr)
  serverless_max_capacity = 2     # Max 2 ACU for 10 devices (~$0.24/hr)
  
  # COST OPTIMIZATION: No replicas needed for 10 devices
  replicas = 0
  
  # Disable expensive features for cost savings
  monitoring_interval             = 0     # Disable enhanced monitoring (saves ~$5/month)
  apply_immediately               = true
  backup_retention_period         = 7     # Keep default 7 days
  skip_final_snapshot             = false # Safety: keep final snapshot
  final_snapshot_identifier       = "fleet-final-snapshot"
  
  # COST OPTIMIZATION: Disable Performance Insights (saves ~$10/month)
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
  
  # Enable KMS encryption as required
  storage_kms = {
    cmk_enabled        = true
    kms_key_arn        = null
    kms_alias          = "fleet-rds-storage"
    extra_kms_policies = []
  }
  
  password_secret_kms = {
    cmk_enabled        = true
    kms_key_arn        = null
    kms_alias          = "fleet-rds-password-secret"
    extra_kms_policies = []
  }
  
  # Disable CloudWatch Logs export (saves ~$5/month)
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
# Redis/ElastiCache Configuration - Single node
# Savings: ~$25/month (1 node vs 2 nodes)
# ----------------------------------------------------------------------------
redis_config = {
  name                 = "fleet"
  engine               = "valkey"        # 20% cheaper than Redis
  engine_version       = "7.2"
  family               = "valkey7"
  
  # COST OPTIMIZATION: Single node (no HA, acceptable for 10 devices)
  cluster_size                = 1
  automatic_failover_enabled  = false
  
  # Use smallest instance type
  instance_type        = "cache.t4g.micro"  # Even smaller than t4g.small
  apply_immediately    = true
  
  # Enable encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  at_rest_kms = {
    cmk_enabled        = true
    kms_key_arn        = null
    kms_alias          = "fleet-redis-at-rest"
    extra_kms_policies = []
  }
  
  # Disable CloudWatch Logs (saves ~$3/month)
  cloudwatch_log_group = {
    retention_in_days = null
    skip_destroy      = false
    kms = {
      cmk_enabled        = false
      kms_key_arn        = null
      kms_alias          = "fleet-redis-logs"
      extra_kms_policies = []
    }
  }
  
  log_delivery_configuration = []
  parameter                  = []
  tags                       = {}
}

# ----------------------------------------------------------------------------
# ECS Cluster Configuration - Minimal logging
# Savings: ~$10/month (reduced log retention)
# ----------------------------------------------------------------------------
ecs_cluster = {
  cluster_name = "fleet"
  
  # COST OPTIMIZATION: Reduce log retention to 7 days
  cloudwatch_log_group = {
    create            = true
    retention_in_days = 7  # Down from 30 days
    kms = {
      cmk_enabled        = false  # Disable KMS for logs to save
      enabled            = false
      kms_key_arn        = null
      kms_alias          = "fleet-ecs-cluster-logs"
      extra_kms_policies = []
    }
  }
  
  # Disable Container Insights (saves ~$5-10/month)
  cluster_settings = {
    name  = "containerInsights"
    value = "disabled"
  }
  
  # COST OPTIMIZATION: Aggressive Spot usage (70% Spot, 30% on-demand)
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 30  # 30% on-demand for stability
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 70  # 70% Spot for cost savings (50-70% discount)
      }
    }
  }
  
  default_capacity_provider_use_fargate = true
  create                                = true
}

# ----------------------------------------------------------------------------
# Fleet Application Configuration - Minimal resources
# Savings: ~$20/month (smaller task size, reduced logging)
# ----------------------------------------------------------------------------
fleet_config = {
  # COST OPTIMIZATION: Smaller task size for 10 devices
  task_mem = 2048  # 2GB total task memory
  task_cpu = 512   # 0.5 vCPU
  mem      = 1536  # 1.5GB for Fleet container
  cpu      = 256   # 0.25 vCPU for Fleet container
  
  image  = "fleetdm/fleet:v4.88.1"
  family = "fleet"
  
  # COST OPTIMIZATION: Reduce log retention to 5 days
  awslogs = {
    name      = null
    region    = null
    create    = true
    prefix    = "fleet"
    retention = 5  # Down from default
    kms = {
      cmk_enabled        = false  # Disable KMS for app logs
      enabled            = false
      kms_key_arn        = null
      kms_alias          = "fleet-application-logs"
      extra_kms_policies = []
    }
  }
  
  # COST OPTIMIZATION: Fixed capacity (no auto-scaling for 10 devices)
  autoscaling = {
    max_capacity                 = 1  # Only 1 task needed
    min_capacity                 = 1
    memory_tracking_target_value = 80
    cpu_tracking_target_value    = 80
  }
  
  # Enable KMS for server private key as required
  private_key_secret_kms = {
    cmk_enabled        = true
    enabled            = true
    kms_key_arn        = null
    kms_alias          = "fleet-server-private-key"
    extra_kms_policies = []
  }
  
  # Software installers bucket
  software_installers = {
    create_bucket                      = true
    bucket_name                        = null
    bucket_prefix                      = "fleet-software-installers-"
    s3_object_prefix                   = ""
    cloudfront_distribution_arn        = null
    enable_bucket_versioning           = false
    expire_noncurrent_versions         = true
    noncurrent_version_expiration_days = 30
    create_kms_key                     = true
    kms_key_arn                        = null
    kms_alias                          = "fleet-software-installers"
    extra_kms_policies                 = []
    tags                               = {}
  }
}

# ----------------------------------------------------------------------------
# ALB Configuration - Standard (required, minimal cost impact)
# Cost: ~$16/month (unavoidable)
# ----------------------------------------------------------------------------
alb_config = {
  name          = "fleet"
  internal      = false
  idle_timeout  = 60  # Reduce from 905 to save on connection costs
  
  # Standard security
  allowed_cidrs      = ["0.0.0.0/0"]
  allowed_ipv6_cidrs = ["::/0"]
  
  enable_deletion_protection = false
}

# ----------------------------------------------------------------------------
# Migration Task Configuration - Minimal resources
# ----------------------------------------------------------------------------
migration_config = {
  mem = 1024  # 1GB for migration task
  cpu = 512   # 0.5 vCPU
}
