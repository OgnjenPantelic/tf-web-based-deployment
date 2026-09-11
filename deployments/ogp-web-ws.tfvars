# Workspace-only first deployment (no Unity Catalog metastore attach yet).
# Deployment name "ogp-web-ws" => state key ogp-web-ws.tfstate.

workspace_name      = "ogp-web-ws"
resource_group_name = "ogp-web-ws-rg"
location            = "westeurope"

tenant_id             = "bf465dc7-3bc8-4944-b018-092572b5c20d"
databricks_account_id = "" # not needed for a workspace-only deploy

existing_metastore_id = ""

tags = {
  owner = "ognjen.pantelic@databricks.com"
}
