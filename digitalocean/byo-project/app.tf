resource "random_password" "private_key" {
  length  = 32
  special = false
}

locals {
  fleet_env_vars = merge(var.fleet_config.extra_env_vars, {
    FLEET_MYSQL_PROTOCOL = "tcp"
    FLEET_MYSQL_ADDRESS  = "${digitalocean_database_cluster.mysql.host}:${digitalocean_database_cluster.mysql.port}"
    FLEET_MYSQL_USERNAME = digitalocean_database_user.fleet.name
    FLEET_MYSQL_DATABASE = digitalocean_database_db.fleet.name
    FLEET_MYSQL_PASSWORD = digitalocean_database_user.fleet.password

    FLEET_REDIS_ADDRESS  = "${digitalocean_database_cluster.cache.host}:${digitalocean_database_cluster.cache.port}"
    FLEET_REDIS_USE_TLS  = "true"
    FLEET_REDIS_PASSWORD = digitalocean_database_cluster.cache.password

    FLEET_SERVER_PRIVATE_KEY = random_password.private_key.result

    FLEET_S3_SOFTWARE_INSTALLERS_BUCKET              = digitalocean_spaces_bucket.software_installers.name
    FLEET_S3_SOFTWARE_INSTALLERS_ENDPOINT_URL        = "https://${digitalocean_spaces_bucket.software_installers.endpoint}"
    FLEET_S3_SOFTWARE_INSTALLERS_REGION              = var.region
    FLEET_S3_SOFTWARE_INSTALLERS_FORCE_S3_PATH_STYLE = "false"

    FLEET_LOGGING_JSON   = "true"
    FLEET_LOGGING_DEBUG  = tostring(var.fleet_config.debug_logging)
    FLEET_SERVER_TLS     = "false"
    FLEET_SERVER_SERVER  = "true"
  })
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
        registry_type = "DOCKER_HUB"
        registry      = "fleetdm"
        repository    = "fleet"
        tag           = trimprefix(var.fleet_config.image_tag, "fleetdm/fleet:")
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
          registry_type = "DOCKER_HUB"
          registry      = "fleetdm"
          repository    = "fleet"
          tag           = trimprefix(var.fleet_config.image_tag, "fleetdm/fleet:")
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
    digitalocean_database_cluster.mysql,
    digitalocean_database_cluster.cache,
    digitalocean_spaces_bucket.software_installers,
  ]
}
