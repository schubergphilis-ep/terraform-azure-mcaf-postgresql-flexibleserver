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
    object_id    = optional(string)
    name         = optional(string)
    display_name = optional(string)
    principal_id = optional(string)
    client_id    = optional(string)
    role_prefix  = optional(string)
  }))
}

variable "writers" {
  type = set(object({
    object_id    = optional(string)
    name         = optional(string)
    display_name = optional(string)
    principal_id = optional(string)
    client_id    = optional(string)
    role_prefix  = optional(string)
  }))
}

variable "admins" {
  type = set(object({
    object_id    = optional(string)
    name         = optional(string)
    display_name = optional(string)
    principal_id = optional(string)
    client_id    = optional(string)
    role_prefix  = optional(string)
  }))
}

variable "local_readers" {
  type = set(object({
    username                   = string
    generate_password          = bool
    ephemeral_password_version = optional(number)
  }))
}

variable "local_writers" {
  type = set(object({
    username                   = string
    generate_password          = bool
    ephemeral_password_version = optional(number)
  }))
}

variable "local_admins" {
  type = set(object({
    username                   = string
    generate_password          = bool
    ephemeral_password_version = optional(number)
  }))
}

variable "local_readers_ephemeral_passwords" {
  type      = map(string)
  ephemeral = true
  default   = null
}

variable "local_writers_ephemeral_passwords" {
  type      = map(string)
  ephemeral = true
  default   = null
}

variable "local_admins_ephemeral_passwords" {
  type      = map(string)
  ephemeral = true
  default   = null
}

