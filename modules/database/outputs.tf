output "id" {
  value = azurerm_postgresql_flexible_server_database.this.id
}

output "name" {
  value = azurerm_postgresql_flexible_server_database.this.name
}

output "local_owner_account" {
  description = "Local PostgreSQL owner account credentials. Password is null if generate_password was set to false."
  sensitive   = true
  value = var.local_owner_account != null ? {
    username = var.local_owner_account.username
    password = var.local_owner_account.generate_password ? random_password.local_owner[0].result : null
  } : null
}
