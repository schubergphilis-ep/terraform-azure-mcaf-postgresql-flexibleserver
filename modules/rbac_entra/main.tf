resource "postgresql_role" "this" {
  name  = var.role_assignment.role_prefix != null ? "${var.role_assignment.role_prefix}-db-${var.role_name}" : coalesce(var.role_assignment.display_name, var.role_assignment.name)
  login = true
  roles = var.roles
}

resource "postgresql_security_label" "this" {
  object_type    = "role"
  object_name    = postgresql_role.this.name
  label_provider = "pgaadauth"
  label          = "aadauth,oid=${coalesce(var.role_assignment.object_id, var.role_assignment.principal_id)},type=${var.role_assignment.object_id != null ? "group" : "service"}"
}

resource "postgresql_default_privileges" "future_table_rights_owner_role" {
  count = var.is_admin ? 1 : 0

  database    = var.database_name
  schema      = "public"
  owner       = postgresql_role.this.name
  object_type = "table"
  privileges  = ["ALL"]
  role        = postgresql_role.this.name
}

resource "postgresql_grant" "create_usage_on_schema" {
  count = var.is_admin ? 1 : 0

  database    = var.database_name
  role        = postgresql_role.this.name
  object_type = "schema"
  objects     = []
  privileges  = ["USAGE", "CREATE"]
  schema      = "public"
}

resource "postgresql_grant" "table_rights" {
  count = var.is_admin ? 1 : 0

  database    = var.database_name
  role        = postgresql_role.this.name
  object_type = "table"
  schema      = "public"
  privileges  = ["ALL"]
}