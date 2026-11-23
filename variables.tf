variable "name" {
  type        = string
  description = "The name of the postgresql server."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which the postgresql server will be created."
}

variable "location" {
  type        = string
  description = "The location of the postgresql server."
}

variable "administrator_username" {
  type    = string
  default = "sbp_administrator"
}

variable "administrator_ephemeral_password" {
  default   = null
  ephemeral = true
  type      = string
}

variable "administrator_ephemeral_password_version" {
  default = null
  type    = number
}

variable "password_auth_enabled" {
  type        = bool
  description = "Whether password authentication is enabled for the PostgreSQL Flexible Server. Opt-in: when false (the default), the server is Entra ID only and gets no local administrator login or password. Set to true for a local administrator with a generated password, or for local PostgreSQL users (`local_readers`, `local_writers`, `local_admins`)."
  default     = false
}

variable "active_directory_auth_enabled" {
  type        = bool
  description = "Whether Active Directory authentication is enabled for the PostgreSQL Flexible Server."
  default     = true
}

variable "active_directory_administrator_groups" {
  type = set(object({
    object_id    = string
    display_name = string
  }))
  default = []
}

variable "backup_retention_days" {
  type        = number
  description = "Number of days to keep the postgress backup, between 7 and 35"
  default     = 7
}

variable "customer_managed_key" {
  type = object({
    key_vault_key_id                  = string
    primary_user_assigned_identity_id = string
  })
  description = "CMK configuration for the postgresql server."
}

variable "high_available" {
  type        = bool
  description = "Whether the postgresql server should be HA."
  default     = true
}

variable "server_version" {
  type        = string
  description = "The version of the postgresql server."
  default     = "17"
}

variable "sku" {
  type        = string
  description = "The sku of the postgresql server. "
}

variable "storage_size" {
  type        = number
  description = "The max storage allowed for the PostgreSQL Flexible Server in GB. Possible values are 32, 64, 128, 256, 512, 1024, 2048, 4095, 4096, 8192, 16384, and 32767."
  default     = 32
}

variable "delegated_subnet_id" {
  type        = string
  description = "The ID of the delegated subnet for the PostgreSQL Flexible Server. This subnet must have the 'Microsoft.DBforPostgreSQL/flexibleServers' service delegation."
  default     = null
}

variable "private_dns_zone_id" {
  type        = string
  description = "The ID of the private DNS zone for the PostgreSQL Flexible Server. Required when using a delegated subnet."
  default     = null
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Whether public network access is enabled for the PostgreSQL Flexible Server."
  default     = false
}

variable "identity_type" {
  type        = string
  description = "The type of identity to use for the PostgreSQL Flexible Server. Possible values are 'UserAssigned' or 'SystemAssigned'."
  default     = "UserAssigned"
}

variable "high_availability_mode" {
  type        = string
  description = "The high availability mode for the PostgreSQL Flexible Server. Possible values are 'ZoneRedundant' or 'SameZone'."
  default     = "ZoneRedundant"
}

variable "high_availability_standby_zone" {
  type        = string
  description = "The availability zone for the standby server when high availability is enabled."
  default     = "2"
}

variable "geo_redundant_backup_enabled" {
  type        = bool
  description = "Whether geo-redundant backup is enabled for the PostgreSQL Flexible Server."
  default     = true
}

