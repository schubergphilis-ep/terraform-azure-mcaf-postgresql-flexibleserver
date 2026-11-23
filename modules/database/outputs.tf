output "id" {
  value = azurerm_postgresql_flexible_server_database.this.id
}

output "name" {
  value = azurerm_postgresql_flexible_server_database.this.name
}

output "local_users" {
  description = "The local PostgreSQL users of the database by username, with their access level and generated password. The password is null when it is supplied through an ephemeral input."
  sensitive   = true
  value = merge(
    { for username, user in module.local_reader : username => { access = "reader", username = username, password = user.password } },
    { for username, user in module.local_writer : username => { access = "writer", username = username, password = user.password } },
    { for username, user in module.local_admin : username => { access = "admin", username = username, password = user.password } },
  )
}
