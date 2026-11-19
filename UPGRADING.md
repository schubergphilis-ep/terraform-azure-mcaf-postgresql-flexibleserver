# Upgrading

## Upgrading to v1.0.0

### What changed

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

### Am I affected?

Only if any database in `databases` uses one of the six inputs above. Run:

```bash
terraform state list | grep -E 'module\.database\[.*\]\.postgresql_(role|grant|default_privileges|security_label)\.[a-z_]+\["[0-9a-f-]{36}"\]'
```

- **No output**: nothing to do. Upgrade and expect only
  `random_password.password has moved to random_password.password[0]` in the plan.
- **Output**: move these resources to their new addresses **before** you apply v1.0.0, as
  described below. If you don't, Terraform drops and recreates the roles: the principals lose
  access to the database until the apply finishes, and the provider reassigns objects owned by
  an admin role when it drops that role.

### How to upgrade

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

That branch already keyed roles on their name, so step 2 is not needed. It also always dropped
the local administrator when password authentication was disabled, which is now an explicit
input. Set it to keep the server as it is:

```hcl
password_auth_enabled       = false
administrator_login_enabled = false
```
