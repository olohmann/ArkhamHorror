output "app_url" {
  description = "Public HTTPS URL of the Arkham Horror app."
  value       = "https://${azurerm_container_app.arkham.ingress[0].fqdn}"
}

output "app_fqdn" {
  description = "Container App ingress FQDN."
  value       = azurerm_container_app.arkham.ingress[0].fqdn
}

output "postgres_fqdn" {
  description = "PostgreSQL Flexible Server FQDN."
  value       = azurerm_postgresql_flexible_server.arkham.fqdn
}

output "database_url" {
  description = "Full Postgres connection URL used by the app."
  value       = local.database_url
  sensitive   = true
}

output "resource_group" {
  description = "Resource group holding the app + database."
  value       = azurerm_resource_group.arkham.name
}

output "image" {
  description = "Container image deployed."
  value       = local.image
}
