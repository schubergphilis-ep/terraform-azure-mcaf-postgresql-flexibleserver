variable "name" {
  type        = string
  description = "The name of the postgresql database."
}

variable "charset" {
  type        = string
  description = "The charset of the postgresql database."
  default     = "UTF8"
}

variable "collation" {
  type        = string
  description = "The collation of the postgresql database."
  default     = "en_US.utf8"
}

variable "postgresql_server_id" {
  type        = string
  description = "The id of the postgresql server on which to create the database."
}

variable "reader_groups" {
  type = list(object({
    role_prefix = optional(string)
    group_name  = string
  }))
  default = []
}

variable "reader_managed_identity_object_ids" {
  type = list(object({
    object_id      = string
    principal_name = string
    role_prefix    = optional(string)
  }))
  default = []
}

variable "writer_groups" {
  type = list(object({
    group_name  = string
    role_prefix = optional(string)
  }))
  default = []
}

variable "writer_managed_identity_object_ids" {
  type = list(object({
    object_id      = string
    principal_name = string
    role_prefix    = optional(string)
  }))
  default = []
}

variable "admin_groups" {
  type = list(object({
    group_name  = string
    role_prefix = optional(string)
  }))
  default = []
}

variable "admin_identity_object_ids" {
  type = list(object({
    object_id      = string
    principal_name = string
    role_prefix    = optional(string)
  }))
  default = []
}

variable "provisioning_identity_name" {
  type        = string
  description = "The PostgreSQL login name that Terraform authenticates as when provisioning roles and privileges. In password mode this is the server administrator username; in Entra-only mode set it to the Entra principal name Terraform connects as, so object-owner default privileges are attributed to the correct owner."
}

variable "local_owner_account" {
  type = object({
    username          = string
    generate_password = optional(bool, true)
    object_id         = optional(string)
    principal_type    = optional(string, "ServicePrincipal")
    federated         = optional(bool)
  })
  description = <<-DOC
    PostgreSQL account with owner access to the database, for applications that manage their own schema.

    Authentication mode is selected by whether `object_id` is set:
    - Password mode (default, `object_id` omitted): a local PostgreSQL role is created with a password.
      Set `generate_password` to `false` to manage the password outside of Terraform.
    - Federated mode (`object_id` set): the role is created for Entra ID (Azure AD) token logon via a
      `pgaadauth` security label and has no password. `generate_password` is ignored. The Entra identity
      itself is NOT created by this module; supply the `object_id` of a caller-managed managed identity,
      service principal, or group.

    - `username`          - (Required) The name of the PostgreSQL owner role.
    - `generate_password` - (Optional) Password mode only. Auto-generate a password. Defaults to `true`.
    - `object_id`         - (Optional) Entra ID object ID of the identity to federate. Enables federated mode.
    - `principal_type`    - (Optional) Entra principal type: `ServicePrincipal`, `Group`, or `User`. Defaults to `ServicePrincipal`.
    - `federated`         - (Optional) Explicitly select federated mode. Set this (known at plan time) when the
                            `object_id` is only known after apply, e.g. a managed identity created in the same run.
                            When null, mode is inferred from whether `object_id` is set (upstream behaviour).
  DOC
  default     = null

  validation {
    condition = var.local_owner_account == null ? true : contains(
      ["ServicePrincipal", "Group", "User"], var.local_owner_account.principal_type
    )
    error_message = "local_owner_account.principal_type must be one of: ServicePrincipal, Group, User."
  }
}
