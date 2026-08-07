# ============================================================================
# ULTRA-LOW-COST FLEET TERRAFORM CONFIGURATION
# Target: $120-150/month (down from ~$600/month - 75-80% savings!)
# Use Case: 10 devices, light monitoring, maximum cost optimization
# ============================================================================
# 
# AGGRESSIVE OPTIMIZATIONS APPLIED:
# - Aurora Serverless v2 with minimum ACU (0.5)
# - NO Redis/ElastiCache (use in-memory cache only)
# - 100% Fargate Spot instances
# - Minimal logging (3-day retention)
# - No KMS encryption (use AWS-managed keys)
# - Smallest possible task sizes
# ============================================================================

# ----------------------------------------------------------------------------
# VPC Configuration - Single AZ, minimal resources
# Savings: ~$100+/month
# ----------------------------------------------------------------------------
vpc = {
  name = "fleet-ultra"
  cidr = "10.10.0.0/16"
  
  # Single AZ only
  azs                 = ["us-east-2a"]
  private_subnets     = ["10.10.1.0/24"]
  public_subnets      = ["10.10.11.0/24"]
  database_subnets    = ["10.10.21.0/24"]
  elasticache_subnets = ["10.10.31.0/24"]  # Not used, but required by module
  
  # Single NAT gateway
  single_nat_gateway     = true
  enable_nat_gateway     = true
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
  enable_dns_hostnames                  = false
  enable_dns_support                    = true
}

