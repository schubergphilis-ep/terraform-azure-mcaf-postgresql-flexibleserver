# Guards the Entra RBAC for_each keys.
#
# modules/database keys its reader/writer/admin for_each maps on a value derived from each
# principal. Those keys become resource addresses, so Terraform requires them to be known at
# plan time. Keying on object_id/principal_id broke that: both are computed, so any caller
# passing a principal created in the same apply failed with "Invalid for_each argument" and
# nothing was applied at all.
#
# terraform validate cannot catch this — it does not evaluate for_each. A plan is required,
# which is what these runs do. Mock providers are enough: computed attributes stay unknown
# under mocks, so the failure still reproduces.

mock_provider "azurerm" {}
mock_provider "azuread" {}
mock_provider "random" {}
mock_provider "postgresql" {}

# Mock providers invent values for computed attributes, and the invented tenant_id is not a
# UUID, which the azurerm provider rejects. Pin it.
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

# A managed identity is identified by name (known at plan) plus principal_id (computed, used
# only for the security label). Before the fix the key came from principal_id and this failed.
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

# Groups are identified by display_name; readers, writers and admins must all key cleanly.
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

# The regression that motivated the fix: the principal is created in the same plan, so its
# principal_id is unknown. Runs against a fixture because the unknown value has to originate
# inside the plan under test.
run "principal_created_in_same_plan" {
  command = plan

  module {
    source = "./tests/fixtures/computed-principal"
  }

  # The module under test is nested one level down in this fixture.
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
