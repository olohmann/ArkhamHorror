locals {
  name = var.name_prefix

  common_tags = {
    project    = "arkham-horror"
    managed-by = "terraform"
    module     = "azure"
  }

  image = "${data.azurerm_container_registry.lohmannio.login_server}/${var.image_repository}:${var.image_tag}"
}

resource "azurerm_resource_group" "arkham" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# --- Existing ACR holding the app image --------------------------------------
data "azurerm_container_registry" "lohmannio" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group_name
}

# --- User-assigned identity used by the Container App to pull from ACR --------
resource "azurerm_user_assigned_identity" "app" {
  name                = "${local.name}-app-identity"
  resource_group_name = azurerm_resource_group.arkham.name
  location            = azurerm_resource_group.arkham.location
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = data.azurerm_container_registry.lohmannio.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# --- Observability + Container Apps environment ------------------------------
resource "azurerm_log_analytics_workspace" "arkham" {
  name                = "${local.name}-logs"
  resource_group_name = azurerm_resource_group.arkham.name
  location            = azurerm_resource_group.arkham.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_container_app_environment" "arkham" {
  name                       = "${local.name}-env"
  resource_group_name        = azurerm_resource_group.arkham.name
  location                   = azurerm_resource_group.arkham.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.arkham.id
  tags                       = local.common_tags
}
