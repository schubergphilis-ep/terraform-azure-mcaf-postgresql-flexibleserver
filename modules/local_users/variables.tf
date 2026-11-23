variable "username" {
  type = string
}

variable "generate_password" {
  type = bool
}

variable "ephemeral_password" {
  type      = string
  ephemeral = true
  default   = null
}

variable "ephemeral_password_version" {
  type = number
}

variable "roles" {
  type    = set(string)
  default = []
}

variable "is_admin" {
  type    = bool
  default = false
}

variable "database_name" {
  type = string
}