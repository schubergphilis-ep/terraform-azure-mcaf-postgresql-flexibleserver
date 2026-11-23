# Complete Example
# This example demonstrates a full configuration for the PostgreSQL Flexible Server module
# with multiple databases and role-based access control.

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.25.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Password-based provider connection (works when password_auth_enabled = true).
provider "postgresql" {
  host            = module.postgresql.fqdn
  port            = 5432
  username        = module.postgresql.administrator_username
  password        = module.postgresql.administrator_password
  sslmode         = "require"
  connect_timeout = 15
  superuser       = false
}

# --- Alternative: connect using Entra ID (Azure AD) instead of a password ---
# Use this when password_auth_enabled = false (or whenever you prefer federated logon). The
# cyrilgdn/postgresql provider obtains an Entra token via DefaultAzureCredential and uses it to
# authenticate, so no password is needed. Requirements:
#   - active_directory_auth_enabled = true on the server.
#   - The identity running Terraform must be a member of one of the
#     active_directory_administrator_groups (so it may create roles).
#   - Set `username` to that Entra principal name.
#
# provider "postgresql" {
#   host                = module.postgresql.fqdn
#   port                = 5432
#   username            = "terraform-deployer" # Entra principal name Terraform runs as
#   sslmode             = "require"
#   connect_timeout     = 15
#   superuser           = false
#   azure_identity_auth = true
#   azure_tenant_id     = data.azurerm_client_config.current.tenant_id
# }

resource "azurerm_resource_group" "example" {
  name     = "rg-postgresql-complete"
  location = "West Europe"
}

resource "azurerm_virtual_network" "example" {
  name                = "vnet-postgresql-complete"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "example" {
  name                 = "snet-postgresql-complete"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "postgresql-delegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

resource "azurerm_user_assigned_identity" "postgresql" {
  name                = "mi-postgresql-complete"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "mi-app-complete"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_user_assigned_identity" "app_staging" {
  name                = "mi-app-staging-complete"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_key_vault" "example" {
  name                       = "kv-psql-complete"
  location                   = azurerm_resource_group.example.location
  resource_group_name        = azurerm_resource_group.example.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
}

resource "azurerm_key_vault_key" "example" {
  name         = "key-postgresql-complete"
  key_vault_id = azurerm_key_vault.example.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
}

data "azurerm_client_config" "current" {}

# The module takes group objects, so the caller does the directory lookup.
data "azuread_group" "example" {
  for_each = toset([
    "PostgreSQL-Admins",
    "Database-Admins",
    "Support-Team",
    "Data-Analysts",
    "Data-Engineers",
    "Developers",
    "BI-Team",
  ])

  display_name     = each.value
  security_enabled = true
}

module "postgresql" {
  source = "../../"

  name                = "psql-example-complete"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  # Server configuration
  sku                   = "GP_Standard_D4s_v3"
  storage_size          = 128
  server_version        = "15"
  backup_retention_days = 14
  delegated_subnet_id   = azurerm_subnet.example.id

  # High availability configuration
  high_available                 = true
  high_availability_mode         = "ZoneRedundant"
  high_availability_standby_zone = "2"

  # Maintenance window configuration (Saturday 02:30 UTC)
  maintenance_window = {
    day_of_week  = 6
    start_hour   = 2
    start_minute = 30
  }

  # Authentication configuration
  password_auth_enabled         = true
  active_directory_auth_enabled = true

  # For an Entra ID only server without a local administrator, leave password_auth_enabled at its
  # default (false) and connect the provider with Entra ID as shown above. Local users
  # (local_readers, local_writers, local_admins) log on with a password and need it set to true.

  # Network configuration
  public_network_access_enabled = false

  # Customer-managed key
  customer_managed_key = {
    key_vault_key_id                  = azurerm_key_vault_key.example.id
    primary_user_assigned_identity_id = azurerm_user_assigned_identity.postgresql.id
  }

  # Active Directory administrator groups
  active_directory_administrator_groups = [
    {
      object_id    = data.azuread_group.example["PostgreSQL-Admins"].object_id
      display_name = data.azuread_group.example["PostgreSQL-Admins"].display_name
    }
  ]

  # Databases with role-based access control.
  #
  # PostgreSQL role names are server-wide, not per database. Every `role_prefix` below is unique
  # (the role is named `<role_prefix>-db-<readers|writers|admins>`), and every principal is used
  # once across all databases. Reusing a prefix in a second database would try to create the same
  # role twice. To give a principal access to another database, give it its own `role_prefix`.
  databases = {
    "app_production" = {
      charset   = "UTF8"
      collation = "en_US.utf8"

      # Local account for applications that cannot use an Entra ID token (requires password_auth_enabled).
      local_admins = [
        {
          username = "app_production_owner"
        }
      ]

      admins = [
        {
          object_id    = data.azuread_group.example["Database-Admins"].object_id
          display_name = data.azuread_group.example["Database-Admins"].display_name
          role_prefix  = "prod-dba"
        }
      ]

      writers = [
        {
          name         = azurerm_user_assigned_identity.app.name
          principal_id = azurerm_user_assigned_identity.app.principal_id
          client_id    = azurerm_user_assigned_identity.app.client_id
          role_prefix  = "prod-app"
        }
      ]

      readers = [
        {
          object_id    = data.azuread_group.example["Support-Team"].object_id
          display_name = data.azuread_group.example["Support-Team"].display_name
          role_prefix  = "prod-support"
        }
      ]
    }

    "app_staging" = {
      charset   = "UTF8"
      collation = "en_US.utf8"

      # Federated owner: the app connects with its managed identity (Entra ID token) and
      # owns/migrates its own schema. The identity is created by the caller, not this module.
      admins = [
        {
          name         = azurerm_user_assigned_identity.app_staging.name
          principal_id = azurerm_user_assigned_identity.app_staging.principal_id
          client_id    = azurerm_user_assigned_identity.app_staging.client_id
          role_prefix  = "stg-app"
        }
      ]

      writers = [
        {
          object_id    = data.azuread_group.example["Developers"].object_id
          display_name = data.azuread_group.example["Developers"].display_name
          role_prefix  = "stg-dev"
        }
      ]
    }

    "analytics" = {
      charset   = "UTF8"
      collation = "en_US.utf8"

      readers = [
        {
          object_id    = data.azuread_group.example["Data-Analysts"].object_id
          display_name = data.azuread_group.example["Data-Analysts"].display_name
          role_prefix  = "analyst"
        },
        {
          object_id    = data.azuread_group.example["BI-Team"].object_id
          display_name = data.azuread_group.example["BI-Team"].display_name
          role_prefix  = "bi"
        }
      ]

      admins = [
        {
          object_id    = data.azuread_group.example["Data-Engineers"].object_id
          display_name = data.azuread_group.example["Data-Engineers"].display_name
          role_prefix  = "engineer"
        }
      ]
    }
  }
}
