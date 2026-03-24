resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.name
  server_id = var.postgresql_server_id
  collation = var.collation
  charset   = var.charset
}

module "rbac_reader" {
  source          = "../pg_rbac"
  for_each        = var.readers
  database_name   = azurerm_postgresql_flexible_server_database.this.name
  role_name       = "readers"
  role_assignment = each.value
  roles           = ["pg_read_all_data"]
}

module "rbac_writer" {
  source          = "../pg_rbac"
  for_each        = var.writers
  database_name   = azurerm_postgresql_flexible_server_database.this.name
  role_name       = "writers"
  role_assignment = each.value
  roles           = ["pg_read_all_data", "pg_write_all_data"]
}

module "rbac_admin" {
  source          = "../pg_rbac"
  for_each        = var.admins
  database_name   = azurerm_postgresql_flexible_server_database.this.name
  role_name       = "admins"
  role_assignment = each.value
  roles           = ["pg_read_all_data", "pg_write_all_data"]
  is_admin        = true
}