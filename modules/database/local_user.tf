# Local owner account for applications that do not support AD authentication
resource "random_password" "local_owner" {
  count = var.local_owner_account != null && var.local_owner_account.generate_password ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "postgresql_role" "local_owner" {
  count = var.local_owner_account != null ? 1 : 0

  name     = var.local_owner_account.username
  login    = true
  password = var.local_owner_account != null && var.local_owner_account.generate_password ? random_password.local_owner[0].result : null

  # Security hardening - principle of least privilege
  superuser       = false
  create_database = false
  create_role     = false
  inherit         = true
  replication     = false

  depends_on = [azurerm_postgresql_flexible_server_database.this]
}

resource "postgresql_grant" "local_owner_database_connect" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.local_owner[0].name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "local_owner_create_usage_on_schema" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.local_owner[0].name
  object_type = "schema"
  objects     = []
  privileges  = ["USAGE", "CREATE"]
  schema      = "public"
}

resource "postgresql_grant" "local_owner_table_rights" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.local_owner[0].name
  object_type = "table"
  schema      = "public"
  privileges  = ["ALL"]
}

resource "postgresql_grant" "local_owner_sequence_rights" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.local_owner[0].name
  object_type = "sequence"
  schema      = "public"
  privileges  = ["ALL"]
}

resource "postgresql_grant" "local_owner_function_rights" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.local_owner[0].name
  object_type = "function"
  schema      = "public"
  privileges  = ["ALL"]
}

resource "postgresql_default_privileges" "local_owner_future_table_rights_own_role" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = postgresql_role.local_owner[0].name
  object_type = "table"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}

resource "postgresql_default_privileges" "local_owner_future_table_rights_admin_account" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = var.postgresql_server_administrator_username
  object_type = "table"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}

resource "postgresql_default_privileges" "local_owner_future_sequence_rights_own_role" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = postgresql_role.local_owner[0].name
  object_type = "sequence"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}

resource "postgresql_default_privileges" "local_owner_future_sequence_rights_admin_account" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = var.postgresql_server_administrator_username
  object_type = "sequence"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}

resource "postgresql_default_privileges" "local_owner_future_function_rights_own_role" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = postgresql_role.local_owner[0].name
  object_type = "function"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}

resource "postgresql_default_privileges" "local_owner_future_function_rights_admin_account" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = var.postgresql_server_administrator_username
  object_type = "function"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}

resource "postgresql_default_privileges" "future_table_rights_admin_account" {
  count = var.local_owner_account != null ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = var.postgresql_server_administrator_username
  object_type = "table"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}
