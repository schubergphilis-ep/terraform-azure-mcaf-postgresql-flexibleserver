# terraform-azure-mcaf-postgresql-flexibleserver

Terraform module for an Azure Database for PostgreSQL Flexible Server with customer-managed key
encryption, Entra ID authentication and databases with scoped access.

## Usage

```hcl
module "postgresql" {
  source  = "schubergphilis-ep/mcaf-postgresql-flexibleserver/azure"
  version = "~> 2.0"

  providers = {
    postgresql.database = postgresql.database
  }

  name                = "psql-example"
  resource_group_name = "rg-example"
  location            = "westeurope"
  sku                 = "GP_Standard_D2ds_v5"

  customer_managed_key = {
    key_vault_key_id                  = azurerm_key_vault_key.cmk.versionless_id
    primary_user_assigned_identity_id = azurerm_user_assigned_identity.cmk.id
  }

  # The Entra principal the postgresql provider connects as (see the complete example).
  provisioning_identity_name = "terraform-deployer"

  databases = {
    app = {
      local_owner_account = { username = "app_owner", object_id = azurerm_user_assigned_identity.app.principal_id, federated = true }
      reader_groups       = [{ group_name = "app-readers", object_id = azuread_group.app_readers.object_id }]
    }
  }
}
```

Password authentication is off by default (Entra ID only). Set `password_auth_enabled = true`
for a local administrator or password owner accounts. See [examples](examples) for complete
configurations, including the `postgresql` provider.

## Database access

Access is scoped per database:

```text
Entra group / managed identity --(pgaadauth label)--> login role --(member of)--> <database>_readers --(privileges)--> <database>
```

- Each database gets PostgreSQL group roles (`NOLOGIN`) `<database>_readers`, `_writers` and
  `_admins` with privileges on that database only. `PUBLIC` cannot connect; only these groups,
  the owner account and server administrators (`azure_pg_admin`) can.
- Each Entra ID group or managed identity in `reader_groups`, `writer_groups`, `admin_groups` or
  the `*_managed_identity_object_ids` lists gets a login role, mapped to the Entra object with a
  `pgaadauth` security label, that is a member of the matching group. Members of an Entra group
  log on with the group's role name as user name and their own token.
- Each Entra principal can be used once across all databases. To give a principal access to more
  than one database, create an Entra ID group per database and access level and add the
  principal to those groups.
- You create the Entra groups and identities yourself. Pass the group's `object_id` to skip the
  lookup by name, so Terraform needs no Microsoft Graph permissions.

| Access group | Schema `public` | Tables | Sequences |
|---|---|---|---|
| `<database>_readers` | USAGE | SELECT | SELECT |
| `<database>_writers` | USAGE | SELECT, INSERT, UPDATE, DELETE | SELECT, USAGE, UPDATE |
| `<database>_admins` | USAGE, CREATE | ALL | ALL |

Tables and sequences created later by the owner account, the provisioning identity or an admin get
the same privileges by default.

## Removing a database

Remove it from `databases`. Terraform drops the database first, including the tables the
application created in it, and then its roles. Don't combine this with changes to the server
itself in the same run.

## Decommissioning (removing the module)

For example when a workload moves to another database engine. The `postgresql` provider is
configured from this module's outputs and is needed to remove the roles and grants inside the
server. Removing the module and the provider in one step fails with
*"Reference to undeclared module"* or *"Provider configuration not present"*. Use one of these:

- **Two applies (recommended):** set `databases = {}` and apply, so the provider removes the
  databases, roles and grants. Then remove the module and the `postgresql` provider and apply
  again.
- **One apply:** the roles and grants disappear with the server anyway, so let Terraform forget
  them first, then remove the module and the provider:

  ```bash
  terraform state rm 'module.postgresql.module.database'
  ```

