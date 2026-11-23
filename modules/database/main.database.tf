# The roles are created before the database, so they are dropped after it. Dropping the
# database first removes the objects the roles own in it (tables created by the application),
# otherwise DROP ROLE fails with "role ... cannot be dropped because some objects depend on it".
resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.name
  server_id = var.postgresql_server_id
  collation = var.collation
  charset   = var.charset

  depends_on = [
    postgresql_role.access,
    postgresql_role.reader,
    postgresql_role.writer,
    postgresql_role.admin,
    postgresql_role.local_owner,
  ]
}

# ---------------------------------------------------------------------------------------------
# Database access groups
#
# Each database gets NOLOGIN group roles (<database>_readers, _writers, _admins) that hold the
# privileges on this database only. Entra ID principals log on with their own role and inherit
# the privileges of the group they are a member of. PostgreSQL roles are cluster-wide, so the
# privileges are granted per database instead of through pg_read_all_data / pg_write_all_data.
# ---------------------------------------------------------------------------------------------
resource "postgresql_role" "access" {
  provider = postgresql.database
  for_each = local.access_groups

  name  = "${var.name}_${each.key}"
  login = false
}

# Only the access groups, the owner account and server administrators may connect.
resource "postgresql_grant" "revoke_public_connect" {
  provider = postgresql.database

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = "public"
  object_type = "database"
  privileges  = []

  depends_on = [postgresql_grant.azure_pg_admin_connect]
}

resource "postgresql_grant" "azure_pg_admin_connect" {
  provider = postgresql.database

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = "azure_pg_admin"
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "access_connect" {
  provider = postgresql.database
  for_each = local.access_groups

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.access[each.key].name
  object_type = "database"
  privileges  = ["CONNECT"]

  depends_on = [postgresql_role.reader, postgresql_role.writer, postgresql_role.admin]
}

resource "postgresql_grant" "access_schema" {
  provider = postgresql.database
  for_each = local.access_groups

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.access[each.key].name
  object_type = "schema"
  schema      = "public"
  objects     = []
  privileges  = each.value.schema

  depends_on = [postgresql_role.reader, postgresql_role.writer, postgresql_role.admin]
}

resource "postgresql_grant" "access_tables" {
  provider = postgresql.database
  for_each = local.access_groups

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.access[each.key].name
  object_type = "table"
  schema      = "public"
  privileges  = each.value.table

  depends_on = [postgresql_role.reader, postgresql_role.writer, postgresql_role.admin]
}

resource "postgresql_grant" "access_sequences" {
  provider = postgresql.database
  for_each = local.access_groups

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.access[each.key].name
  object_type = "sequence"
  schema      = "public"
  privileges  = each.value.sequence

  depends_on = [postgresql_role.reader, postgresql_role.writer, postgresql_role.admin]
}

# Tables and sequences created later by the owner account, the provisioning identity or an
# admin get the same privileges for the access groups.
#
# The postgresql provider takes advisory locks on the roles involved. Running these at the same
# time as the grants on the same roles can deadlock (40P01), so they wait for the grants.
resource "postgresql_default_privileges" "access" {
  provider = postgresql.database
  for_each = local.access_default_privileges

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = each.value.owner
  object_type = each.value.object_type
  privileges  = each.value.privileges
  role        = postgresql_role.access[each.value.group].name

  depends_on = [
    postgresql_role.admin,
    postgresql_role.local_owner,
    postgresql_grant.access_connect,
    postgresql_grant.access_schema,
    postgresql_grant.access_tables,
    postgresql_grant.access_sequences,
    postgresql_grant.local_owner_database_connect,
    postgresql_grant.local_owner_create_usage_on_schema,
    postgresql_grant.local_owner_table_rights,
    postgresql_grant.local_owner_sequence_rights,
    postgresql_grant.local_owner_function_rights,
  ]
}

# ---------------------------------------------------------------------------------------------
# Entra ID principals
#
# One login role per principal, mapped to the Entra object with a pgaadauth security label
# (stored in pg_shseclabel) and a member of the access group of this database.
# ---------------------------------------------------------------------------------------------
resource "postgresql_role" "reader" {
  provider = postgresql.database
  for_each = local.readers

  name  = each.value.role_name
  login = true
  roles = [postgresql_role.access["readers"].name]
}

resource "postgresql_role" "writer" {
  provider = postgresql.database
  for_each = local.writers

  name  = each.value.role_name
  login = true
  roles = [postgresql_role.access["writers"].name]
}

resource "postgresql_role" "admin" {
  provider = postgresql.database
  for_each = local.admins

  name  = each.value.role_name
  login = true
  roles = [postgresql_role.access["admins"].name]
}

resource "postgresql_security_label" "readers" {
  provider = postgresql.database
  for_each = local.readers

  object_type    = "role"
  object_name    = postgresql_role.reader[each.key].name
  label_provider = "pgaadauth"
  label          = "aadauth,oid=${each.value.object_id},type=${each.value.type}"
}

resource "postgresql_security_label" "writers" {
  provider = postgresql.database
  for_each = local.writers

  object_type    = "role"
  object_name    = postgresql_role.writer[each.key].name
  label_provider = "pgaadauth"
  label          = "aadauth,oid=${each.value.object_id},type=${each.value.type}"
}

resource "postgresql_security_label" "admin" {
  provider = postgresql.database
  for_each = local.admins

  object_type    = "role"
  object_name    = postgresql_role.admin[each.key].name
  label_provider = "pgaadauth"
  label          = "aadauth,oid=${each.value.object_id},type=${each.value.type}"
}

# ---------------------------------------------------------------------------------------------
# Owner account
# ---------------------------------------------------------------------------------------------
resource "random_password" "local_owner" {
  count = local.generate_owner_password ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "postgresql_role" "local_owner" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  name     = var.local_owner_account.username
  login    = true
  password = local.generate_owner_password ? random_password.local_owner[0].result : null

  # Security hardening - principle of least privilege
  superuser       = false
  create_database = false
  create_role     = false
  inherit         = true
  replication     = false
}

# Federated (Entra ID) logon for the owner account. Only created when object_id is supplied.
resource "postgresql_security_label" "local_owner" {
  provider = postgresql.database
  count    = local.local_owner_is_federated ? 1 : 0

  object_type    = "role"
  object_name    = postgresql_role.local_owner[0].name
  label_provider = "pgaadauth"
  label          = "aadauth,oid=${var.local_owner_account.object_id},type=${local.pgaadauth_type[var.local_owner_account.principal_type]}"

  depends_on = [azurerm_postgresql_flexible_server_database.this]
}

resource "postgresql_grant" "local_owner_database_connect" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.local_owner[0].name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "local_owner_create_usage_on_schema" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.local_owner[0].name
  object_type = "schema"
  objects     = []
  privileges  = ["USAGE", "CREATE"]
  schema      = "public"
}

