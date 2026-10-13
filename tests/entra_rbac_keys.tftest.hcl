# Entra RBAC for_each keys must be known at plan time.

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

run "managed_identity_keyed_on_name" {
  command = plan

  variables {
    databases = {
      "app" = {
        writers = [
          {
            name         = "id-app"
            principal_id = "44444444-4444-4444-4444-444444444444"
          }
        ]
      }
    }
  }
}

run "all_three_role_types" {
  command = plan

  variables {
    databases = {
      "app" = {
        readers = [{ display_name = "Data-Analysts", object_id = "11111111-1111-1111-1111-111111111111" }]
        writers = [{ display_name = "Developers", object_id = "22222222-2222-2222-2222-222222222222" }]
        admins  = [{ display_name = "Database-Admins", object_id = "33333333-3333-3333-3333-333333333333" }]
      }
    }
  }
}

run "principal_created_in_same_plan" {
  command = plan

  module {
    source = "./tests/fixtures/computed-principal"
  }

  override_data {
    target = module.postgresql.data.azurerm_client_config.current
    values = {
      tenant_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  variables {
    resource_group_name = "rg-test"
    location            = "westeurope"
  }
}
