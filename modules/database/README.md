<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 3.5 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.20 |
| <a name="requirement_postgresql"></a> [postgresql](#requirement\_postgresql) | ~> 1.25 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 4.20 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_entra_rbac_admin"></a> [entra\_rbac\_admin](#module\_entra\_rbac\_admin) | ../rbac_entra | n/a |
| <a name="module_entra_rbac_reader"></a> [entra\_rbac\_reader](#module\_entra\_rbac\_reader) | ../rbac_entra | n/a |
| <a name="module_entra_rbac_writer"></a> [entra\_rbac\_writer](#module\_entra\_rbac\_writer) | ../rbac_entra | n/a |
| <a name="module_local_admin"></a> [local\_admin](#module\_local\_admin) | ../local_users | n/a |
| <a name="module_local_reader"></a> [local\_reader](#module\_local\_reader) | ../local_users | n/a |
| <a name="module_local_writer"></a> [local\_writer](#module\_local\_writer) | ../local_users | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_postgresql_flexible_server_database.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_database) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admins"></a> [admins](#input\_admins) | n/a | <pre>set(object({<br/>    object_id    = optional(string)<br/>    name         = optional(string)<br/>    display_name = optional(string)<br/>    principal_id = optional(string)<br/>    client_id    = optional(string)<br/>    role_prefix  = optional(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_local_admins"></a> [local\_admins](#input\_local\_admins) | n/a | <pre>set(object({<br/>    username                   = string<br/>    generate_password          = bool<br/>    ephemeral_password_version = optional(number)<br/>  }))</pre> | n/a | yes |
| <a name="input_local_readers"></a> [local\_readers](#input\_local\_readers) | n/a | <pre>set(object({<br/>    username                   = string<br/>    generate_password          = bool<br/>    ephemeral_password_version = optional(number)<br/>  }))</pre> | n/a | yes |
| <a name="input_local_writers"></a> [local\_writers](#input\_local\_writers) | n/a | <pre>set(object({<br/>    username                   = string<br/>    generate_password          = bool<br/>    ephemeral_password_version = optional(number)<br/>  }))</pre> | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | The name of the postgresql database. | `string` | n/a | yes |
| <a name="input_postgresql_server_id"></a> [postgresql\_server\_id](#input\_postgresql\_server\_id) | The id of the postgresql server on which to create the database. | `string` | n/a | yes |
| <a name="input_readers"></a> [readers](#input\_readers) | n/a | <pre>set(object({<br/>    object_id    = optional(string)<br/>    name         = optional(string)<br/>    display_name = optional(string)<br/>    principal_id = optional(string)<br/>    client_id    = optional(string)<br/>    role_prefix  = optional(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_writers"></a> [writers](#input\_writers) | n/a | <pre>set(object({<br/>    object_id    = optional(string)<br/>    name         = optional(string)<br/>    display_name = optional(string)<br/>    principal_id = optional(string)<br/>    client_id    = optional(string)<br/>    role_prefix  = optional(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_charset"></a> [charset](#input\_charset) | The charset of the postgresql database. | `string` | `"UTF8"` | no |
| <a name="input_collation"></a> [collation](#input\_collation) | The collation of the postgresql database. | `string` | `"en_US.utf8"` | no |
| <a name="input_local_admins_ephemeral_passwords"></a> [local\_admins\_ephemeral\_passwords](#input\_local\_admins\_ephemeral\_passwords) | n/a | `map(string)` | `null` | no |
| <a name="input_local_readers_ephemeral_passwords"></a> [local\_readers\_ephemeral\_passwords](#input\_local\_readers\_ephemeral\_passwords) | n/a | `map(string)` | `null` | no |
| <a name="input_local_writers_ephemeral_passwords"></a> [local\_writers\_ephemeral\_passwords](#input\_local\_writers\_ephemeral\_passwords) | n/a | `map(string)` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_id"></a> [id](#output\_id) | n/a |
| <a name="output_name"></a> [name](#output\_name) | n/a |
<!-- END_TF_DOCS -->