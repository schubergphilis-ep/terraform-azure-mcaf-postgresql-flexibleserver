data "azuread_group" "active_directory_administrator_groups" {
  for_each = toset(var.active_directory_administrator_groups)

  display_name     = each.value
  security_enabled = true
}

locals {
  storage_mb = var.storage_size * 1024

  # Every Entra principal may be used once across all databases and access levels: one principal,
  # one database, one access level. Groups without an object_id are compared by name.
  entra_principals = flatten([
    for db_name, db in var.databases : concat(
      [for g in concat(db.reader_groups, db.writer_groups, db.admin_groups) : coalesce(g.object_id, "group:${g.group_name}")],
      [for m in concat(db.reader_managed_identity_object_ids, db.writer_managed_identity_object_ids, db.admin_identity_object_ids) : m.object_id],
    )
  ])

  duplicate_entra_principals = distinct([
    for principal in local.entra_principals : principal if length([for p in local.entra_principals : p if p == principal]) > 1
  ])

  # Login role names of the Entra principals of all databases. PostgreSQL roles are cluster-wide,
  # so the same name in two databases would be the same role; that is caught by a precondition.
  entra_role_names = flatten([
    for db_name, db in var.databases : concat(
      [for g in db.reader_groups : "${coalesce(g.role_prefix, g.group_name)}_group_reader"],
      [for m in db.reader_managed_identity_object_ids : "${coalesce(m.role_prefix, m.principal_name)}_service_reader"],
      [for g in db.writer_groups : "${coalesce(g.role_prefix, g.group_name)}_group_writer"],
      [for m in db.writer_managed_identity_object_ids : "${coalesce(m.role_prefix, m.principal_name)}_service_writer"],
      [for g in db.admin_groups : "${coalesce(g.role_prefix, g.group_name)}_group_admin"],
      [for m in db.admin_identity_object_ids : "${coalesce(m.role_prefix, m.principal_name)}_service_admin"],
    )
  ])

  duplicate_entra_role_names = distinct([
    for name in local.entra_role_names : name if length([for n in local.entra_role_names : n if n == name]) > 1
  ])

  # Databases with a password (non-federated) owner account; these need password authentication.
  password_owner_databases = [
    for name, db in var.databases : name
    if db.local_owner_account != null && !coalesce(db.local_owner_account.federated, db.local_owner_account.object_id != null)
  ]
}
