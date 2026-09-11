# Workspace-only first deployment (no Unity Catalog metastore attach yet).
# Deployment name "ogp-web-ws" => state key ogp-web-ws.tfstate.

workspace_name      = "ogp-web-ws"
resource_group_name = "ogp-web-ws-rg"
location            = "westeurope"

# tenant_id / databricks_account_id are only needed when attaching a Unity Catalog
# metastore; left blank for this workspace-only deploy.
tenant_id             = ""
databricks_account_id = ""

existing_metastore_id = ""

tags = {
  owner = "OgnjenPantelic"
}