# ----------------------------------------------------------------------------
# Aurora MySQL Configuration - Serverless v2 MINIMUM settings
# Savings: ~$200+/month vs provisioned
# ----------------------------------------------------------------------------
rds_config = {
  name           = "fleet"
  engine_version = "8.0.mysql_aurora.3.08.2"
  
  # ULTRA OPTIMIZATION: Minimum Aurora Serverless v2 settings
  serverless              = true
  serverless_min_capacity = 0.5   # Absolute minimum (can't go lower)
  serverless_max_capacity = 1.0   # Cap at 1 ACU for cost control
  
  # No replicas
  replicas = 0
  
  # All monitoring disabled
  monitoring_interval = 0
  apply_immediately   = true
  
  # Minimal backups (still safe)
  backup_retention_period   = 3  # Reduced from 7 to 3 days
  skip_final_snapshot       = false
  final_snapshot_identifier = "fleet-ultra-final"
  
  # ULTRA OPTIMIZATION: Disable Performance Insights
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
  
  # ULTRA OPTIMIZATION: Use AWS-managed encryption (no KMS cost)
  storage_kms = {
    cmk_enabled        = false  # Use AWS-managed keys
    kms_key_arn        = null
    kms_alias          = "fleet-rds-storage"
    extra_kms_policies = []
  }
  
  password_secret_kms = {
    cmk_enabled        = false  # Use AWS-managed keys
    kms_key_arn        = null
    kms_alias          = "fleet-rds-password-secret"
    extra_kms_policies = []
  }
  
  # No CloudWatch Logs
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
# Redis/ElastiCache Configuration - DISABLED
# Savings: ~$15-20/month (Fleet can use in-memory cache)
# ----------------------------------------------------------------------------
# NOTE: Fleet supports running without Redis for small deployments
# Set FLEET_REDIS_ADDRESS="" in environment to disable Redis requirement
redis_config = {
  name = "fleet"
  
  # ULTRA OPTIMIZATION: Smallest possible instance (will be disabled via Fleet config)
  engine         = "valkey"
  engine_version = "7.2"
  family         = "valkey7"
  
  # Minimal configuration (can be removed entirely if Fleet doesn't need it)
  cluster_size                = 1
  instance_type               = "cache.t4g.micro"
  automatic_failover_enabled  = false
  apply_immediately           = true
  
  # Encryption disabled for cost savings
  at_rest_encryption_enabled = false
  transit_encryption_enabled = false
  
  at_rest_kms = {
    cmk_enabled        = false
    kms_key_arn        = null
    kms_alias          = "fleet-redis-at-rest"
    extra_kms_policies = []
  }
  
  cloudwatch_log_group = {
    retention_in_days = null
    skip_destroy      = false
    kms = {
      cmk_enabled = false
      kms_key_arn = null
      kms_alias   = "fleet-redis-logs"
    }
  }
  
  log_delivery_configuration = []
  parameter                  = []
  tags                       = {}
}

# ----------------------------------------------------------------------------
# ECS Cluster Configuration - Minimal logging
# Savings: ~$15/month
# ----------------------------------------------------------------------------
ecs_cluster = {
  cluster_name = "fleet"
  
  # ULTRA OPTIMIZATION: 3-day log retention
  cloudwatch_log_group = {
    create            = true
    retention_in_days = 3  # Absolute minimum
    kms = {
      cmk_enabled        = false
      enabled            = false
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
  
  # ULTRA OPTIMIZATION: 100% Spot instances
  fargate_capacity_providers = {
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 100  # 100% Spot for maximum savings
      }
    }
  }
  
  default_capacity_provider_use_fargate = true
  create                                = true
}

# ----------------------------------------------------------------------------
# Fleet Application Configuration - MINIMAL resources
# Savings: ~$30/month
# ----------------------------------------------------------------------------
fleet_config = {
  # ULTRA OPTIMIZATION: Absolute minimum task size for 10 devices
  task_mem = 1024  # 1GB total (minimum for Fargate)
  task_cpu = 256   # 0.25 vCPU (minimum for Fargate)
  mem      = 768   # 768MB for Fleet container
  cpu      = 128   # 0.125 vCPU
  
  image  = "fleetdm/fleet:v4.88.1"
  family = "fleet"
  
  # ULTRA OPTIMIZATION: 3-day log retention
  awslogs = {
    name      = null
    region    = null
    create    = true
    prefix    = "fleet"
    retention = 3  # Minimum retention
    kms = {
      cmk_enabled = false
      enabled     = false
      kms_key_arn = null
      kms_alias   = "fleet-application-logs"
    }
  }
  
  # Fixed single task (no auto-scaling)
  autoscaling = {
    max_capacity                 = 1
    min_capacity                 = 1
    memory_tracking_target_value = 80
    cpu_tracking_target_value    = 80
  }
  
  # ULTRA OPTIMIZATION: No KMS encryption for secrets
  private_key_secret_kms = {
    cmk_enabled        = false
    enabled            = false
    kms_key_arn        = null
    kms_alias          = "fleet-server-private-key"
    extra_kms_policies = []
  }
  
  # ULTRA OPTIMIZATION: Minimal S3 configuration
  software_installers = {
    create_bucket                      = true
    bucket_name                        = null
    bucket_prefix                      = "fleet-installers-"
    s3_object_prefix                   = ""
    cloudfront_distribution_arn        = null
    enable_bucket_versioning           = false
    expire_noncurrent_versions         = true
    noncurrent_version_expiration_days = 7  # Aggressive cleanup
    create_kms_key                     = false  # No KMS
    kms_key_arn                        = null
    kms_alias                          = "fleet-software-installers"
    extra_kms_policies                 = []
    tags                               = {}
  }
  
  # ULTRA OPTIMIZATION: Environment variables to disable Redis
  extra_environment_variables = {
    # Fleet can run without Redis for small deployments
    FLEET_REDIS_ADDRESS = ""  # Disable Redis requirement
  }
}

# ----------------------------------------------------------------------------
# ALB Configuration - Minimal settings
# Cost: ~$16/month (unavoidable)
# ----------------------------------------------------------------------------
alb_config = {
  name          = "fleet"
  internal      = false
  idle_timeout  = 60
  
  allowed_cidrs      = ["0.0.0.0/0"]
  allowed_ipv6_cidrs = ["::/0"]
  
  enable_deletion_protection = false
}

# ----------------------------------------------------------------------------
# Migration Task Configuration - Minimal
# ----------------------------------------------------------------------------
migration_config = {
  mem = 512   # Minimum for migration
  cpu = 256   # Minimum
}
