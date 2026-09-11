terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }

  # Partial backend config. The concrete values (storage account, container, and a
  # per-deployment state key) are supplied at `terraform init` time by the GitHub
  # Actions workflow via -backend-config. Kept empty here so the module stays
  # backend-agnostic and can also be run with local state for quick experiments.
  backend "azurerm" {}
}
