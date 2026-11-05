# Setup guide (one-time)

First time on Azure? Do `docs/AZURE-GETTING-STARTED.md` first (account, Cloud Shell, region/VM policy).
Read `docs/COST-SAFETY.md` too: no card, never upgrade, teardown when finished.

## 1. Create the GitHub repository
```bash
git init && git add . && git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
```
Make the repo **public** (or add your instructor as a collaborator). **Don't push yet.**

## 2. Provision Azure (in Cloud Shell)
```bash
export GITHUB_REPO=<you>/<repo>      # exact capitalisation
./scripts/azure-setup.sh
```
Creates: resource group, Container Registry, AKS cluster (registry attached), an app registration with
**federated credentials** (keyless login for GitHub Actions) and least-privilege role assignments.

## 3. Connect SonarCloud
1. Sign in at <https://sonarcloud.io> with GitHub, **Import** your repository.
2. Choose **CI-based analysis (GitHub Actions)**. In *Administration -> Analysis Method* turn **Automatic Analysis OFF**.
3. Note the **Organization key** and **Project key**.
4. *My Account -> Security -> Generate Token* -> this is `SONAR_TOKEN`.

(Self-hosted SonarQube instead? Replace `-Dsonar.host.url` in the workflow and drop `sonar.organization`.)

## 4. Add GitHub secrets, variables and the environment
*Repo -> Settings -> Secrets and variables -> Actions* (values printed by `azure-setup.sh`):

| Type | Name |
|---|---|
| Secret | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `SONAR_TOKEN` |
| Variable | `AZURE_RESOURCE_GROUP`, `ACR_NAME`, `AKS_CLUSTER`, `SONAR_ORGANIZATION`, `SONAR_PROJECT_KEY` |

*Settings -> Environments -> New environment* named exactly **`production`**. The deploy job's Azure login
trusts that environment name; a different name makes login fail.

## 5. Recommended protections
- *Settings -> Branches*: protect `main`, require the `secret-scan` and `build-test` checks.
- *Settings -> Code security*: enable Dependabot, secret scanning and push protection.
- Optional: Required reviewers on the `production` environment (manual approval gate).
- Local hook: `pip install pre-commit && pre-commit install` (Gitleaks before each commit).

## 6. First run
```bash
git push -u origin main
```
Watch the **Actions** tab. The first deploy takes a few extra minutes while Azure creates the load balancer IP.

## 7. Clean up
```bash
./scripts/azure-teardown.sh
```
