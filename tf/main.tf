resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Minimal, real payload: a Premium Azure Databricks workspace. This is deliberately
# lean so the web-based pipeline can be proven end to end. Swap or extend this file
# with VNet injection, NAT gateway, hardened UC storage, etc. as needed — the
# workflow and state wiring do not change.
resource "azurerm_databricks_workspace" "this" {
  name                = var.workspace_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "premium"
  tags                = var.tags
}

# Optionally attach an existing Unity Catalog metastore to the workspace.
resource "databricks_metastore_assignment" "this" {
  count = var.existing_metastore_id != "" ? 1 : 0

  provider     = databricks.accounts
  workspace_id = azurerm_databricks_workspace.this.workspace_id
  metastore_id = var.existing_metastore_id
}
