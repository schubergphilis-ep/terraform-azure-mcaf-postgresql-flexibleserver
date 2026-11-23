data "azurerm_client_config" "current" {}

resource "azurerm_postgresql_flexible_server" "this" {
  # checkov:skip=CKV2_AZURE_57: networking is the caller's choice: VNet integration via delegated_subnet_id, or a private endpoint created by the caller (e.g. terraform-azure-mcaf-private-endpoints)
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  administrator_login               = var.password_auth_enabled ? var.administrator_username : null
  administrator_password            = var.password_auth_enabled && var.administrator_ephemeral_password_version == null ? random_password.password[0].result : null
  administrator_password_wo         = var.administrator_ephemeral_password
  administrator_password_wo_version = var.administrator_ephemeral_password_version
  backup_retention_days             = var.backup_retention_days
  create_mode                       = "Default" # TODO: support DR scenarios
  delegated_subnet_id               = var.delegated_subnet_id
  private_dns_zone_id               = var.private_dns_zone_id
  public_network_access_enabled     = var.public_network_access_enabled
  sku_name                          = var.sku
  storage_mb                        = var.storage_size * 1024
  geo_redundant_backup_enabled      = var.geo_redundant_backup_enabled
  version                           = var.server_version
  zone                              = var.high_available ? "1" : null
  tags                              = var.tags

  authentication {
    password_auth_enabled         = var.password_auth_enabled
    active_directory_auth_enabled = var.active_directory_auth_enabled
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  identity {
    type         = var.identity_type
    identity_ids = [var.customer_managed_key.primary_user_assigned_identity_id]
  }

  customer_managed_key {
    key_vault_key_id                  = var.customer_managed_key.key_vault_key_id
    primary_user_assigned_identity_id = var.customer_managed_key.primary_user_assigned_identity_id
  }

  dynamic "high_availability" {
    for_each = var.high_available ? [true] : []
    content {
      mode                      = var.high_availability_mode
      standby_availability_zone = var.high_availability_standby_zone
    }
  }

  dynamic "maintenance_window" {
    for_each = var.maintenance_window != null ? [var.maintenance_window] : []
    content {
      day_of_week  = maintenance_window.value.day_of_week
      start_hour   = maintenance_window.value.start_hour
      start_minute = maintenance_window.value.start_minute
    }
  }

  lifecycle {
    ignore_changes = [
      zone,
      high_availability
    ]

    precondition {
      condition     = var.password_auth_enabled || var.active_directory_auth_enabled
      error_message = "Enable at least one of password_auth_enabled and active_directory_auth_enabled."
    }

    precondition {
      condition     = var.password_auth_enabled || length(local.databases_with_local_users) == 0
      error_message = "Local PostgreSQL users (local_readers, local_writers, local_admins) log on with a password and need password_auth_enabled = true. Databases with local users: ${join(", ", local.databases_with_local_users)}."
    }
  }
}

resource "random_password" "password" {
  count = var.password_auth_enabled && var.administrator_ephemeral_password_version == null ? 1 : 0

  length           = 48
  special          = true
  override_special = "!#$&()-_=+[]{}?"
}

moved {
  from = random_password.password
  to   = random_password.password[0]
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "this" {
  for_each = { for group_object in var.active_directory_administrator_groups : group_object.display_name => group_object }

  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = each.value.object_id
  principal_name      = each.key
  principal_type      = "Group"
}

module "database" {
  for_each = var.databases

  source = "./modules/database"

  postgresql_server_id = azurerm_postgresql_flexible_server.this.id
  name                 = each.key
  charset              = each.value.charset
  collation            = each.value.collation

  readers                           = each.value.readers
  local_readers                     = each.value.local_readers
  local_readers_ephemeral_passwords = var.local_readers_ephemeral_passwords

  writers                           = each.value.writers
  local_writers                     = each.value.local_writers
  local_writers_ephemeral_passwords = var.local_writers_ephemeral_passwords

  admins                           = each.value.admins
  local_admins                     = each.value.local_admins
  local_admins_ephemeral_passwords = var.local_admins_ephemeral_passwords

  depends_on = [azurerm_postgresql_flexible_server_active_directory_administrator.this]
}