A `removed` block doesn't help here: it also needs the provider configuration.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.5 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 3.3.0, < 4.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.20.0, < 5.0.0 |
| <a name="requirement_postgresql"></a> [postgresql](#requirement\_postgresql) | >= 1.25.0, < 2.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.3, < 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | 3.10.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.81.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.1 |

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
| [azuread_group.active_directory_administrator_groups](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/group) | data source |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_active_directory_administrator_groups"></a> [active\_directory\_administrator\_groups](#input\_active\_directory\_administrator\_groups) | n/a | `list(string)` | `[]` | no |
| <a name="input_active_directory_auth_enabled"></a> [active\_directory\_auth\_enabled](#input\_active\_directory\_auth\_enabled) | Whether Active Directory authentication is enabled for the PostgreSQL Flexible Server. | `bool` | `true` | no |
| <a name="input_administrator_username"></a> [administrator\_username](#input\_administrator\_username) | n/a | `string` | `"sbp_administrator"` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Number of days to keep the postgress backup, between 7 and 35 | `number` | `7` | no |
| <a name="input_customer_managed_key"></a> [customer\_managed\_key](#input\_customer\_managed\_key) | CMK configuration for the postgresql server. | <pre>object({<br/>    key_vault_key_id                  = string<br/>    primary_user_assigned_identity_id = string<br/>  })</pre> | n/a | yes |
| <a name="input_databases"></a> [databases](#input\_databases) | A map of databases to create on the PostgreSQL Flexible Server. The map key is used as the database name.<br/><br/>Access is scoped to the database. Each database gets PostgreSQL group roles (NOLOGIN)<br/>`<database>_readers`, `<database>_writers` and `<database>_admins` that hold the privileges on<br/>that database only, and only these groups, the owner account and server administrators may<br/>connect to it. Each Entra ID group or managed identity below gets a login role, mapped to the<br/>Entra object with a `pgaadauth` security label, that is a member of the matching group.<br/>Members of an Entra group log on with the group's role name as user name and their own token.<br/><br/>Readers can read tables and sequences, writers can also insert, update and delete, and admins<br/>have all privileges on tables and sequences and can create objects in the `public` schema.<br/>Objects created later by the owner account, the provisioning identity or an admin get the same<br/>privileges by default.<br/><br/>Each Entra ID group and managed identity can be used once across all databases and access<br/>levels. To give a principal access to more than one database, create an Entra ID group per<br/>database and access level (for example `app-readers` and `app2-writers`) and add the principal<br/>to those groups.<br/><br/>Each database object supports the following properties:<br/>- `charset`              - (Optional) The charset of the PostgreSQL database. Defaults to `UTF8`.<br/>- `collation`            - (Optional) The collation of the PostgreSQL database. Defaults to `en_US.utf8`.<br/>- `administrator_username` - (Optional) The administrator username for the PostgreSQL server. If not specified, the server's default administrator username is used.<br/><br/>- `reader_groups` - (Optional) A list of Entra ID groups to grant read access to the database.<br/>  - `group_name`  - (Required) The name of the Entra ID group. Used for the role name, and to look up the group when `object_id` is not set.<br/>  - `object_id`   - (Optional) The object ID of the Entra ID group. Skips the lookup by name, so Terraform needs no Microsoft Graph permissions for it.<br/>  - `role_prefix` - (Optional) A prefix for the database role name.<br/><br/>- `reader_managed_identity_object_ids` - (Optional) A list of managed identities to grant read access to the database.<br/>  - `object_id`      - (Required) The object ID of the managed identity.<br/>  - `principal_name` - (Required) The principal name of the managed identity.<br/>  - `role_prefix`    - (Optional) A prefix for the database role name.<br/><br/>- `writer_groups` - (Optional) A list of Entra ID groups to grant write access to the database.<br/>  - `group_name`  - (Required) The name of the Entra ID group. Used for the role name, and to look up the group when `object_id` is not set.<br/>  - `object_id`   - (Optional) The object ID of the Entra ID group. Skips the lookup by name, so Terraform needs no Microsoft Graph permissions for it.<br/>  - `role_prefix` - (Optional) A prefix for the database role name.<br/><br/>- `writer_managed_identity_object_ids` - (Optional) A list of managed identities to grant write access to the database.<br/>  - `object_id`      - (Required) The object ID of the managed identity.<br/>  - `principal_name` - (Required) The principal name of the managed identity.<br/>  - `role_prefix`    - (Optional) A prefix for the database role name.<br/><br/>- `admin_groups` - (Optional) A list of Entra ID groups to grant admin access to the database.<br/>  - `group_name`  - (Required) The name of the Entra ID group. Used for the role name, and to look up the group when `object_id` is not set.<br/>  - `object_id`   - (Optional) The object ID of the Entra ID group. Skips the lookup by name, so Terraform needs no Microsoft Graph permissions for it.<br/>  - `role_prefix` - (Optional) A prefix for the database role name.<br/><br/>- `admin_identity_object_ids` - (Optional) A list of managed identities to grant admin access to the database.<br/>  - `object_id`      - (Required) The object ID of the managed identity.<br/>  - `principal_name` - (Required) The principal name of the managed identity.<br/>  - `role_prefix`    - (Optional) A prefix for the database role name.<br/><br/>- `local_owner_account` - (Optional) A PostgreSQL account with owner access, for applications that manage their own schema. Authentication mode is selected by whether `object_id` is set: password mode (default) creates a role with a password; federated mode (`object_id` set) creates an Entra ID (Azure AD) role that logs on with a token and has no password. The Entra identity itself is not created by this module.<br/>  - `username`          - (Required) The name of the PostgreSQL owner role.<br/>  - `generate_password` - (Optional) Password mode only. Whether to auto-generate a password. Defaults to `true`. Set to `false` if the password is managed outside of Terraform.<br/>  - `object_id`         - (Optional) The Entra ID object ID of a caller-managed managed identity, service principal, or group. Setting this switches the owner account to federated (token) logon.<br/>  - `principal_type`    - (Optional) The Entra principal type: `ServicePrincipal`, `Group`, or `User`. Defaults to `ServicePrincipal`. | <pre>map(object({<br/>    charset                = optional(string, "UTF8")<br/>    collation              = optional(string, "en_US.utf8")<br/>    administrator_username = optional(string)<br/><br/>    local_owner_account = optional(object({<br/>      username          = string<br/>      generate_password = optional(bool, true)<br/>      object_id         = optional(string)<br/>      principal_type    = optional(string, "ServicePrincipal")<br/>      federated         = optional(bool)<br/>    }))<br/><br/>    reader_groups = optional(list(object({<br/>      group_name  = string<br/>      object_id   = optional(string)<br/>      role_prefix = optional(string)<br/>    })), [])<br/><br/>    reader_managed_identity_object_ids = optional(list(object({<br/>      object_id      = string<br/>      principal_name = string<br/>      role_prefix    = optional(string)<br/>    })), [])<br/><br/>    writer_groups = optional(list(object({<br/>      group_name  = string<br/>      object_id   = optional(string)<br/>      role_prefix = optional(string)<br/>    })), [])<br/><br/>    writer_managed_identity_object_ids = optional(list(object({<br/>      object_id      = string<br/>      principal_name = string<br/>      role_prefix    = optional(string)<br/>    })), [])<br/><br/>    admin_groups = optional(list(object({<br/>      group_name  = string<br/>      object_id   = optional(string)<br/>      role_prefix = optional(string)<br/>    })), [])<br/><br/>    admin_identity_object_ids = optional(list(object({<br/>      object_id      = string<br/>      principal_name = string<br/>      role_prefix    = optional(string)<br/>    })), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_delegated_subnet_id"></a> [delegated\_subnet\_id](#input\_delegated\_subnet\_id) | The ID of the delegated subnet for the PostgreSQL Flexible Server. This subnet must have the 'Microsoft.DBforPostgreSQL/flexibleServers' service delegation. | `string` | `null` | no |
| <a name="input_geo_redundant_backup_enabled"></a> [geo\_redundant\_backup\_enabled](#input\_geo\_redundant\_backup\_enabled) | Whether geo-redundant backup is enabled for the PostgreSQL Flexible Server. | `bool` | `true` | no |
| <a name="input_high_availability_mode"></a> [high\_availability\_mode](#input\_high\_availability\_mode) | The high availability mode for the PostgreSQL Flexible Server. Possible values are 'ZoneRedundant' or 'SameZone'. | `string` | `"ZoneRedundant"` | no |
| <a name="input_high_availability_standby_zone"></a> [high\_availability\_standby\_zone](#input\_high\_availability\_standby\_zone) | The availability zone for the standby server when high availability is enabled. | `string` | `"2"` | no |
| <a name="input_high_available"></a> [high\_available](#input\_high\_available) | Whether the postgresql server should be HA. | `bool` | `true` | no |
| <a name="input_identity_type"></a> [identity\_type](#input\_identity\_type) | The type of identity to use for the PostgreSQL Flexible Server. Possible values are 'UserAssigned' or 'SystemAssigned'. | `string` | `"UserAssigned"` | no |
| <a name="input_location"></a> [location](#input\_location) | The location of the postgresql server. | `string` | n/a | yes |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | A custom maintenance window for the PostgreSQL Flexible Server. If not specified, the system-managed maintenance window is used.<br/><br/>The maintenance window object supports the following properties:<br/>- `day_of_week`  - (Optional) The day of the week for the maintenance window, where `0` is Sunday and `6` is Saturday. Defaults to `0`.<br/>- `start_hour`   - (Optional) The start hour (UTC) for the maintenance window, between `0` and `23`. Defaults to `0`.<br/>- `start_minute` - (Optional) The start minute for the maintenance window, between `0` and `59`. Defaults to `0`. | <pre>object({<br/>    day_of_week  = optional(number, 0)<br/>    start_hour   = optional(number, 0)<br/>    start_minute = optional(number, 0)<br/>  })</pre> | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the postgresql server. | `string` | n/a | yes |
| <a name="input_password_auth_enabled"></a> [password\_auth\_enabled](#input\_password\_auth\_enabled) | Whether password authentication is enabled for the PostgreSQL Flexible Server. Opt-in: when false (the default), the server is Entra ID only and gets no local administrator login or password. Set to true for a local administrator with a generated password, or for password owner accounts. | `bool` | `false` | no |
| <a name="input_private_dns_zone_id"></a> [private\_dns\_zone\_id](#input\_private\_dns\_zone\_id) | The ID of the private DNS zone for the PostgreSQL Flexible Server. Required when using a delegated subnet. | `string` | `null` | no |
| <a name="input_provisioning_identity_name"></a> [provisioning\_identity\_name](#input\_provisioning\_identity\_name) | The PostgreSQL login name that the postgresql provider authenticates as when creating roles and privileges. Defaults to the server administrator username (password mode). When password authentication is disabled and the provider connects via Entra ID, set this to the Entra principal name Terraform runs as so that object-owner default privileges are attributed to the correct owner. Can be overridden per database via the database's administrator\_username. Must be the role name as PostgreSQL stores it: at most 63 characters, as PostgreSQL truncates longer role names (e.g. guest UPNs with #EXT#). | `string` | `null` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Whether public network access is enabled for the PostgreSQL Flexible Server. | `bool` | `false` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of the resource group in which the postgresql server will be created. | `string` | n/a | yes |
| <a name="input_server_version"></a> [server\_version](#input\_server\_version) | The version of the postgresql server. | `string` | `"14"` | no |
| <a name="input_sku"></a> [sku](#input\_sku) | The sku of the postgresql server. | `string` | n/a | yes |
| <a name="input_storage_size"></a> [storage\_size](#input\_storage\_size) | The max storage allowed for the PostgreSQL Flexible Server in GB. Possible values are 32, 64, 128, 256, 512, 1024, 2048, 4095, 4096, 8192, 16384, and 32767. | `number` | `32` | no |
| <a name="input_use_password_override_special"></a> [use\_password\_override\_special](#input\_use\_password\_override\_special) | Set true to use '!#$&()-\_=+[]{}?' as special characters, false for default behavior. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_administrator_password"></a> [administrator\_password](#output\_administrator\_password) | The generated administrator password. Null when password\_auth\_enabled is false. |
| <a name="output_administrator_username"></a> [administrator\_username](#output\_administrator\_username) | n/a |
| <a name="output_databases"></a> [databases](#output\_databases) | Map of database names to their details: the local owner account credentials and the access group and login roles. |
| <a name="output_fqdn"></a> [fqdn](#output\_fqdn) | n/a |
| <a name="output_id"></a> [id](#output\_id) | n/a |
<!-- END_TF_DOCS -->