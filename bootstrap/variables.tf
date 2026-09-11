variable "subscription_id" {
  description = "Azure subscription ID that will host the workspaces and the state storage."
  type        = string
}

variable "github_owner" {
  description = "GitHub org/user that owns the deployment repo (e.g. OgnjenPantelic)."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. tf-web-based-deployment)."
  type        = string
}

variable "github_environment" {
  description = "GitHub Environment the deploy workflow runs in. The OIDC federated credential is bound to this."
  type        = string
  default     = "azure-prod"
}

variable "location" {
  description = "Azure region for the state storage account."
  type        = string
  default     = "westeurope"
}

variable "state_resource_group_name" {
  description = "Resource group to hold the Terraform state storage account."
  type        = string
  default     = "tfstate-rg"
}

variable "state_storage_account_name" {
  description = "Globally-unique storage account name for Terraform state (3-24 chars, lowercase alphanumeric)."
  type        = string
}

variable "state_container_name" {
  description = "Blob container name for Terraform state."
  type        = string
  default     = "tfstate"
}

variable "identity_name" {
  description = "Name of the Azure AD application / service principal used by GitHub Actions."
  type        = string
  default     = "tf-web-based-deployment-ci"
}
