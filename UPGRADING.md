# Upgrading

## Upgrading to v2.0.0

This is the upgrade from v1.x. Coming from v0.x? Read [Upgrading to v1.0.0](#upgrading-to-v100)
first: the change of the `password_auth_enabled` default and the other v1.0.0 changes still apply.

v2.0.0 restructures how databases and access are configured. Authentication is unchanged:
`password_auth_enabled` still defaults to `false`. Go through the list, then the sections that
apply to you:

1. [The `databases` interface changed](#the-databases-interface-changed)
2. [Role names changed and are server-wide](#role-names-changed-and-are-server-wide)
3. [Local users replace `local_owner_account`](#local-users-replace-local_owner_account)
4. [Active Directory administrator groups take objects](#active-directory-administrator-groups-take-objects)
5. [The module uses the default `postgresql` provider](#the-module-uses-the-default-postgresql-provider)
6. [Removed inputs and outputs, changed defaults and requirements](#removed-inputs-and-outputs-changed-defaults-and-requirements)
7. [Moving the state](#moving-the-state)

### The `databases` interface changed

The Entra ID inputs of a database are replaced by three lists of principals, `readers`, `writers`
and `admins`. The caller now passes the principal's own values, so the module no longer looks up
groups in the directory.

| v1 | v2 |
|---|---|
| `reader_groups = [{ group_name, role_prefix }]` | `readers = [{ object_id, display_name, role_prefix }]` |
| `reader_managed_identity_object_ids = [{ object_id, principal_name, role_prefix }]` | `readers = [{ principal_id, name, client_id, role_prefix }]` |
| `writer_groups`, `writer_managed_identity_object_ids` | `writers`, with the same fields as `readers` |
| `admin_groups`, `admin_identity_object_ids` | `admins`, with the same fields as `readers` |
| `local_owner_account` | [`local_admins`](#local-users-replace-local_owner_account), or `admins` for a federated owner |

```hcl
data "azuread_group" "analysts" {
  display_name     = "Data-Analysts"
  security_enabled = true
}

databases = {
  "app" = {
    readers = [
      {
        object_id    = data.azuread_group.analysts.object_id
        display_name = data.azuread_group.analysts.display_name
        role_prefix  = "analyst"
      }
    ]
    writers = [
      {
        name         = azurerm_user_assigned_identity.app.name
        principal_id = azurerm_user_assigned_identity.app.principal_id
        client_id    = azurerm_user_assigned_identity.app.client_id
        role_prefix  = "app"
      }
    ]
  }
}
```

- **Groups use `object_id`, service principals and managed identities use `principal_id`.** The
  principal type of the `pgaadauth` security label follows from which of the two is set: a
  principal passed with `object_id` becomes a `group`, one passed with `principal_id` a `service`.
  Users are not supported.
- **Every principal needs `object_id` or `principal_id`, and one of `display_name`, `name` or
  `role_prefix`.** The plan fails otherwise. The role is named after these, and the name must be
  known at plan time, which the object ID of something created in the same apply is not.
- `admins` get `USAGE` and `CREATE` on the `public` schema, `ALL` on its tables and matching
  default privileges, which is what a principal that creates its own schema needs.
- **Default privileges for objects created by the provisioning identity are gone.** Admin roles
  used to get default privileges on tables created by the administrator login (or the principal
  in `provisioning_identity_name`) as well. They now only get them on tables they create
  themselves. `databases[*].administrator_username` is still accepted, but has no effect.

### Role names changed and are server-wide

A role is named `<role_prefix>-db-<readers|writers|admins>` when `role_prefix` is set, and after
`display_name` (groups) or `name` (managed identities) when it isn't. In v1 it was
`<role_prefix or name>_group_reader`, `_service_writer` and so on. **Every Entra role is
renamed**, also if you keep your `role_prefix`.

PostgreSQL role names are server-wide, not per database. Every `role_prefix` (or `display_name`
or `name` without one) must be unique across **all** databases of the server, otherwise creating
the second role fails. A `role_prefix` that you used in two databases needs a different one in one
of them, and the same goes for a principal you listed in two databases. Avoid binding the same
Entra principal to more than one role. [`examples/complete`](examples/complete/main.tf) shows a
layout that keeps every role unique.

### Local users replace `local_owner_account`

`local_owner_account` is removed. A local PostgreSQL user, for an application that can't use an
Entra ID token, is now declared as `local_readers`, `local_writers` or `local_admins`:

```hcl
databases = {
  "app" = {
    local_admins = [{ username = "app_owner" }]
  }
}
```

- Local users log on with a password, so they need `password_auth_enabled = true`. The plan fails
  with a precondition error otherwise. To turn password authentication off later, first replace
  the local users with Entra principals and apply.
- `local_readers` get `pg_read_all_data`. `local_writers` also get `pg_write_all_data`.
  `local_admins` are what a password `local_owner_account` was: `CONNECT` on the database, `USAGE`
  and `CREATE` on the `public` schema, and `ALL` on its tables, sequences and functions.
- **A local admin has fewer default privileges than the owner account had.** It gets them for
  tables it creates, no longer for sequences and functions, and none for objects created by the
  provisioning identity.
- **The generated password is no longer exposed.** The `databases` output contains `id` and
  `name` only, not `local_owner_account`. A generated password (`generate_password = true`, the
  default) exists only in the Terraform state. To manage the password yourself, set
  `generate_password = false` and an `ephemeral_password_version`, and pass the password through
  the ephemeral input `local_admins_ephemeral_passwords` (`local_readers_ephemeral_passwords` and
  `local_writers_ephemeral_passwords` for the others), a map of user name to password. Bump the
  version to rotate it.
- **A federated owner** (`local_owner_account` with `object_id`) becomes an entry in `admins` for
  that identity. It is no longer granted `CONNECT`, nor `ALL` on sequences and functions and
  default privileges for them.

### Active Directory administrator groups take objects

`active_directory_administrator_groups` takes the group's `object_id` and `display_name`, like
the principals above, instead of a list of group names:

```hcl
# v1
active_directory_administrator_groups = ["PostgreSQL-Admins"]

# v2
active_directory_administrator_groups = [
  {
    object_id    = data.azuread_group.admins.object_id
    display_name = data.azuread_group.admins.display_name
  }
]
```

The resources keep their address (`...active_directory_administrator.this["<group name>"]`),
so nothing moves in the state.

### The module uses the default `postgresql` provider

The module no longer declares the `postgresql.database` provider alias. Remove
`providers = { postgresql.database = postgresql.database }` from the module call and either drop
the alias from your `provider "postgresql"` block, or keep it and pass it explicitly:

```hcl
providers = {
  postgresql = postgresql.database
}
```

If your provider connects with Entra ID (`azure_identity_auth = true`), nothing else changes there:
`provisioning_identity_name` is gone, so remove it from the module call. The provider still logs
on as the Entra group that is in `active_directory_administrator_groups`.

### Removed inputs and outputs, changed defaults and requirements

**Removed:**

- `provisioning_identity_name`: it is no longer needed. Remove it from your module call.
- `use_password_override_special`: the administrator password always uses the special characters
  `!#$&()-_=+[]{}?`, which is what the default `true` gave you. If you set it to `false`, the
  password is replaced on upgrade.
- The `local_owner_account` entry in the `databases` output.

**Changed defaults:**

- `server_version` now defaults to `17` (was `14`). Set `server_version` explicitly to keep your
  version.

**New:**

- `tags`, `administrator_ephemeral_password` and `administrator_ephemeral_password_version` (a
  write-only administrator password), and the `local_*_ephemeral_passwords` inputs.

**Requirements:** Terraform `>= 1.12.0` (was `>= 1.8.5`), for write-only attributes, and the
azuread provider `>= 3.5` (was `>= 3.3`). The azurerm and postgresql constraints are unchanged in
effect, and random is now `~> 3.6` (was `>= 3.6.3`).

### Moving the state

The roles, grants and security labels now live in nested modules (`entra_rbac_reader`,
`entra_rbac_writer`, `entra_rbac_admin`, `local_reader`, `local_writer` and `local_admin`),
so their addresses change. **Move them before you apply v2.0.0.** If you don't, Terraform
destroys the old roles and creates new ones: the principals lose access to the database until the
apply finishes, and the provider reassigns objects owned by an admin role when it drops that role.

#### Do I need to move anything?

Only if a database has Entra principals or a `local_owner_account`. Run:

```bash
terraform state list | grep -E 'module\.database\["[^"]+"\]\.(postgresql_|random_password\.local_owner)'
```

- **No output**: nothing to move.
- **Output**: follow the steps below.

#### Steps

1. Switch the module to v2.0.0 and run `terraform init -upgrade`.
2. Write down, for each database, what is in the state and which principal it is. In v1 the key
   of an Entra role is its role name, for example `Data-Analysts_group_reader`.
   `terraform state show '<address>'` prints the role's `name`.
3. Write a `mapping.txt` with one line per Entra role or owner account, separated by `|`:

   ```text
   <database>|<kind>|<old key>|<new key>
   ```

   - `kind` is `reader`, `writer` or `admin` for the lists of the same name, `local_owner` for a
     password `local_owner_account`, and `federated_owner` for one with `object_id`.
   - The old key is the key from step 2. Use `-` for `local_owner` and `federated_owner`.
   - The new key is the `display_name` (groups) or `name` (managed identities) you pass in the
     v2 configuration, or the user name for `local_owner`. If you pass neither, it is the
     `object_id` or `principal_id`.

   ```text
   app|reader|Data-Analysts_group_reader|Data-Analysts
   app|writer|mi-app_service_writer|mi-app
   app|local_owner|-|app_owner
   ```
4. Generate the `moved` blocks. Set `MOD` to the address of the module call if it isn't
   `module.postgresql`:

   ```bash
   MOD=module.postgresql bash gen-moved.sh < mapping.txt > moved_postgresql_roles.tf
   ```

   Save this script as `gen-moved.sh`:

   ```bash
   #!/usr/bin/env bash
   # Reads lines "<database>|<kind>|<old key>|<new key>" and prints moved blocks.
   #   kind: reader | writer | admin | local_owner | federated_owner
   #   old key: the key in your current state (ignored for local_owner and federated_owner)
   #   new key: the display_name or name of the principal (reader, writer, admin, federated_owner),
   #            or the username (local_owner)
   set -euo pipefail
   MOD="${MOD:-module.postgresql}" # address of the module call in your configuration

   emit() { printf 'moved {\n  from = %s\n  to   = %s\n}\n\n' "$1" "$2"; }

   while IFS='|' read -r db kind old new; do
     [ -z "$db" ] && continue
     src="$MOD.module.database[\"$db\"]"
     case "$kind" in
       reader | writer | admin | federated_owner)
         if [ "$kind" = federated_owner ]; then
           dst="$src.module.entra_rbac_admin[\"$new\"]"
           emit "$src.postgresql_role.local_owner[0]" "$dst.postgresql_role.this"
           emit "$src.postgresql_security_label.local_owner[0]" "$dst.postgresql_security_label.this"
           emit "$src.postgresql_grant.local_owner_create_usage_on_schema[0]" "$dst.postgresql_grant.create_usage_on_schema[0]"
           emit "$src.postgresql_grant.local_owner_table_rights[0]" "$dst.postgresql_grant.table_rights[0]"
           emit "$src.postgresql_default_privileges.local_owner_future_table_rights_own_role[0]" "$dst.postgresql_default_privileges.future_table_rights_owner_role[0]"
           continue
         fi
         dst="$src.module.entra_rbac_$kind[\"$new\"]"
         case "$kind" in reader) label=readers ;; writer) label=writers ;; admin) label=admin ;; esac
         emit "$src.postgresql_role.$kind[\"$old\"]" "$dst.postgresql_role.this"
         emit "$src.postgresql_security_label.$label[\"$old\"]" "$dst.postgresql_security_label.this"
         if [ "$kind" = admin ]; then
           emit "$src.postgresql_grant.create_usage_on_schema[\"$old\"]" "$dst.postgresql_grant.create_usage_on_schema[0]"
           emit "$src.postgresql_grant.table_rights[\"$old\"]" "$dst.postgresql_grant.table_rights[0]"
           emit "$src.postgresql_default_privileges.future_table_rights_own_role[\"$old\"]" "$dst.postgresql_default_privileges.future_table_rights_owner_role[0]"
         fi
         ;;
       local_owner)
         dst="$src.module.local_admin[\"$new\"]"
         emit "$src.random_password.local_owner[0]" "$dst.random_password.this[0]"
         emit "$src.postgresql_role.local_owner[0]" "$dst.postgresql_role.this"
         emit "$src.postgresql_grant.local_owner_database_connect[0]" "$dst.postgresql_grant.database_connect[0]"
         emit "$src.postgresql_grant.local_owner_table_rights[0]" "$dst.postgresql_grant.owner_table_rights[0]"
         emit "$src.postgresql_grant.local_owner_sequence_rights[0]" "$dst.postgresql_grant.owner_sequence_rights[0]"
         emit "$src.postgresql_grant.local_owner_create_usage_on_schema[0]" "$dst.postgresql_grant.owner_create_usage_on_schema[0]"
         emit "$src.postgresql_grant.local_owner_function_rights[0]" "$dst.postgresql_grant.owner_function_rights[0]"
         emit "$src.postgresql_default_privileges.local_owner_future_table_rights_own_role[0]" "$dst.postgresql_default_privileges.owner_future_table_rights_own_role[0]"
         ;;
       *)
         echo "unknown kind: $kind" >&2
         exit 1
         ;;
     esac
   done
   ```

   Review the generated file: each block maps a resource to the same resource in the nested module.
5. Run `terraform plan`. Expect `has moved` lines for everything you mapped. Because
   [role names changed](#role-names-changed-and-are-server-wide), the plan also changes the name
   of each role and the security label that refers to it. **If the plan shows a role being
   replaced (destroyed and created) instead of updated in place, stop and don't apply:**
   replacing a role drops it.
6. The default privileges for objects of the provisioning identity have no new address
   (`future_table_rights_admin_account`, and the `local_owner_*_admin_account`,
   `local_owner_future_sequence_rights_own_role` and `local_owner_future_function_rights_own_role`
   ones). The plan destroys them. That is expected.
7. Apply. The `moved` blocks can be removed afterwards.

## Upgrading to v1.0.0

v1.0.0 has two breaking changes. Check both:

1. [Password authentication is opt-in](#password-authentication-is-opt-in): set `password_auth_enabled = true` if you rely on the default.
2. [Entra roles are keyed on role name](#entra-roles-are-keyed-on-role-name): move the role resources if you use Entra readers, writers or admins.

### Password authentication is opt-in

`password_auth_enabled` now defaults to `false`. A server is Entra ID only unless you opt in,
and the local administrator login and its generated password only exist when
`password_auth_enabled = true`.

**What you need to do:**

| Your configuration on v0.x | Action |
|---|---|
| `password_auth_enabled` not set (default `true`) | Add `password_auth_enabled = true` to keep password authentication, the admin login and its password. Without it, the plan disables password authentication on the server and destroys `random_password.password`, and anything that logs on with the admin password (such as the `postgresql` provider) stops working. |
| `password_auth_enabled = true` | Nothing. The plan shows `random_password.password has moved to random_password.password[0]`. |
| `password_auth_enabled = false` | The server no longer gets a local administrator. The plan destroys `random_password.password` and removes the admin password from the server configuration. Nothing could log on with it, as password authentication was already off. |

Databases with a password owner account (`local_owner_account` without `object_id`) need
`password_auth_enabled = true`; the plan fails with a precondition error otherwise. Set
`object_id` to make the owner a federated (Entra ID) account instead.

### Optional: let Terraform connect with Entra ID instead of the admin password

Upgrading to v1.0.0 doesn't require this, but it is the step towards an Entra ID only server.
Do it in separate applies, in this order:

1. **Keep `password_auth_enabled = true`** for now.
2. **Create an Entra ID security group** and add the identity Terraform runs as (the pipeline's
   managed identity or service principal) to it.
3. **Add the group to `active_directory_administrator_groups` and apply.** The `postgresql`
   provider still connects with the admin password. Don't switch the provider in the same
   apply: it would log on as the group before the server knows it, and fail with
   *"password authentication failed for user \"<group>\""*.
4. **Switch the provider to Entra ID, set `provisioning_identity_name` to the group name and
   apply.** Members of the group log on with the group name as user name and their own token:

   ```hcl
   provider "postgresql" {
     alias               = "database"
     host                = module.postgresql.fqdn
     port                = 5432
     database            = "postgres"
     username            = "<group name>"
     azure_identity_auth = true
     azure_tenant_id     = data.azurerm_client_config.current.tenant_id
     sslmode             = "require"
     superuser           = false
   }

   module "postgresql" {
     # ...
     active_directory_administrator_groups = ["<group name>"]
     provisioning_identity_name            = "<group name>"
   }
   ```

   The plan replaces the default privileges of each owner account for objects created by the
   provisioning identity (owner `<admin username>` becomes `<group name>`). Password logins of
   applications keep working. The provider gets its token through Azure's default credential
   chain, so the pipeline step must be logged on as that identity (for example the `AzureCLI`
   task or workload identity federation).
5. **To turn password authentication off**, first make every owner account federated (set
   `object_id`, and `federated = true` when the identity is created in the same apply) and apply.
   A managed identity created in that apply can take a minute to become known to Entra ID; if
   the security label fails with *"the OID isn't found in the tenant"*, apply again. Then set
   `password_auth_enabled = false` and apply separately. Azure keeps the administrator login name
   on the server, but nobody can log on with a password any more.

### Removed input `private_service_connection_is_manual`

This input was declared but never used. Remove it from your module call if you set it; it had
no effect.

### Entra roles are keyed on role name

#### What changed

The Entra ID roles a database creates for `reader_groups`, `writer_groups`, `admin_groups`,
`reader_managed_identity_object_ids`, `writer_managed_identity_object_ids` and
`admin_identity_object_ids` are now keyed on their **role name** instead of the principal's
**object ID**. For example:

```text
module.postgresql.module.database["app"].postgresql_role.reader["4353c946-523a-4bea-8696-3a476d48c799"]   # v0.x
module.postgresql.module.database["app"].postgresql_role.reader["app_reader_service_reader"]             # v1.0.0
```

The role name is known at plan time, also for identities created in the same apply. The object
ID of such an identity is not, which made the plan fail with *"Invalid for_each argument"*.

The roles in PostgreSQL do not change. Only their addresses in the Terraform state do.

#### Am I affected?

Only if any database in `databases` uses one of the six inputs above. Run:

```bash
terraform state list | grep -E 'module\.database\[.*\]\.postgresql_(role|grant|default_privileges|security_label)\.[a-z_]+\["[0-9a-f-]{36}"\]'
```

- **No output**: nothing to do for this change.
- **Output**: move these resources to their new addresses **before** you apply v1.0.0, as
  described below. If you don't, Terraform drops and recreates the roles: the principals lose
  access to the database until the apply finishes, and the provider reassigns objects owned by
  an admin role when it drops that role.

#### How to upgrade

1. Switch the module to v1.0.0 and run `terraform init -upgrade`.
2. Generate `moved` blocks from your current state. The new key is the role name, which the
   state already holds (`name` for roles, `role` for grants and default privileges,
   `object_name` for security labels):

   ```bash
   terraform show -json | jq -r '
     .. | objects | select(has("address") and has("values") and has("index"))
     | select(.address | test("module\\.database\\[.*\\]\\.postgresql_(role|grant|default_privileges|security_label)\\."))
     | select(.index | type == "string" and test("^[0-9a-f-]{36}$"))
     | (.values.name // .values.role // .values.object_name) as $role
     | "moved {\n  from = \(.address)\n  to   = \(.address | sub("\\[\"[0-9a-f-]{36}\"\\]$"; "[\"" + $role + "\"]"))\n}\n"
   ' > moved_postgresql_roles.tf
   ```

   Review the file: each block maps an object ID key to a role name key of the same resource.
3. Run `terraform plan`. Expect only `has moved` lines: nothing added, changed or destroyed
   (apart from changes you made yourself).
4. Apply. The `moved` blocks can be removed afterwards.

### Coming from the `feature/add_fedauth` branch

That branch already keyed roles on their name and dropped the admin login when password
authentication was off, which is what v1.0.0 does. Keep `password_auth_enabled = false` and no
`moved` blocks are needed.
