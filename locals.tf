data "azuread_group" "active_directory_administrator_groups" {
  for_each = toset(var.active_directory_administrator_groups)

  display_name     = each.value
  security_enabled = true
}

locals {
  storage_mb = var.storage_size * 1024

  # Databases with a password (non-federated) owner account; these need password authentication.
  password_owner_databases = [
    for name, db in var.databases : name
    if db.local_owner_account != null && !coalesce(db.local_owner_account.federated, db.local_owner_account.object_id != null)
  ]
}
