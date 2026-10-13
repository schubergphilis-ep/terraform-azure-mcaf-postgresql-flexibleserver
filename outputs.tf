output "id" {
  value = azurerm_postgresql_flexible_server.this.id
}

output "fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "administrator_username" {
  value = azurerm_postgresql_flexible_server.this.administrator_login
}

output "administrator_password" {
  value     = var.password_auth_enabled && var.administrator_ephemeral_password_version == null ? random_password.password[0].result : null
  sensitive = true
}

output "databases" {
  description = "Map of database names to their id and name."
  sensitive   = true
  value = {
    for name, db in module.database : name => {
      id   = db.id
      name = db.name
    }
  }
}
