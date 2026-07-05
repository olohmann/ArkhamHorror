resource "random_password" "pg_admin" {
  length           = 32
  special          = true
  override_special = "-_"
}

resource "azurerm_postgresql_flexible_server" "arkham" {
  name                          = "${local.name}-pg"
  resource_group_name           = azurerm_resource_group.arkham.name
  location                      = azurerm_resource_group.arkham.location
  version                       = var.pg_version
  administrator_login           = var.pg_admin_login
  administrator_password        = random_password.pg_admin.result
  sku_name                      = var.pg_sku_name
  storage_mb                    = var.pg_storage_mb
  auto_grow_enabled             = true
  backup_retention_days         = 7
  public_network_access_enabled = true
  zone                          = "1"
  tags                          = local.common_tags

  lifecycle {
    # Storage can auto-grow beyond the configured value; don't fight it.
    ignore_changes = [storage_mb, zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "arkham" {
  name      = var.pg_database_name
  server_id = azurerm_postgresql_flexible_server.arkham.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  lifecycle {
    prevent_destroy = true
  }
}

# Allow other Azure services (the Container App egress) to reach the server.
# The 0.0.0.0 start/end sentinel is Azure's "Allow public access from any
# Azure service within Azure to this server" rule.
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.arkham.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

locals {
  database_url = format(
    "postgres://%s:%s@%s:5432/%s?sslmode=require",
    var.pg_admin_login,
    urlencode(random_password.pg_admin.result),
    azurerm_postgresql_flexible_server.arkham.fqdn,
    var.pg_database_name,
  )
}
