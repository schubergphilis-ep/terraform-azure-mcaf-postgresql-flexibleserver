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

variable "readers" {
  type = set(object({
    object_id    = string
    display_name = string
    role_prefix  = optional(string)
  }))
  default = []
}

variable "writers" {
  type = set(object({
    object_id    = string
    display_name = string
    role_prefix  = optional(string)
  }))
  default = []
}

variable "admins" {
  type = set(object({
    object_id    = string
    display_name = string
    role_prefix  = optional(string)
  }))
  default = []
}

variable "postgresql_server_administrator_username" {
  type    = string
  default = null
}

variable "local_owner_account" {
  type = object({
    username          = string
    generate_password = optional(bool, true)
  })
  description = "Local PostgreSQL account with owner access for applications that do not support AD authentication. Set generate_password to false if password will be managed outside of Terraform."
  default     = null
}
