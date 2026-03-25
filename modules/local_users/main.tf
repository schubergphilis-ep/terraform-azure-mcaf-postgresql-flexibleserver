# Local owner account for applications that do not support AD authentication
resource "random_password" "this" {
  count = var.generate_password ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "postgresql_role" "this" {
  name                = var.username
  login               = true
  password            = var.generate_password ? random_password.this[0].result : null
  password_wo         = var.ephemeral_password
  password_wo_version = var.ephemeral_password_version
  roles               = var.roles

  # Security hardening - principle of least privilege
  superuser       = false
  create_database = false
  create_role     = false
  inherit         = true
  replication     = false
}

resource "postgresql_grant" "database_connect" {
  count       = var.is_admin ? 1 : 0
  database    = var.database_name
  role        = postgresql_role.this.name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "owner_table_rights" {
  count       = var.is_admin ? 1 : 0
  database    = var.database_name
  role        = postgresql_role.this.name
  object_type = "table"
  schema      = "public"
  privileges  = ["ALL"]
}

resource "postgresql_grant" "owner_sequence_rights" {
  count       = var.is_admin ? 1 : 0
  database    = var.database_name
  role        = postgresql_role.this.name
  object_type = "sequence"
  schema      = "public"
  privileges  = ["ALL"]
}

resource "postgresql_grant" "owner_create_usage_on_schema" {
  count       = var.is_admin ? 1 : 0
  database    = var.database_name
  role        = postgresql_role.this.name
  object_type = "schema"
  objects     = []
  privileges  = ["USAGE", "CREATE"]
  schema      = "public"
}

resource "postgresql_grant" "owner_function_rights" {
  count       = var.is_admin ? 1 : 0
  database    = var.database_name
  role        = postgresql_role.this.name
  object_type = "function"
  schema      = "public"
  privileges  = ["ALL"]
}

resource "postgresql_default_privileges" "owner_future_table_rights_own_role" {
  count       = var.is_admin ? 1 : 0
  database    = var.database_name
  role        = postgresql_role.this.name
  schema      = "public"
  owner       = postgresql_role.this.name
  object_type = "table"
  privileges  = ["ALL"]
}


