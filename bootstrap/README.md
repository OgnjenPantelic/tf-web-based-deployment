# Bootstrap (one-time, web-based)

Everything in this project runs in GitHub Actions — including this one-time setup.
Bootstrap creates the pieces the deploy/destroy workflows depend on:

- Terraform **remote state** storage account + container
- A GitHub-**OIDC** Azure AD application / service principal (no long-lived secret)
- A **federated credential** per GitHub environment (`azure-prod`, `azure-prod-destroy`)
- Role assignments: **Contributor** on the subscription + **Storage Blob Data Contributor** on the state account

## Why a temporary secret

Bootstrap is the one step that *cannot* use OIDC, because it is what creates the OIDC
identity. To break that chicken-and-egg, the bootstrap workflow authenticates once
with a **temporary, privileged service principal secret**, which you delete afterward.
Every other workflow uses OIDC with no stored secret.

## Steps

### 1. Create the temporary service principal (web)

In the [Azure Portal](https://portal.azure.com) (or one `az` command from any machine):

- App registration → new registration → note the **Application (client) ID** and **Directory (tenant) ID**.
- Certificates & secrets → new client secret → copy the **value**.
- Grant it **Owner** on the target subscription (Access control (IAM) → Add role assignment).
- Grant it the **Application Administrator** directory role (Microsoft Entra ID → Roles and administrators),
  so it can create the app registration and federated credentials.

> This principal is powerful and short-lived — delete its secret (and optionally the SP)
> after bootstrap succeeds.

### 2. Store the credential as a GitHub secret

Repo → Settings → Secrets and variables → Actions → **Secrets** → new secret
`AZURE_BOOTSTRAP_CREDENTIALS` with this JSON:

```json
{
  "clientId": "<app client id>",
  "clientSecret": "<secret value>",
  "subscriptionId": "<subscription id>",
  "tenantId": "<tenant id>"
}
```

### 3. Run the bootstrap workflow

Actions → **Bootstrap (one-time)** → Run workflow → provide a globally-unique
`state_storage_account` name (3-24 lowercase alphanumeric). The run's summary prints
the six values you need next.

### 4. Set the deploy variables

Repo → Settings → Secrets and variables → Actions → **Variables** (not secrets — these
IDs are not sensitive under OIDC):

`ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`,
`TFSTATE_RG`, `TFSTATE_SA`, `TFSTATE_CONTAINER`

### 5. Create protected environments

Repo → Settings → Environments → create `azure-prod` and `azure-prod-destroy`, each with
**required reviewers**, so applies/destroys pause for human approval.

### 6. Clean up

Delete the `AZURE_BOOTSTRAP_CREDENTIALS` secret (and the temporary SP's client secret).

## Notes

- The script is idempotent — safe to re-run if a step failed.
- **Databricks account admin** is only needed once you start attaching Unity Catalog
  metastores. The SP object id is printed at the end of the bootstrap run for that grant.
