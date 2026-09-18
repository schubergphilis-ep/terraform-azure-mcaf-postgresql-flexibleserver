variable "database_name" {
  type        = string
  description = "Name of the Database"
}

variable "role_name" {
  type        = string
  description = "Name of the Role"
}

variable "roles" {
  type        = set(string)
  description = "roles to assign to the defined role"
}

variable "is_admin" {
  type        = bool
  description = "Boolean value to assign Admin grants to the group in addition to supplied grants"
  default     = false
}

variable "role_assignment" {
  type = object({
    object_id    = optional(string)
    name         = optional(string)
    display_name = optional(string)
    principal_id = optional(string)
    role_prefix  = optional(string)
  })
}