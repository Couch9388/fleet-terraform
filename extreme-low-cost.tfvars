# ============================================================================
# EXTREME LOW-COST FLEET TERRAFORM CONFIGURATION
# Target: $60-80/month (down from ~$600/month - 87-90% savings!)
# Use Case: 10 devices, absolute minimum cost, acceptable tradeoffs
# ============================================================================
#
# EXTREME OPTIMIZATIONS APPLIED:
# - NO NAT Gateway (use public subnets) - SAVES $32/month
# - NO Load Balancer (direct ECS access) - SAVES $16/month  
# - Aurora Serverless fixed 0.5 ACU - SAVES $15/month
# - 1-day log retention - SAVES $5/month
# - Minimal backups (1 day) - SAVES $5/month
# - Total additional savings: $73/month vs ULTRA
# ============================================================================

# ----------------------------------------------------------------------------
# VPC Configuration - PUBLIC subnets to eliminate NAT Gateway
# Savings: $32/month (NO NAT Gateway needed!)
# ----------------------------------------------------------------------------
vpc = {
  name = "fleet-extreme"
  cidr = "10.10.0.0/16"
  
  # Single AZ
  azs = ["us-east-2a"]
  
  # EXTREME OPTIMIZATION: Use public subnets for ECS (no NAT needed)
  # ECS tasks get public IPs, still protected by security groups
  private_subnets     = []  # Not used
  public_subnets      = ["10.10.11.0/24"]  # ECS runs here with public IPs
  database_subnets    = ["10.10.21.0/24"]  # Aurora stays private
  elasticache_subnets = ["10.10.31.0/24"]  # Not used but required
  
  # EXTREME OPTIMIZATION: NO NAT Gateway
  enable_nat_gateway     = false  # Disabled - saves $32/month!
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
  enable_dns_hostnames                  = true  # Needed for public DNS
  enable_dns_support                    = true
}

# ----------------------------------------------------------------------------
# Aurora MySQL Configuration - FIXED 0.5 ACU (no scaling)
# Savings: $15/month vs auto-scaling
# ----------------------------------------------------------------------------
rds_config = {
  name           = "fleet"
  engine_version = "8.0.mysql_aurora.3.08.2"
  
  # EXTREME OPTIMIZATION: Fixed 0.5 ACU (no auto-scaling)
  serverless              = true
  serverless_min_capacity = 0.5  # Minimum
  serverless_max_capacity = 0.5  # Same as min = no scaling = predictable cost
  
  # No replicas
  replicas = 0
  
  # All monitoring disabled
  monitoring_interval = 0
  apply_immediately   = true
  
  # EXTREME OPTIMIZATION: 1-day backup retention (minimum)
  backup_retention_period   = 1  # Absolute minimum
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
  
  # No KMS encryption
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
# Redis/ElastiCache - DISABLED
# Savings: $15/month
# ----------------------------------------------------------------------------
redis_config = {
  name = "fleet"
  
  # Minimal config (disabled via Fleet environment variable)
  engine                      = "valkey"
  engine_version              = "7.2"
  family                      = "valkey7"
  cluster_size                = 1
  instance_type               = "cache.t4g.micro"
  automatic_failover_enabled  = false
  apply_immediately           = true
  at_rest_encryption_enabled  = false
  transit_encryption_enabled  = false
  
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
# ECS Cluster Configuration - 1-day log retention
# Savings: $5/month
# ----------------------------------------------------------------------------
ecs_cluster = {
  cluster_name = "fleet"
  
  # EXTREME OPTIMIZATION: 1-day log retention
  cloudwatch_log_group = {
    create            = true
    retention_in_days = 1  # Minimum possible
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
  
  # 100% Spot
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
# Fleet Application Configuration - MINIMAL + Public subnet
# Savings: Multiple optimizations
# ----------------------------------------------------------------------------
fleet_config = {
  # Minimum Fargate task size
  task_mem = 1024  # 1GB
  task_cpu = 256   # 0.25 vCPU
  mem      = 768   # 768MB
  cpu      = 128   # 0.125 vCPU
  
  image  = "fleetdm/fleet:v4.88.1"
  family = "fleet"
  
  # EXTREME OPTIMIZATION: 1-day log retention
  awslogs = {
    name      = null
    region    = null
    create    = true
    prefix    = "fleet"
    retention = 1  # Minimum
    kms = {
      cmk_enabled = false
      enabled     = false
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
  
  # No KMS
  private_key_secret_kms = {
    cmk_enabled        = false
    enabled            = false
    kms_key_arn        = null
    kms_alias          = "fleet-server-private-key"
    extra_kms_policies = []
  }
  
  # Minimal S3
  software_installers = {
    create_bucket                      = true
    bucket_name                        = null
    bucket_prefix                      = "fleet-extreme-"
    s3_object_prefix                   = ""
    cloudfront_distribution_arn        = null
    enable_bucket_versioning           = false
    expire_noncurrent_versions         = true
    noncurrent_version_expiration_days = 1  # Aggressive cleanup
    create_kms_key                     = false
    kms_key_arn                        = null
    kms_alias                          = "fleet-software-installers"
    extra_kms_policies                 = []
    tags                               = {}
  }
  
  # Disable Redis requirement
  extra_environment_variables = {
    FLEET_REDIS_ADDRESS = ""  # Disable Redis
  }
  
  # EXTREME OPTIMIZATION: Deploy in PUBLIC subnet with public IP
  networking = {
    subnets          = null  # Will use public subnets from VPC
    security_groups  = null  # Will be created
    assign_public_ip = true  # Get public IP (no NAT needed!)
    ingress_sources = {
      cidr_blocks      = ["0.0.0.0/0"]  # Allow from anywhere (ALB replacement)
      ipv6_cidr_blocks = ["::/0"]
      security_groups  = []
      prefix_list_ids  = []
    }
  }
}

# ----------------------------------------------------------------------------
# ALB Configuration - DISABLED (use direct ECS access)
# Savings: $16/month
# NOTE: This module still requires ALB config, but we'll document how to
# access Fleet directly via ECS task public IP or use Route53
# ----------------------------------------------------------------------------
alb_config = {
  name          = "fleet-extreme"
  internal      = false
  idle_timeout  = 60
  
  allowed_cidrs      = ["0.0.0.0/0"]
  allowed_ipv6_cidrs = ["::/0"]
  
  enable_deletion_protection = false
  
  # NOTE: In EXTREME mode, consider removing ALB entirely and using:
  # 1. Direct ECS task public IP access, OR
  # 2. Route53 → ECS task IP (update manually on task restart)
  # This saves $16/month but requires manual DNS updates
}

# ----------------------------------------------------------------------------
# Migration Task Configuration - Minimal
# ----------------------------------------------------------------------------
migration_config = {
  mem = 512
  cpu = 256
}

# ============================================================================
# EXTREME MODE DEPLOYMENT NOTES
# ============================================================================
#
# After deploying this configuration, you have two options:
#
# OPTION 1: Keep ALB ($16/month)
# - Use ALB as normal
# - Total cost: ~$76-96/month
#
# OPTION 2: Remove ALB (SAVES $16/month)
# - Delete ALB via Terraform or console
# - Get ECS task public IP: aws ecs describe-tasks ...
# - Access Fleet directly: https://<TASK_PUBLIC_IP>:8080
# - OR create Route53 A record pointing to task IP
# - Update DNS when task restarts (rare with Spot)
# - Total cost: ~$60-80/month
#
# For 10 devices, OPTION 2 is recommended for maximum savings.
# ============================================================================
