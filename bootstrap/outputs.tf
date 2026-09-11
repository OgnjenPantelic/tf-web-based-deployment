# These values are NOT secrets. Set them as GitHub Actions *variables* (repo or
# environment level), which the deploy workflow reads. See bootstrap/README.md.

output "ARM_CLIENT_ID" {
  description = "Set as GitHub variable ARM_CLIENT_ID."
  value       = azuread_application.ci.client_id
}

output "ARM_TENANT_ID" {
  description = "Set as GitHub variable ARM_TENANT_ID."
  value       = data.azuread_client_config.current.tenant_id
}

output "ARM_SUBSCRIPTION_ID" {
  description = "Set as GitHub variable ARM_SUBSCRIPTION_ID."
  value       = var.subscription_id
}

output "TFSTATE_RG" {
  description = "Set as GitHub variable TFSTATE_RG."
  value       = azurerm_resource_group.state.name
}

output "TFSTATE_SA" {
  description = "Set as GitHub variable TFSTATE_SA."
  value       = azurerm_storage_account.state.name
}

output "TFSTATE_CONTAINER" {
  description = "Set as GitHub variable TFSTATE_CONTAINER."
  value       = azurerm_storage_container.state.name
}

output "service_principal_object_id" {
  description = "Object ID of the CI service principal — grant it Databricks account admin (manual step)."
  value       = azuread_service_principal.ci.object_id
}
