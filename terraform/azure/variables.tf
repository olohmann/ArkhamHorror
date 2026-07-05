variable "subscription_id" {
  description = "Target Azure subscription (MSDN)."
  type        = string
  default     = "ad7a4fc6-a7e2-45b3-9ee8-7ba3a0917834"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  # NOTE: This MSDN sub offer-restricts PostgreSQL Flexible Server in westeurope
  # and germanywestcentral. northeurope is verified available.
  default     = "northeurope"
}

variable "name_prefix" {
  description = "Prefix applied to resource names."
  type        = string
  default     = "arkham"
}

variable "resource_group_name" {
  description = "Resource group to create for the app + database."
  type        = string
  default     = "rg-arkham-horror"
}

# --- Existing ACR (created in a previous step, holds the app image) ----------
variable "acr_name" {
  description = "Name of the existing Azure Container Registry."
  type        = string
  default     = "lohmannio"
}

variable "acr_resource_group_name" {
  description = "Resource group of the existing ACR."
  type        = string
  default     = "prod-lohmannio-rg"
}

variable "image_repository" {
  description = "Image repository inside the ACR."
  type        = string
  default     = "arkham-horror"
}

variable "image_tag" {
  description = "Image tag to deploy (e.g. sha-<short> or a v* tag)."
  type        = string
  default     = "sha-1757946"
}

# --- App sizing --------------------------------------------------------------
variable "app_cpu" {
  description = "vCPU per replica. Memory-hungry Haskell app -> 1.0."
  type        = number
  default     = 1.0
}

variable "app_memory" {
  description = "Memory per replica. Must pair with app_cpu per ACA rules."
  type        = string
  default     = "2Gi"
}

variable "asset_host" {
  description = "Public asset host (CDN). Empty serves images from the container."
  type        = string
  default     = "https://assets.arkhamhorror.app"
}

# --- PostgreSQL --------------------------------------------------------------
variable "pg_sku_name" {
  description = "Flexible Server SKU. Burstable B1ms for cost."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "pg_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "pg_storage_mb" {
  description = "Flexible Server storage in MB."
  type        = number
  default     = 32768
}

variable "pg_admin_login" {
  description = "PostgreSQL administrator login."
  type        = string
  default     = "arkham_pg_user"
}

variable "pg_database_name" {
  description = "Application database name."
  type        = string
  default     = "arkham-horror-backend"
}
