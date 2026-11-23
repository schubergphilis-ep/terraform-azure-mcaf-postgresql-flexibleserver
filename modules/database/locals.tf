data "azuread_group" "reader_groups" {
  for_each = { for group in var.reader_groups : group.group_name => group if group.object_id == null }

  display_name     = each.key
  security_enabled = true
}

data "azuread_group" "writer_groups" {
  for_each = { for group in var.writer_groups : group.group_name => group if group.object_id == null }

  display_name     = each.key
  security_enabled = true
}

data "azuread_group" "admin_groups" {
  for_each = { for group in var.admin_groups : group.group_name => group if group.object_id == null }

  display_name     = each.key
  security_enabled = true
}

locals {
  # Entra roles are keyed on the role name, which is known at plan time also for principals
  # created in the same apply (their object IDs are not).
  readers = merge(
    { for group in var.reader_groups : "${coalesce(group.role_prefix, group.group_name)}_group_reader" =>
      {
        role_name = "${coalesce(group.role_prefix, group.group_name)}_group_reader"
        object_id = group.object_id != null ? group.object_id : data.azuread_group.reader_groups[group.group_name].object_id
        type      = "group"
      }
    },
    { for mid in var.reader_managed_identity_object_ids : "${mid.role_prefix != null ? mid.role_prefix : mid.principal_name}_service_reader" =>
      {
        role_name = "${mid.role_prefix != null ? mid.role_prefix : mid.principal_name}_service_reader"
        object_id = mid.object_id
        type      = "service"
      }
    }
  )

  writers = merge(
    { for group in var.writer_groups : "${coalesce(group.role_prefix, group.group_name)}_group_writer" =>
      {
        role_name = "${coalesce(group.role_prefix, group.group_name)}_group_writer"
        object_id = group.object_id != null ? group.object_id : data.azuread_group.writer_groups[group.group_name].object_id
        type      = "group"
      }
    },
    { for mid in var.writer_managed_identity_object_ids : "${mid.role_prefix != null ? mid.role_prefix : mid.principal_name}_service_writer" =>
      {
        role_name = "${mid.role_prefix != null ? mid.role_prefix : mid.principal_name}_service_writer"
        object_id = mid.object_id
        type      = "service"
      }
    }
  )

  admins = merge(
    { for group in var.admin_groups : "${coalesce(group.role_prefix, group.group_name)}_group_admin" =>
      {
        role_name = "${coalesce(group.role_prefix, group.group_name)}_group_admin"
        object_id = group.object_id != null ? group.object_id : data.azuread_group.admin_groups[group.group_name].object_id
        type      = "group"
      }
    },
    { for mid in var.admin_identity_object_ids : "${mid.role_prefix != null ? mid.role_prefix : mid.principal_name}_service_admin" =>
      {
        role_name = "${mid.role_prefix != null ? mid.role_prefix : mid.principal_name}_service_admin"
        object_id = mid.object_id
        type      = "service"
      }
    }
  )

  # Privileges per access group on this database. A group is only created when it has members.
  access_privileges = {
    readers = {
      schema   = ["USAGE"]
      table    = ["SELECT"]
      sequence = ["SELECT"]
    }
    writers = {
      schema   = ["USAGE"]
      table    = ["SELECT", "INSERT", "UPDATE", "DELETE"]
      sequence = ["SELECT", "USAGE", "UPDATE"]
    }
    admins = {
      schema   = ["USAGE", "CREATE"]
      table    = ["ALL"]
      sequence = ["ALL"]
    }
  }

  access_groups = {
    for group, privileges in local.access_privileges : group => privileges
    if length({ readers = local.readers, writers = local.writers, admins = local.admins }[group]) > 0
  }

  # Roles that create tables and sequences in this database; objects they create later get the
  # access group privileges by default.
  object_owners = toset(concat(
    [var.provisioning_identity_name],
    var.local_owner_account != null ? [var.local_owner_account.username] : [],
    [for admin in local.admins : admin.role_name],
  ))

  access_default_privileges = merge([
    for group, privileges in local.access_groups : merge([
      for owner in local.object_owners : {
        for object_type in ["table", "sequence"] : "${group}/${owner}/${object_type}" => {
          group       = group
          owner       = owner
          object_type = object_type
          privileges  = privileges[object_type]
        }
      }
    ]...)
  ]...)

  create_local_owner = var.local_owner_account != null
  local_owner_is_federated = local.create_local_owner && (
    var.local_owner_account.federated != null ? var.local_owner_account.federated : var.local_owner_account.object_id != null
  )
  generate_owner_password = local.create_local_owner && !local.local_owner_is_federated && var.local_owner_account.generate_password


  # Map Entra principal types to the token expected by the pgaadauth security label provider.
  pgaadauth_type = {
    ServicePrincipal = "service"
    Group            = "group"
    User             = "user"
  }
}
