output "id" {
  value = azurerm_postgresql_flexible_server_database.this.id
}

output "name" {
  value = azurerm_postgresql_flexible_server_database.this.name
}

# output "local_accounts" {
#   description = "Local PostgreSQL owner account credentials. Password is null if generate_password was set to false."
#   sensitive   = true
#   value = { for user in merge(var.local_admins, var.local_readers, lo)}
# }
