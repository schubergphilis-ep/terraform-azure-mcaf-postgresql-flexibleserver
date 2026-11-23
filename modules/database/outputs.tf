output "id" {
  value = azurerm_postgresql_flexible_server_database.this.id
}

output "name" {
  value = azurerm_postgresql_flexible_server_database.this.name
}

output "access" {
  description = "The access group roles of this database and the login roles that are a member of them."
  value = {
    groups  = { for group, role in postgresql_role.access : group => role.name }
    readers = [for role in postgresql_role.reader : role.name]
    writers = [for role in postgresql_role.writer : role.name]
    admins  = [for role in postgresql_role.admin : role.name]
  }
}

output "local_owner_account" {
  description = "PostgreSQL owner account details. In federated mode password is null and object_id is set; in password mode password is null only if generate_password was set to false."
  sensitive   = true
  value = local.create_local_owner ? {
    username    = var.local_owner_account.username
    auth_method = local.local_owner_is_federated ? "federated" : "password"
    object_id   = var.local_owner_account.object_id
    password    = local.generate_owner_password ? random_password.local_owner[0].result : null
  } : null
}
