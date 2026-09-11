# Example deployment. Run with:
#   deployment_name = "example"
# (via the GitHub Actions "Deploy Databricks Workspace" workflow)
#
# The workflow uses this file name as the Terraform state key, so each file in
# deployments/ maps to one isolated workspace deployment.

workspace_name      = "example-databricks-ws"
resource_group_name = "example-databricks-rg"
location            = "westeurope"

tenant_id             = "00000000-0000-0000-0000-000000000000"
databricks_account_id = "00000000-0000-0000-0000-000000000000"

existing_metastore_id = ""

tags = {
  Owner       = "me@example.com"
  Environment = "demo"
}
