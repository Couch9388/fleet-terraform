resource "random_password" "private_key" {
  length  = 32
  special = false
}

locals {
  # --------------------------------------------------------------------------
  # Image parsing — supports Docker Hub and DigitalOcean Container Registry
  #
  # Accepted formats for var.fleet_config.image_tag:
  #   "fleetdm/fleet:v4.90.0"                           → Docker Hub (official)
  #   "your-org/your-image:v1.0.0"                      → Docker Hub (custom)
  #   "registry.digitalocean.com/<registry>/<repo>:tag" → DOCR
  # --------------------------------------------------------------------------
  image_tag_parts   = split(":", var.fleet_config.image_tag)
  image_name_part   = local.image_tag_parts[0]
  image_tag_part    = length(local.image_tag_parts) > 1 ? local.image_tag_parts[length(local.image_tag_parts) - 1] : "latest"
  image_segments    = split("/", local.image_name_part)
  image_is_docr     = local.image_segments[0] == "registry.digitalocean.com"
  image_repository  = local.image_segments[length(local.image_segments) - 1]
  image_dh_registry = join("/", slice(local.image_segments, 0, length(local.image_segments) - 1))

  base_env_vars = {
    FLEET_MYSQL_PROTOCOL = "tcp"
    FLEET_MYSQL_ADDRESS  = "${local.mysql_host}:${local.mysql_port}"
    FLEET_MYSQL_USERNAME = local.mysql_user
    FLEET_MYSQL_DATABASE = local.mysql_database
    FLEET_MYSQL_PASSWORD = local.mysql_password

    FLEET_SERVER_PRIVATE_KEY = random_password.private_key.result

    FLEET_S3_SOFTWARE_INSTALLERS_BUCKET              = digitalocean_spaces_bucket.software_installers.name
    FLEET_S3_SOFTWARE_INSTALLERS_ENDPOINT_URL        = "https://${digitalocean_spaces_bucket.software_installers.endpoint}"
    FLEET_S3_SOFTWARE_INSTALLERS_REGION              = var.region
    FLEET_S3_SOFTWARE_INSTALLERS_FORCE_S3_PATH_STYLE = "false"

    FLEET_LOGGING_JSON  = "true"
    FLEET_LOGGING_DEBUG = tostring(var.fleet_config.debug_logging)
    FLEET_SERVER_TLS    = "false"
    FLEET_SERVER_SERVER = "true"
  }

  # Redis env vars — only included when cache is enabled
  redis_env_vars = local.cache_enabled ? {
    FLEET_REDIS_ADDRESS  = "${local.cache_host}:${local.cache_port}"
    FLEET_REDIS_USE_TLS  = "true"
    FLEET_REDIS_PASSWORD = local.cache_password
  } : {}

  # Merge all env vars
  fleet_env_vars = merge(local.base_env_vars, local.redis_env_vars, var.fleet_config.extra_env_vars)
}

resource "digitalocean_app" "fleet" {
  spec {
    name   = "${var.prefix}-app"
    region = var.region

    # Custom domain
    domain {
      name = var.domain_name
      type = "PRIMARY"
      zone = local.zone_name
    }

    # VPC
    vpc {
      id = digitalocean_vpc.fleet.id
    }

    # Fleet service
    service {
      name               = "fleet"
      instance_count     = var.fleet_config.instance_count
      instance_size_slug = var.fleet_config.instance_size_slug
      http_port          = 8080

      image {
        registry_type        = local.image_is_docr ? "DOCR" : "DOCKER_HUB"
        registry             = local.image_is_docr ? null : local.image_dh_registry
        repository           = local.image_repository
        tag                  = local.image_tag_part
        registry_credentials = var.fleet_config.image_registry_credentials

        # Auto-deploy on push is only supported for DOCR
        dynamic "deploy_on_push" {
          for_each = local.image_is_docr && var.fleet_config.image_deploy_on_push ? [1] : []
          content {
            enabled = true
          }
        }
      }

      health_check {
        http_path             = "/healthz"
        initial_delay_seconds = 30
        period_seconds        = 30
        timeout_seconds       = 5
        success_threshold     = 1
        failure_threshold     = 3
      }

      dynamic "env" {
        for_each = local.fleet_env_vars
        content {
          key   = env.key
          value = env.value
          type  = "GENERAL"
          scope = "RUN_TIME"
        }
      }

      # License key as a secret (only if provided)
      dynamic "env" {
        for_each = var.fleet_config.license_key != null ? { FLEET_LICENSE_KEY = var.fleet_config.license_key } : {}
        content {
          key   = env.key
          value = env.value
          type  = "SECRET"
          scope = "RUN_TIME"
        }
      }
    }

    # Migration job — runs before each deployment
    dynamic "job" {
      for_each = var.fleet_config.exec_migration ? [1] : []
      content {
        name               = "fleet-migration"
        kind               = "PRE_DEPLOY"
        instance_count     = 1
        instance_size_slug = var.fleet_config.instance_size_slug

        image {
          registry_type        = local.image_is_docr ? "DOCR" : "DOCKER_HUB"
          registry             = local.image_is_docr ? null : local.image_dh_registry
          repository           = local.image_repository
          tag                  = local.image_tag_part
          registry_credentials = var.fleet_config.image_registry_credentials
        }

        run_command = "fleet prepare db --no-prompt=true"

        dynamic "env" {
          for_each = local.fleet_env_vars
          content {
            key   = env.key
            value = env.value
            type  = "GENERAL"
            scope = "RUN_TIME"
          }
        }

        dynamic "env" {
          for_each = var.fleet_config.license_key != null ? { FLEET_LICENSE_KEY = var.fleet_config.license_key } : {}
          content {
            key   = env.key
            value = env.value
            type  = "SECRET"
            scope = "RUN_TIME"
          }
        }
      }
    }

    # Deployment alerts
    alert {
      rule = "DEPLOYMENT_FAILED"
    }

    alert {
      rule = "DOMAIN_FAILED"
    }
  }

  depends_on = [
    digitalocean_spaces_bucket.software_installers,
  ]
}
