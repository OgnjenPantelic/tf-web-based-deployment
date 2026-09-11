data "azurerm_subscription" "current" {}
data "azuread_client_config" "current" {}

# ---------------------------------------------------------------------------
# Remote state backend: storage account + container
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "state" {
  name     = var.state_resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "state" {
  name                     = var.state_storage_account_name
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "state" {
  name                  = var.state_container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# GitHub OIDC identity: Azure AD app + service principal + federated credential
# ---------------------------------------------------------------------------
resource "azuread_application" "ci" {
  display_name = var.identity_name
}

resource "azuread_service_principal" "ci" {
  client_id = azuread_application.ci.client_id
}

# Trust tokens minted by GitHub Actions for this repo's deploy environment.
# Subject must match GitHub's OIDC claim exactly.
resource "azuread_application_federated_identity_credential" "env" {
  application_id = azuread_application.ci.id
  display_name   = "github-${var.github_environment}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_owner}/${var.github_repo}:environment:${var.github_environment}"
}

# ---------------------------------------------------------------------------
# Role assignments for the CI identity
# ---------------------------------------------------------------------------
# Contributor on the subscription so it can create workspaces / resource groups.
# Tighten to specific resource groups for least privilege in production.
resource "azurerm_role_assignment" "ci_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.ci.object_id
}

# Read/write Terraform state blobs.
resource "azurerm_role_assignment" "ci_state_blob" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.ci.object_id
}
