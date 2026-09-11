# tf-web-based-deployment

Deploy Databricks workspaces on Azure by running Terraform **in GitHub Actions** —
no local machine required. A deployment is triggered by a single API call, so a
human, the GitHub UI, or an agent (e.g. Genie in the account console) can all drive
it the same way.

## How it works

```
                deployments/<name>.tfvars   ──┐
  trigger  ─────────────────────────────────► │  GitHub Actions (deploy.yml)
 (UI / gh / REST API / agent)                  │    OIDC → Azure   (no secrets)
                                               │    terraform init/plan/apply
                                               │    remote state in Azure Storage
                                               └──────────────► Databricks workspace
```

- **`tf/`** — the Terraform module that gets deployed (a Premium Azure Databricks
  workspace, optional Unity Catalog metastore attach). Backend is left partial and
  filled in at `init` time, so the same module works locally and in CI.
- **`deployments/`** — one `*.tfvars` per workspace. The file name is the deployment
  name and the Terraform **state key**, so deployments are isolated from each other.
- **`.github/workflows/`** — `deploy.yml` (plan/apply) and `destroy.yml`, both
  `workflow_dispatch` with inputs.
- **`bootstrap/`** — one-time setup, run as its own GitHub Actions workflow
  (`bootstrap.yml`): remote state storage + the GitHub-OIDC identity.
  See [bootstrap/README.md](bootstrap/README.md).

## Setup (once, web-based)

Bootstrap runs in Actions too — it's the only workflow that uses a temporary secret,
because it's what creates the OIDC identity. Full steps in [bootstrap/README.md](bootstrap/README.md):

1. Create a temporary privileged service principal, store it as the GitHub secret
   `AZURE_BOOTSTRAP_CREDENTIALS`.
2. Run the **Bootstrap (one-time)** workflow (provide a unique state storage account name).
3. Set the six GitHub Actions **variables** it prints (`ARM_CLIENT_ID`, `ARM_TENANT_ID`,
   `ARM_SUBSCRIPTION_ID`, `TFSTATE_RG`, `TFSTATE_SA`, `TFSTATE_CONTAINER`).
4. Create protected Environments `azure-prod` / `azure-prod-destroy` with required reviewers.
5. Delete the temporary bootstrap secret. (Databricks account admin is only needed once
   you attach Unity Catalog metastores.)

## Deploy a workspace

1. Add `deployments/<name>.tfvars` (copy `tf/terraform.tfvars.example`).
2. Run the **Deploy Databricks Workspace** workflow with `deployment_name=<name>`,
   `action=plan` (preview) then `action=apply`.

### Trigger from the CLI

```bash
gh workflow run deploy.yml -f deployment_name=example -f action=apply
```

### Trigger from the REST API (what an agent / Genie calls)

Two calls: (1) write the tfvars via the contents API, (2) dispatch the workflow.

```bash
# 2) dispatch
curl -X POST \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/OgnjenPantelic/tf-web-based-deployment/actions/workflows/deploy.yml/dispatches \
  -d '{"ref":"main","inputs":{"deployment_name":"example","action":"apply"}}'
```

## Notes & guardrails

- **OIDC, no secrets.** Auth is a short-lived federated token bound to this repo's
  `azure-prod` environment. A fork/PR cannot assume the identity, and `apply` never
  runs on `pull_request`.
- **Approvals.** Applies and destroys run in protected environments — keep required
  reviewers on until you trust an unattended (agent-driven) flow.
- **One metastore per region per account.** Multiple workspaces in the same region
  should *attach* an existing metastore (`existing_metastore_id`), not create new ones.
- The `tf/` module is intentionally minimal. Extend it (VNet injection, NAT gateway,
  hardened UC storage, Private Link) without touching the workflow or state wiring.
