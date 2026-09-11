variable "workspace_name" {
  description = "Name of the Azure Databricks workspace to create."
  type        = string
  validation {
    condition     = length(var.workspace_name) > 0
    error_message = "workspace_name cannot be empty."
  }
}

variable "resource_group_name" {
  description = "Resource group to create for the workspace."
  type        = string
}

variable "location" {
  description = "Azure region (e.g. westeurope, eastus)."
  type        = string
  default     = "westeurope"
}

variable "tenant_id" {
  description = "Azure AD tenant ID (used by the account-level Databricks provider)."
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID (accounts.azuredatabricks.net)."
  type        = string
}

variable "existing_metastore_id" {
  description = "Attach this existing Unity Catalog metastore. Leave empty to skip metastore assignment. Azure allows one metastore per region per account."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}