resource "postgresql_grant" "local_owner_table_rights" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.local_owner[0].name
  object_type = "table"
  schema      = "public"
  privileges  = ["ALL"]
}

resource "postgresql_grant" "local_owner_sequence_rights" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.local_owner[0].name
  object_type = "sequence"
  schema      = "public"
  privileges  = ["ALL"]
}

resource "postgresql_grant" "local_owner_function_rights" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  role        = postgresql_role.local_owner[0].name
  object_type = "function"
  schema      = "public"
  privileges  = ["ALL"]
}

resource "postgresql_default_privileges" "local_owner_future_table_rights_own_role" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = postgresql_role.local_owner[0].name
  object_type = "table"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}

resource "postgresql_default_privileges" "local_owner_future_table_rights_admin_account" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = var.provisioning_identity_name
  object_type = "table"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}

resource "postgresql_default_privileges" "local_owner_future_sequence_rights_own_role" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = postgresql_role.local_owner[0].name
  object_type = "sequence"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}

resource "postgresql_default_privileges" "local_owner_future_sequence_rights_admin_account" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = var.provisioning_identity_name
  object_type = "sequence"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}

resource "postgresql_default_privileges" "local_owner_future_function_rights_own_role" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = postgresql_role.local_owner[0].name
  object_type = "function"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}

resource "postgresql_default_privileges" "local_owner_future_function_rights_admin_account" {
  provider = postgresql.database
  count    = local.create_local_owner ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.this.name
  schema      = "public"
  owner       = var.provisioning_identity_name
  object_type = "function"
  privileges  = ["ALL"]
  role        = postgresql_role.local_owner[0].name
}
