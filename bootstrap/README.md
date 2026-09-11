# Bootstrap (run once)

Creates the pieces the CI pipeline needs before it can run:

- Terraform **remote state** storage account + container
- A GitHub-**OIDC** Azure AD application / service principal (no stored secret)
- A **federated credential** trusting this repo's `azure-prod` environment
- Role assignments: **Contributor** on the subscription + **Storage Blob Data Contributor** on the state account

## Prerequisites

- Azure CLI logged in as someone who can create app registrations and assign roles
  (Owner or User Access Administrator on the subscription): `az login`
- Terraform installed locally

## Run

```bash
cd bootstrap
terraform init
terraform apply \
  -var 'subscription_id=<SUB_ID>' \
  -var 'github_owner=OgnjenPantelic' \
  -var 'github_repo=tf-web-based-deployment' \
  -var 'state_storage_account_name=<globally-unique-name>'
```

## After apply

1. Copy the outputs into **GitHub → repo → Settings → Secrets and variables → Actions → Variables**
   (these are *variables*, not secrets — client/tenant/subscription IDs are not sensitive under OIDC):

   `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`,
   `TFSTATE_RG`, `TFSTATE_SA`, `TFSTATE_CONTAINER`

2. Create the GitHub **Environments** `azure-prod` and `azure-prod-destroy`
   (repo → Settings → Environments) and add **required reviewers** so applies/destroys
   pause for human approval.

3. **Manual step — Databricks account admin.** Add the service principal
   (object id in the `service_principal_object_id` output) to your Databricks account
   and grant it **account admin**, so it can attach metastores / manage workspaces.
   Account console → User management → Service principals.

> Keep `bootstrap/terraform.tfstate` out of the deploy pipeline. It references the
> identity, not secrets, but treat it as sensitive infrastructure state.
