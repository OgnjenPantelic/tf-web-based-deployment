output "workspace_url" {
  description = "URL of the deployed Databricks workspace."
  value       = "https://${azurerm_databricks_workspace.this.workspace_url}"
}

output "workspace_id" {
  description = "Databricks workspace ID."
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "resource_group" {
  description = "Resource group the workspace lives in."
  value       = azurerm_resource_group.this.name
}
