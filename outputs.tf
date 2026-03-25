output "id" {
  value = azurerm_postgresql_flexible_server.this.id
}

output "fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "administrator_username" {
  value = azurerm_postgresql_flexible_server.this.administrator_login
}

# output "active_directory_administrators" {
#   value = keys(azurerm_postgresql_flexible_server_active_directory_administrator.this)[0]
#   description = "Use this output as your `username` in the postgres provider configuration to ensure the role is configured to prevent pre-emptive initialisation of the provider"
# }

output "administrator_password" {
  value     = var.password_auth_enabled && var.administrator_ephemeral_password_version == null ? random_password.password[0].result : null
  sensitive = true
}

output "databases" {
  description = "Map of database names to their details including local owner account credentials."
  sensitive   = true
  value = {
    for name, db in module.database : name => {
      id   = db.id
      name = db.name
      # local_owner_account = db.local_owner_account
    }
  }
}
