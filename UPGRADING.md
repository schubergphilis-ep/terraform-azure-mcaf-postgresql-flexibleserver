# Upgrading

## Upgrading to v2.0.0

v2.0.0 scopes database access to the database it is configured for. In v1.x, Entra readers,
writers and admins were members of the server-wide roles `pg_read_all_data` and
`pg_write_all_data`, and `PUBLIC` could connect to every database. A reader on one database could
therefore read every database on the server, and a writer could write to all of them.

### What changes

- Each database gets PostgreSQL group roles (`NOLOGIN`) `<database>_readers`, `_writers` and
  `_admins` with privileges on that database only (see [Database access](README.md#database-access)).
- The login roles of Entra groups and managed identities are a member of those groups instead of
  `pg_read_all_data` / `pg_write_all_data`. **Their names don't change**, so applications keep
  their database user name.
- `CONNECT` and `TEMPORARY` on each database are revoked from `PUBLIC`. The access groups, the
  owner account and `azure_pg_admin` (server administrators) get `CONNECT`.
- Each Entra principal can be used once across all databases and access levels; the plan fails
  with a precondition error otherwise.
- Databases are dropped before their roles, so removing a database whose owner created tables no
  longer fails with *"role ... cannot be dropped because some objects depend on it"*.
- New: `object_id` on `reader_groups`, `writer_groups` and `admin_groups` to skip the group lookup
  in Microsoft Graph.

### What you need to do

No state moves are needed. The plan creates the access groups and their grants, updates the
Entra login roles in place (membership only) and removes the per-admin grants that the
`_admins` group replaces. During the apply, a principal can lack its privileges for a few
seconds while its membership moves to the access group, so apply outside peak hours. Before you
apply, check:

| Situation | Action |
|---|---|
| A principal needs access to more than one database (it used to get that through `pg_read_all_data`) | Add it to each database it needs. Using the same principal twice fails; create an Entra ID group per database and access level and add the principal to those groups. |
| The same group or managed identity is listed more than once (other database or access level) | The plan fails with *"Each Entra ID group and managed identity can be used once"*. Use an Entra ID group per database and access level. |
| Roles you created yourself, outside this module, connect to a database | They can no longer connect through `PUBLIC`. Grant them membership of an access group, for example `GRANT app_readers TO my_role;`, or `CONNECT` on the database. |

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
