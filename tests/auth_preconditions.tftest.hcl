# Authentication defaults and the preconditions that guard them.

mock_provider "azurerm" {}
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
  name                = "psql-test"
  resource_group_name = "rg-test"
  location            = "westeurope"
  sku                 = "B_Standard_B1ms"
  storage_size        = 32

  customer_managed_key = {
    key_vault_key_id                  = "https://kv-test.vault.azure.net/keys/cmk/00000000000000000000000000000000"
    primary_user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"
  }
}

run "entra_only_is_the_default" {
  command = plan

  variables {
    databases = {
      "app" = {
        readers = [{ object_id = "11111111-1111-1111-1111-111111111111", display_name = "Readers" }]
      }
    }
  }

  assert {
    condition     = length(random_password.password) == 0
    error_message = "A server without password_auth_enabled must not generate an administrator password."
  }
}

run "password_auth_creates_administrator_password" {
  command = plan

  variables {
    password_auth_enabled = true
  }

  assert {
    condition     = length(random_password.password) == 1
    error_message = "password_auth_enabled = true must generate an administrator password."
  }
}

run "local_users_need_password_auth" {
  command = plan

  variables {
    databases = {
      "app" = {
        local_readers = [{ username = "reporting" }]
      }
    }
  }

  expect_failures = [azurerm_postgresql_flexible_server.this]
}

run "local_users_with_password_auth" {
  command = plan

  variables {
    password_auth_enabled = true
    databases = {
      "app" = {
        local_admins = [{ username = "app_owner" }]
      }
    }
  }
}

run "at_least_one_auth_method" {
  command = plan

  variables {
    password_auth_enabled         = false
    active_directory_auth_enabled = false
  }

  expect_failures = [azurerm_postgresql_flexible_server.this]
}
