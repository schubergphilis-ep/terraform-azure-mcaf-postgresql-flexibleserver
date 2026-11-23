<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_postgresql"></a> [postgresql](#requirement\_postgresql) | ~> 1.25 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_postgresql"></a> [postgresql](#provider\_postgresql) | ~> 1.25 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [postgresql_default_privileges.future_table_rights_owner_role](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/default_privileges) | resource |
| [postgresql_grant.create_usage_on_schema](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/grant) | resource |
| [postgresql_grant.table_rights](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/grant) | resource |
| [postgresql_role.this](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/role) | resource |
| [postgresql_security_label.this](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/security_label) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the Database | `string` | n/a | yes |
| <a name="input_role_assignment"></a> [role\_assignment](#input\_role\_assignment) | n/a | <pre>object({<br/>    object_id    = optional(string)<br/>    name         = optional(string)<br/>    display_name = optional(string)<br/>    principal_id = optional(string)<br/>    role_prefix  = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the Role | `string` | n/a | yes |
| <a name="input_roles"></a> [roles](#input\_roles) | roles to assign to the defined role | `set(string)` | n/a | yes |
| <a name="input_is_admin"></a> [is\_admin](#input\_is\_admin) | Boolean value to assign Admin grants to the group in addition to supplied grants | `bool` | `false` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->