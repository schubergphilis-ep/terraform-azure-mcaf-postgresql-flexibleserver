# Fixture for tests/entra_rbac_keys.tftest.hcl.
#
# Creates the managed identity in the SAME plan as the module call, so its principal_id is
# unknown at plan time. That is the condition that broke the Entra RBAC for_each: keys must
# be derivable from configuration, and principal_id is a computed attribute.
#
# Do not replace this with a value passed in from a previous run block — an applied output is
# a known value and would no longer reproduce the failure.

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.25"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "postgresql" {
  host = "127.0.0.1"
  port = 5432
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "id-test-app"
  resource_group_name = var.resource_group_name
  location            = var.location
}

module "postgresql" {
  source = "../../../"

  name                = "psql-test-keys"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku          = "B_Standard_B1ms"
  storage_size = 32

  password_auth_enabled         = false
  active_directory_auth_enabled = true

  customer_managed_key = {
    key_vault_key_id                  = "https://kv-test.vault.azure.net/keys/cmk/00000000000000000000000000000000"
    primary_user_assigned_identity_id = azurerm_user_assigned_identity.app.id
  }

  databases = {
    "app" = {
      # name is a configured argument and therefore known at plan time; principal_id is not.
      writers = [
        {
          name         = azurerm_user_assigned_identity.app.name
          principal_id = azurerm_user_assigned_identity.app.principal_id
        }
      ]
    }
  }
}
