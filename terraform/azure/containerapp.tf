resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

resource "azurerm_container_app" "arkham" {
  name                         = "${local.name}-web"
  resource_group_name          = azurerm_resource_group.arkham.name
  container_app_environment_id = azurerm_container_app_environment.arkham.id
  revision_mode                = "Single"
  tags                         = local.common_tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = data.azurerm_container_registry.lohmannio.login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  secret {
    name  = "database-url"
    value = local.database_url
  }

  secret {
    name  = "jwt-secret"
    value = random_password.jwt_secret.result
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    # Single stateful instance: in-memory game rooms + WebSocket fan-out with
    # no Redis, and no cold-start on scale events.
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "web"
      image  = local.image
      cpu    = var.app_cpu
      memory = var.app_memory

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "PORT"
        value = "3000"
      }
      env {
        name  = "ASSET_HOST"
        value = var.asset_host
      }
      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }
      env {
        name        = "JWT_SECRET"
        secret_name = "jwt-secret"
      }

      # Restart the container if /health stops responding. Generous startup
      # window for the slow-booting Haskell binary.
      startup_probe {
        transport               = "HTTP"
        port                    = 3000
        path                    = "/health"
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 30
      }

      liveness_probe {
        transport               = "HTTP"
        port                    = 3000
        path                    = "/health"
        initial_delay           = 60
        interval_seconds        = 20
        timeout                 = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        transport               = "HTTP"
        port                    = 3000
        path                    = "/health"
        interval_seconds        = 10
        timeout                 = 3
        failure_count_threshold = 3
      }
    }
  }

  depends_on = [azurerm_role_assignment.acr_pull]
}
