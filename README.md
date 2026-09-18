# Introduction 
TODO: Give a short introduction of your project. Let this section explain the objectives or the motivation behind this project. 

# Getting Started
TODO: Guide users through getting your code up and running on their own system. In this section you can talk about:
1.	Installation process
2.	Software dependencies
3.	Latest releases
4.	API references

# Build and Test
TODO: Describe and show how to build your code and run the tests. 

# Contribute
TODO: Explain how other users and developers can contribute to make your code better. 

If you want to learn more about creating good readme files then refer the following [guidelines](https://docs.microsoft.com/en-us/azure/devops/repos/git/create-a-readme?view=azure-devops). You can also seek inspiration from the below readme files:
- [ASP.NET Core](https://github.com/aspnet/Home)
- [Visual Studio Code](https://github.com/Microsoft/vscode)
- [Chakra Core](https://github.com/Microsoft/ChakraCore)
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
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.6 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_database"></a> [database](#module\_database) | ./modules/database | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_postgresql_flexible_server.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server) | resource |
| [azurerm_postgresql_flexible_server_active_directory_administrator.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_active_directory_administrator) | resource |
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_customer_managed_key"></a> [customer\_managed\_key](#input\_customer\_managed\_key) | CMK configuration for the postgresql server. | <pre>object({<br/>    key_vault_key_id                  = string<br/>    primary_user_assigned_identity_id = string<br/>  })</pre> | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | The location of the postgresql server. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | The name of the postgresql server. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of the resource group in which the postgresql server will be created. | `string` | n/a | yes |
| <a name="input_sku"></a> [sku](#input\_sku) | The sku of the postgresql server. | `string` | n/a | yes |
| <a name="input_active_directory_administrator_groups"></a> [active\_directory\_administrator\_groups](#input\_active\_directory\_administrator\_groups) | n/a | <pre>set(object({<br/>    object_id    = string<br/>    display_name = string<br/>  }))</pre> | `[]` | no |
| <a name="input_active_directory_auth_enabled"></a> [active\_directory\_auth\_enabled](#input\_active\_directory\_auth\_enabled) | Whether Active Directory authentication is enabled for the PostgreSQL Flexible Server. | `bool` | `true` | no |
| <a name="input_administrator_ephemeral_password"></a> [administrator\_ephemeral\_password](#input\_administrator\_ephemeral\_password) | n/a | `string` | `null` | no |
| <a name="input_administrator_ephemeral_password_version"></a> [administrator\_ephemeral\_password\_version](#input\_administrator\_ephemeral\_password\_version) | n/a | `number` | `null` | no |
| <a name="input_administrator_username"></a> [administrator\_username](#input\_administrator\_username) | n/a | `string` | `"sbp_administrator"` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Number of days to keep the postgress backup, between 7 and 35 | `number` | `7` | no |
| <a name="input_databases"></a> [databases](#input\_databases) | A map of databases to create on the PostgreSQL Flexible Server. The map key is used as the database name.<br/><br/>Each database object supports the following properties:<br/>- `charset`                - (Optional) The charset of the PostgreSQL database. Defaults to `UTF8`.<br/>- `collation`              - (Optional) The collation of the PostgreSQL database. Defaults to `en_US.utf8`.<br/>- `administrator_username` - (Optional) The administrator username for the PostgreSQL server. If not specified, the server's default administrator username is used.<br/><br/>Entra ID principals are granted access through `readers`, `writers` and `admins`. Each entry<br/>describes one principal, which may be a group, a service principal or a managed identity:<br/>  - `object_id`    - (Optional) The object ID of the group. Set this for groups.<br/>  - `principal_id` - (Optional) The principal ID of the service principal or managed identity.<br/>  - `display_name` - (Optional) The display name of the group.<br/>  - `name`         - (Optional) The name of the managed identity.<br/>  - `client_id`    - (Optional) The client ID of the managed identity.<br/>  - `role_prefix`  - (Optional) A prefix for the database role name. Without it the role takes the principal's display name or name.<br/><br/>One of `object_id` or `principal_id` is required: the `pgaadauth` security label needs the<br/>principal's Entra object ID. Supply `display_name` for groups or `name` for managed identities<br/>as well, because the database role is named after it and the role name is what the principal<br/>authenticates as.<br/><br/>`readers` receive `pg_read_all_data`. `writers` additionally receive `pg_write_all_data`.<br/>`admins` receive both, plus `USAGE` and `CREATE` on the `public` schema, `ALL` on its tables,<br/>and matching default privileges — use `admins` for a principal that creates its own schema.<br/><br/>Local PostgreSQL accounts, for applications that cannot use Entra ID authentication, are<br/>declared through `local_readers`, `local_writers` and `local_admins`:<br/>  - `username`                   - (Required) The username for the local account.<br/>  - `generate_password`          - (Optional) Whether to generate a password. Defaults to `true`.<br/>  - `ephemeral_password_version` - (Optional) Version marker used when the password is supplied through the corresponding `local_*_ephemeral_passwords` variable. | <pre>map(object({<br/>    charset                = optional(string, "UTF8")<br/>    collation              = optional(string, "en_US.utf8")<br/>    administrator_username = optional(string)<br/><br/>    local_readers = optional(set(object({<br/>      username                   = string<br/>      generate_password          = optional(bool, true)<br/>      ephemeral_password_version = optional(number)<br/>    })), [])<br/><br/><br/>    local_writers = optional(set(object({<br/>      username                   = string<br/>      generate_password          = optional(bool, true)<br/>      ephemeral_password_version = optional(number)<br/>    })), [])<br/><br/>    local_admins = optional(set(object({<br/>      username                   = string<br/>      generate_password          = optional(bool, true)<br/>      ephemeral_password_version = optional(number)<br/>    })), [])<br/><br/>    readers = optional(set(object({<br/>      object_id    = optional(string)<br/>      name         = optional(string)<br/>      display_name = optional(string)<br/>      principal_id = optional(string)<br/>      client_id    = optional(string)<br/>      role_prefix  = optional(string)<br/>    })), [])<br/><br/>    writers = optional(set(object({<br/>      object_id    = optional(string)<br/>      name         = optional(string)<br/>      display_name = optional(string)<br/>      principal_id = optional(string)<br/>      client_id    = optional(string)<br/>      role_prefix  = optional(string)<br/>    })), [])<br/><br/>    admins = optional(set(object({<br/>      object_id    = optional(string)<br/>      name         = optional(string)<br/>      display_name = optional(string)<br/>      principal_id = optional(string)<br/>      client_id    = optional(string)<br/>      role_prefix  = optional(string)<br/>    })), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_delegated_subnet_id"></a> [delegated\_subnet\_id](#input\_delegated\_subnet\_id) | The ID of the delegated subnet for the PostgreSQL Flexible Server. This subnet must have the 'Microsoft.DBforPostgreSQL/flexibleServers' service delegation. | `string` | `null` | no |
| <a name="input_geo_redundant_backup_enabled"></a> [geo\_redundant\_backup\_enabled](#input\_geo\_redundant\_backup\_enabled) | Whether geo-redundant backup is enabled for the PostgreSQL Flexible Server. | `bool` | `true` | no |
| <a name="input_high_availability_mode"></a> [high\_availability\_mode](#input\_high\_availability\_mode) | The high availability mode for the PostgreSQL Flexible Server. Possible values are 'ZoneRedundant' or 'SameZone'. | `string` | `"ZoneRedundant"` | no |
| <a name="input_high_availability_standby_zone"></a> [high\_availability\_standby\_zone](#input\_high\_availability\_standby\_zone) | The availability zone for the standby server when high availability is enabled. | `string` | `"2"` | no |
| <a name="input_high_available"></a> [high\_available](#input\_high\_available) | Whether the postgresql server should be HA. | `bool` | `true` | no |
| <a name="input_identity_type"></a> [identity\_type](#input\_identity\_type) | The type of identity to use for the PostgreSQL Flexible Server. Possible values are 'UserAssigned' or 'SystemAssigned'. | `string` | `"UserAssigned"` | no |
| <a name="input_local_admins_ephemeral_passwords"></a> [local\_admins\_ephemeral\_passwords](#input\_local\_admins\_ephemeral\_passwords) | n/a | `map(string)` | `null` | no |
| <a name="input_local_readers_ephemeral_passwords"></a> [local\_readers\_ephemeral\_passwords](#input\_local\_readers\_ephemeral\_passwords) | n/a | `map(string)` | `null` | no |
| <a name="input_local_writers_ephemeral_passwords"></a> [local\_writers\_ephemeral\_passwords](#input\_local\_writers\_ephemeral\_passwords) | n/a | `map(string)` | `null` | no |
| <a name="input_password_auth_enabled"></a> [password\_auth\_enabled](#input\_password\_auth\_enabled) | Whether password authentication is enabled for the PostgreSQL Flexible Server. | `bool` | `true` | no |
| <a name="input_private_dns_zone_id"></a> [private\_dns\_zone\_id](#input\_private\_dns\_zone\_id) | The ID of the private DNS zone for the PostgreSQL Flexible Server. Required when using a delegated subnet. | `string` | `null` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Whether public network access is enabled for the PostgreSQL Flexible Server. | `bool` | `false` | no |
| <a name="input_server_version"></a> [server\_version](#input\_server\_version) | The version of the postgresql server. | `string` | `"17"` | no |
| <a name="input_storage_size"></a> [storage\_size](#input\_storage\_size) | The max storage allowed for the PostgreSQL Flexible Server in GB. Possible values are 32, 64, 128, 256, 512, 1024, 2048, 4095, 4096, 8192, 16384, and 32767. | `number` | `32` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_administrator_password"></a> [administrator\_password](#output\_administrator\_password) | n/a |
| <a name="output_administrator_username"></a> [administrator\_username](#output\_administrator\_username) | n/a |
| <a name="output_databases"></a> [databases](#output\_databases) | Map of database names to their details including local owner account credentials. |
| <a name="output_fqdn"></a> [fqdn](#output\_fqdn) | n/a |
| <a name="output_id"></a> [id](#output\_id) | n/a |
<!-- END_TF_DOCS -->