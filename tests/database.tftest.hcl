# Unit tests for the database submodule (plan only, mocked providers).

mock_provider "azurerm" {}
mock_provider "azuread" {}
mock_provider "random" {}

mock_provider "postgresql" {
  alias = "database"
}

variables {
  name                       = "app"
  postgresql_server_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-test"
  provisioning_identity_name = "terraform-deployer"
}

run "reader_is_member_of_the_database_group_only" {
  command = plan

  module {
    source = "./modules/database"
  }

  providers = {
    azurerm             = azurerm
    azuread             = azuread
    random              = random
    postgresql.database = postgresql.database
  }

  variables {
    reader_managed_identity_object_ids = [{ object_id = "11111111-1111-1111-1111-111111111111", principal_name = "app-reader" }]
  }

  assert {
    condition     = postgresql_role.reader["app-reader_service_reader"].roles == toset(["app_readers"])
    error_message = "The reader must only be a member of app_readers (no server-wide pg_read_all_data)."
  }

  assert {
    condition     = postgresql_role.access["readers"].login == false
    error_message = "The access group must be a NOLOGIN role."
  }

  assert {
    condition     = postgresql_grant.access_tables["readers"].privileges == toset(["SELECT"]) && postgresql_grant.access_tables["readers"].database == "app"
    error_message = "Readers must only get SELECT on the tables of this database."
  }

  assert {
    condition     = postgresql_security_label.readers["app-reader_service_reader"].label == "aadauth,oid=11111111-1111-1111-1111-111111111111,type=service"
    error_message = "The reader must be mapped to its managed identity with a pgaadauth label."
  }
}

run "public_cannot_connect" {
  command = plan

  module {
    source = "./modules/database"
  }

  providers = {
    azurerm             = azurerm
    azuread             = azuread
    random              = random
    postgresql.database = postgresql.database
  }

  assert {
    condition     = postgresql_grant.revoke_public_connect.role == "public" && length(postgresql_grant.revoke_public_connect.privileges) == 0
    error_message = "CONNECT must be revoked from PUBLIC."
  }

  assert {
    condition     = postgresql_grant.azure_pg_admin_connect.privileges == toset(["CONNECT"])
    error_message = "Server administrators (azure_pg_admin) must keep CONNECT."
  }

  assert {
    condition     = length(postgresql_role.access) == 0
    error_message = "No access groups may be created for a database without principals."
  }
}

run "writer_and_admin_privileges" {
  command = plan

  module {
    source = "./modules/database"
  }

  providers = {
    azurerm             = azurerm
    azuread             = azuread
    random              = random
    postgresql.database = postgresql.database
  }

  variables {
    writer_managed_identity_object_ids = [{ object_id = "22222222-2222-2222-2222-222222222222", principal_name = "app-writer" }]
    admin_identity_object_ids          = [{ object_id = "33333333-3333-3333-3333-333333333333", principal_name = "app-admin" }]
    local_owner_account                = { username = "app_owner" }
  }

  assert {
    condition     = postgresql_grant.access_tables["writers"].privileges == toset(["SELECT", "INSERT", "UPDATE", "DELETE"])
    error_message = "Writers must get SELECT, INSERT, UPDATE and DELETE on tables."
  }

  assert {
    condition     = postgresql_grant.access_schema["admins"].privileges == toset(["USAGE", "CREATE"])
    error_message = "Admins must be able to create objects in the public schema."
  }

  # Default privileges for objects created later by the provisioning identity, the owner account
  # and the admin, for tables and sequences, per access group.
  assert {
    condition     = length(postgresql_default_privileges.access) == 2 * 3 * 2
    error_message = "Expected default privileges for 2 groups x 3 object owners x 2 object types."
  }

  assert {
    condition     = postgresql_default_privileges.access["writers/app_owner/table"].privileges == toset(["SELECT", "INSERT", "UPDATE", "DELETE"])
    error_message = "Tables created later by the owner account must be writable for the writers."
  }
}

run "group_with_object_id_skips_the_lookup" {
  command = plan

  module {
    source = "./modules/database"
  }

  providers = {
    azurerm             = azurerm
    azuread             = azuread
    random              = random
    postgresql.database = postgresql.database
  }

  variables {
    reader_groups = [{ group_name = "app-readers-group", object_id = "44444444-4444-4444-4444-444444444444" }]
  }

  assert {
    condition     = length(data.azuread_group.reader_groups) == 0
    error_message = "A group with an object_id must not be looked up in Microsoft Graph."
  }

  assert {
    condition     = postgresql_security_label.readers["app-readers-group_group_reader"].label == "aadauth,oid=44444444-4444-4444-4444-444444444444,type=group"
    error_message = "The group must be mapped with type=group."
  }

  assert {
    condition     = postgresql_role.reader["app-readers-group_group_reader"].roles == toset(["app_readers"])
    error_message = "The group role must be a member of app_readers."
  }
}
