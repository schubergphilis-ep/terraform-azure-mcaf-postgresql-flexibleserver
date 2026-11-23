# A local user gets either a generated password, which is output, or one the caller supplies.

mock_provider "azurerm" {
  # The database resource parses the server ID, so the mock needs a real-looking one.
  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-test"
    }
  }
}
mock_provider "azuread" {}
mock_provider "random" {}
mock_provider "postgresql" {}

# azurerm rejects the mock's non-UUID tenant_id.
override_data {
  target = data.azurerm_client_config.current
  values = {
    tenant_id = "00000000-0000-0000-0000-000000000000"
  }
}

variables {
  name                  = "psql-test"
  resource_group_name   = "rg-test"
  location              = "westeurope"
  sku                   = "B_Standard_B1ms"
  storage_size          = 32
  password_auth_enabled = true

  customer_managed_key = {
    key_vault_key_id                  = "https://kv-test.vault.azure.net/keys/cmk/00000000000000000000000000000000"
    primary_user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"
  }
}

run "generated_passwords_are_output" {
  command = apply

  variables {
    databases = {
      "app" = {
        local_readers = [{ username = "reporting" }]
        local_writers = [{ username = "importer" }]
        local_admins  = [{ username = "app_owner" }]
      }
    }
  }

  assert {
    condition     = nonsensitive(output.databases["app"].local_users["reporting"].password != null && output.databases["app"].local_users["reporting"].access == "reader")
    error_message = "A generated local reader password must be in the databases output."
  }

  assert {
    condition     = nonsensitive(output.databases["app"].local_users["importer"].password != null && output.databases["app"].local_users["importer"].access == "writer")
    error_message = "A generated local writer password must be in the databases output."
  }

  assert {
    condition     = nonsensitive(output.databases["app"].local_users["app_owner"].password != null && output.databases["app"].local_users["app_owner"].access == "admin")
    error_message = "A generated local admin password must be in the databases output."
  }
}

run "supplied_password_is_not_output" {
  command = apply

  variables {
    databases = {
      "app" = {
        local_admins = [{ username = "app_owner", generate_password = false, ephemeral_password_version = 1 }]
      }
    }
    local_admins_ephemeral_passwords = { app_owner = "supplied-by-the-caller" }
  }

  assert {
    condition     = nonsensitive(output.databases["app"].local_users["app_owner"].password == null)
    error_message = "A password the caller supplies must not be in the databases output."
  }
}

run "generated_and_supplied_passwords_together" {
  command = apply

  variables {
    databases = {
      "app" = {
        local_readers = [{ username = "reporting" }]
        local_admins  = [{ username = "app_owner", generate_password = false, ephemeral_password_version = 1 }]
      }
    }
    local_admins_ephemeral_passwords = { app_owner = "supplied-by-the-caller" }
  }

  assert {
    condition     = nonsensitive(output.databases["app"].local_users["reporting"].password != null && output.databases["app"].local_users["app_owner"].password == null)
    error_message = "Only the generated password may be in the databases output."
  }
}

run "rejects_version_with_generate_password" {
  command = plan

  variables {
    databases = {
      "app" = {
        local_admins = [{ username = "app_owner", ephemeral_password_version = 1 }]
      }
    }
    local_admins_ephemeral_passwords = { app_owner = "supplied-by-the-caller" }
  }

  expect_failures = [var.databases]
}

run "rejects_supplied_password_without_version" {
  command = plan

  variables {
    databases = {
      "app" = {
        local_admins = [{ username = "app_owner", generate_password = false }]
      }
    }
    local_admins_ephemeral_passwords = { app_owner = "supplied-by-the-caller" }
  }

  expect_failures = [var.databases]
}

run "rejects_supplied_password_without_entry" {
  command = plan

  variables {
    databases = {
      "app" = {
        local_writers = [{ username = "importer", generate_password = false, ephemeral_password_version = 1 }]
      }
    }
  }

  expect_failures = [var.local_writers_ephemeral_passwords]
}

run "rejects_entry_for_a_generated_password" {
  command = plan

  variables {
    databases = {
      "app" = {
        local_readers = [{ username = "reporting" }]
      }
    }
    local_readers_ephemeral_passwords = { reporting = "ignored-before-this-check" }
  }

  expect_failures = [var.local_readers_ephemeral_passwords]
}
