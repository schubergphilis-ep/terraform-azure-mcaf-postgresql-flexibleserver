resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.name
  server_id = var.postgresql_server_id
  collation = var.collation
  charset   = var.charset
}

module "local_reader" {
  source                     = "../local_users"
  for_each                   = { for user_object in var.local_readers : user_object.username => user_object }
  database_name              = azurerm_postgresql_flexible_server_database.this.name
  username                   = each.key
  generate_password          = each.value.generate_password
  ephemeral_password         = each.value.generate_password ? null : var.local_readers_ephemeral_passwords[each.key]
  ephemeral_password_version = each.value.generate_password ? null : each.value.ephemeral_password_version
  roles                      = ["pg_read_all_data"]

  depends_on = [azurerm_postgresql_flexible_server_database.this]
}

module "local_writer" {
  source                     = "../local_users"
  for_each                   = { for user_object in var.local_writers : user_object.username => user_object }
  database_name              = azurerm_postgresql_flexible_server_database.this.name
  username                   = each.key
  generate_password          = each.value.generate_password
  ephemeral_password         = each.value.generate_password ? null : var.local_writers_ephemeral_passwords[each.key]
  ephemeral_password_version = each.value.generate_password ? null : each.value.ephemeral_password_version
  roles                      = ["pg_read_all_data", "pg_write_all_data"]

  depends_on = [azurerm_postgresql_flexible_server_database.this]
}

module "local_admin" {
  source                     = "../local_users"
  for_each                   = { for user_object in var.local_admins : user_object.username => user_object }
  database_name              = azurerm_postgresql_flexible_server_database.this.name
  username                   = each.key
  generate_password          = each.value.generate_password
  ephemeral_password         = each.value.generate_password ? null : var.local_admins_ephemeral_passwords[each.key]
  ephemeral_password_version = each.value.generate_password ? null : each.value.ephemeral_password_version
  is_admin                   = true

  depends_on = [azurerm_postgresql_flexible_server_database.this]
}

module "entra_rbac_reader" {
  source          = "../rbac_entra"
  for_each        = { for user_object in var.readers : user_object.display_name => user_object }
  database_name   = azurerm_postgresql_flexible_server_database.this.name
  role_name       = "readers"
  role_assignment = each.value
  roles           = ["pg_read_all_data"]

  depends_on = [azurerm_postgresql_flexible_server_database.this]
}

module "entra_rbac_writer" {
  source          = "../rbac_entra"
  for_each        = { for user_object in var.writers : user_object.display_name => user_object }
  database_name   = azurerm_postgresql_flexible_server_database.this.name
  role_name       = "writers"
  role_assignment = each.value
  roles           = ["pg_read_all_data", "pg_write_all_data"]

  depends_on = [azurerm_postgresql_flexible_server_database.this]
}

module "entra_rbac_admin" {
  source          = "../rbac_entra"
  for_each        = { for user_object in var.admins : user_object.display_name => user_object }
  database_name   = azurerm_postgresql_flexible_server_database.this.name
  role_name       = "admins"
  role_assignment = each.value
  roles           = ["pg_read_all_data", "pg_write_all_data"]
  is_admin        = true

  depends_on = [azurerm_postgresql_flexible_server_database.this]
}