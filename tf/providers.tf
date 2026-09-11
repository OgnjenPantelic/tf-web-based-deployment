# azurerm authenticates from ARM_* environment variables. In CI the workflow sets
# ARM_USE_OIDC=true plus ARM_CLIENT_ID / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID, so no
# secret is stored anywhere.
provider "azurerm" {
  features {}
}

# Workspace-level Databricks provider. Host comes from the workspace we create.
# auth_type is intentionally NOT pinned so it works both under Azure CLI (local)
# and the OIDC/service-principal flow (CI).
provider "databricks" {
  host = azurerm_databricks_workspace.this.workspace_url
}

# Account-level Databricks provider, used to attach the Unity Catalog metastore.
# The service principal must be a Databricks *account admin*.
provider "databricks" {
  alias           = "accounts"
  host            = "https://accounts.azuredatabricks.net"
  account_id      = var.databricks_account_id
  azure_tenant_id = var.tenant_id
}