variable "maintenance_window" {
  type = object({
    day_of_week  = optional(number, 0)
    start_hour   = optional(number, 0)
    start_minute = optional(number, 0)
  })
  default     = null
  description = <<-DOC
    A custom maintenance window for the PostgreSQL Flexible Server. If not specified, the system-managed maintenance window is used.

    The maintenance window object supports the following properties:
    - `day_of_week`  - (Optional) The day of the week for the maintenance window, where `0` is Sunday and `6` is Saturday. Defaults to `0`.
    - `start_hour`   - (Optional) The start hour (UTC) for the maintenance window, between `0` and `23`. Defaults to `0`.
    - `start_minute` - (Optional) The start minute for the maintenance window, between `0` and `59`. Defaults to `0`.
  DOC
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "databases" {
  type = map(object({
    charset                = optional(string, "UTF8")
    collation              = optional(string, "en_US.utf8")
    administrator_username = optional(string)

    local_readers = optional(set(object({
      username                   = string
      generate_password          = optional(bool, true)
      ephemeral_password_version = optional(number)
    })), [])


    local_writers = optional(set(object({
      username                   = string
      generate_password          = optional(bool, true)
      ephemeral_password_version = optional(number)
    })), [])

    local_admins = optional(set(object({
      username                   = string
      generate_password          = optional(bool, true)
      ephemeral_password_version = optional(number)
    })), [])

    readers = optional(set(object({
      object_id    = optional(string)
      name         = optional(string)
      display_name = optional(string)
      principal_id = optional(string)
      client_id    = optional(string)
      role_prefix  = optional(string)
    })), [])

    writers = optional(set(object({
      object_id    = optional(string)
      name         = optional(string)
      display_name = optional(string)
      principal_id = optional(string)
      client_id    = optional(string)
      role_prefix  = optional(string)
    })), [])

    admins = optional(set(object({
      object_id    = optional(string)
      name         = optional(string)
      display_name = optional(string)
      principal_id = optional(string)
      client_id    = optional(string)
      role_prefix  = optional(string)
    })), [])
  }))

  default     = {}
  description = <<-DOC
    A map of databases to create on the PostgreSQL Flexible Server. The map key is used as the database name.

    Each database object supports the following properties:
    - `charset`                - (Optional) The charset of the PostgreSQL database. Defaults to `UTF8`.
    - `collation`              - (Optional) The collation of the PostgreSQL database. Defaults to `en_US.utf8`.
    - `administrator_username` - (Optional) The administrator username for the PostgreSQL server. If not specified, the server's default administrator username is used.

    Entra ID principals are granted access through `readers`, `writers` and `admins`. Each entry
    describes one principal, which may be a group, a service principal or a managed identity:
      - `object_id`    - (Optional) The object ID of the group. Set this for groups.
      - `principal_id` - (Optional) The principal ID of the service principal or managed identity.
      - `display_name` - (Optional) The display name of the group.
      - `name`         - (Optional) The name of the managed identity.
      - `client_id`    - (Optional) The client ID of the managed identity.
      - `role_prefix`  - (Optional) A prefix for the database role name. Without it the role takes the principal's display name or name.

    One of `object_id` or `principal_id` is required: the `pgaadauth` security label needs the
    principal's Entra object ID. Supply `display_name` for groups or `name` for managed identities
    as well, because the database role is named after it and the role name is what the principal
    authenticates as.

    Use `object_id` for groups and `principal_id` for service principals and managed identities:
    the principal type in the `pgaadauth` label (`group` or `service`) follows from which of the
    two is set. Users are not supported.

    Role names are server-wide in PostgreSQL, not per database. Every `role_prefix` (or
    `display_name`/`name` when there is none) must therefore be unique across all databases, or
    the second role fails to create. The role is named `<role_prefix>-db-<readers|writers|admins>`,
    or after `display_name`/`name` without a `role_prefix`. Avoid binding the same Entra principal
    to more than one role.

    `readers` receive `pg_read_all_data`. `writers` additionally receive `pg_write_all_data`.
    `admins` receive both, plus `USAGE` and `CREATE` on the `public` schema, `ALL` on its tables,
    and matching default privileges — use `admins` for a principal that creates its own schema.

    Local PostgreSQL accounts, for applications that cannot use Entra ID authentication, are
    declared through `local_readers`, `local_writers` and `local_admins`. They log on with a
    password, so they need `password_auth_enabled = true`. Usernames are server-wide, like role names:
      - `username`                   - (Required) The username for the local account.
      - `generate_password`          - (Optional) Whether the module generates the password. Defaults to `true`.
                                       The generated password is in the `local_users` entry of the `databases` output.
      - `ephemeral_password_version` - (Optional) Set it, together with `generate_password = false`, to supply the
                                       password yourself through the corresponding `local_*_ephemeral_passwords`
                                       variable (a map of username to password). Bump the version to rotate it.

    A local user gets either a generated password or one you supply, never both. A user with
    `generate_password = true` must not set `ephemeral_password_version`, and a user with
    `generate_password = false` must set it and have an entry in the matching
    `local_*_ephemeral_passwords` map.
  DOC

  validation {
    condition = alltrue([
      for db in var.databases : alltrue([
        for principal in setunion(db.readers, db.writers, db.admins) :
        principal.object_id != null || principal.principal_id != null
      ])
    ])
    error_message = "Each reader, writer and admin must set object_id (for a group) or principal_id (for a service principal or managed identity). The pgaadauth security label cannot be written without the principal's Entra object ID."
  }

  validation {
    condition = alltrue([
      for db in var.databases : alltrue([
        for principal in setunion(db.readers, db.writers, db.admins) :
        principal.display_name != null || principal.name != null || principal.role_prefix != null
      ])
    ])
    error_message = "Each reader, writer and admin must set display_name, name or role_prefix. The database role is named after one of these, and the name must be known at plan time because it identifies the role."
  }

  validation {
    condition = alltrue([
      for db in var.databases : alltrue([
        for user in setunion(db.local_readers, db.local_writers, db.local_admins) :
        user.generate_password ? user.ephemeral_password_version == null : user.ephemeral_password_version != null
      ])
    ])
    error_message = "A local user gets either a generated password or one you supply. Set ephemeral_password_version only together with generate_password = false, and set it for every local user with generate_password = false."
  }
}

variable "local_readers_ephemeral_passwords" {
  type        = map(string)
  description = "Passwords for the local_readers that have generate_password = false, as a map of username to password. Entries for users that generate their own password are rejected."
  ephemeral   = true
  default     = null

  validation {
    condition = alltrue([
      for db in var.databases : alltrue([
        for user in db.local_readers :
        user.generate_password || try(contains(keys(var.local_readers_ephemeral_passwords), user.username), false)
      ])
    ])
    error_message = "Every local_readers user with generate_password = false needs an entry, keyed by username, in local_readers_ephemeral_passwords."
  }

  validation {
    condition = var.local_readers_ephemeral_passwords == null ? true : alltrue([
      for username in keys(var.local_readers_ephemeral_passwords) :
      contains(flatten([
        for db in var.databases : [for user in db.local_readers : user.username if !user.generate_password]
      ]), username)
    ])
    error_message = "local_readers_ephemeral_passwords has an entry for a user that is not in local_readers or that generates its own password (generate_password = true). Set generate_password = false and an ephemeral_password_version for that user, or remove the entry."
  }
}

variable "local_writers_ephemeral_passwords" {
  type        = map(string)
  description = "Passwords for the local_writers that have generate_password = false, as a map of username to password. Entries for users that generate their own password are rejected."
  ephemeral   = true
  default     = null

  validation {
    condition = alltrue([
      for db in var.databases : alltrue([
        for user in db.local_writers :
        user.generate_password || try(contains(keys(var.local_writers_ephemeral_passwords), user.username), false)
      ])
    ])
    error_message = "Every local_writers user with generate_password = false needs an entry, keyed by username, in local_writers_ephemeral_passwords."
  }

  validation {
    condition = var.local_writers_ephemeral_passwords == null ? true : alltrue([
      for username in keys(var.local_writers_ephemeral_passwords) :
      contains(flatten([
        for db in var.databases : [for user in db.local_writers : user.username if !user.generate_password]
      ]), username)
    ])
    error_message = "local_writers_ephemeral_passwords has an entry for a user that is not in local_writers or that generates its own password (generate_password = true). Set generate_password = false and an ephemeral_password_version for that user, or remove the entry."
  }
}

variable "local_admins_ephemeral_passwords" {
  type        = map(string)
  description = "Passwords for the local_admins that have generate_password = false, as a map of username to password. Entries for users that generate their own password are rejected."
  ephemeral   = true
  default     = null

  validation {
    condition = alltrue([
      for db in var.databases : alltrue([
        for user in db.local_admins :
        user.generate_password || try(contains(keys(var.local_admins_ephemeral_passwords), user.username), false)
      ])
    ])
    error_message = "Every local_admins user with generate_password = false needs an entry, keyed by username, in local_admins_ephemeral_passwords."
  }

  validation {
    condition = var.local_admins_ephemeral_passwords == null ? true : alltrue([
      for username in keys(var.local_admins_ephemeral_passwords) :
      contains(flatten([
        for db in var.databases : [for user in db.local_admins : user.username if !user.generate_password]
      ]), username)
    ])
    error_message = "local_admins_ephemeral_passwords has an entry for a user that is not in local_admins or that generates its own password (generate_password = true). Set generate_password = false and an ephemeral_password_version for that user, or remove the entry."
  }
}

