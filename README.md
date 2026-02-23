# 🚀 Serverless n8n for Google Cloud Run

This repository provides a highly-replicable, robust, and automated (near "1-click") pipeline for deploying a self-hosted, scalable instance of **[n8n](https://n8n.io/)** natively onto Google Cloud Run. 

It is specifically designed for multi-tenant and enterprise setups, utilizing durable Google Cloud architectures (Cloud SQL, Cloud Storage, Secret Manager) to ensure high availability and data safety. It circumvents all the standard pitfalls of running stateful workflow automation on serverless infrastructure.

---

## 🌟 Architecture Overview

*   **Compute:** Google Cloud Run (`docker.io/n8nio/n8n:latest`)
*   **Database:** Cloud SQL (PostgreSQL 15) for high-availability workflow/credential storage.
*   **Storage:** Cloud Storage bucket via Cloud Storage FUSE for persisting binary files between executions.
*   **Secrets:** Google Cloud Secret Manager for the `N8N_ENCRYPTION_KEY` to ensure your workflows aren't permanently locked upon container restarts.
*   **Security:** A dedicated Service Account (`n8n-runner`) ensuring Principle of Least Privilege.

---

## 🛠️ Prerequisites

Before installing this for a new client, you must have the following configured locally on your machine and in their GCP account:

1.  **Google Cloud CLI (`gcloud`)**: Must be [installed and authenticated](https://cloud.google.com/sdk/docs/install).
2.  **Billing Enabled**: The target Google Cloud Project must have an active billing account.
3.  **Domain Name**: A domain (e.g., `n8n.clientdomain.com`).

Make sure your `gcloud` CLI is pointing to your own Google account that has `Owner` access to the target project.
```bash
gcloud auth login
```

---

## 🚀 1-Click Deployment Guide

Follow these sequential steps to rapidly spin up a production-ready instance for a client.

### Step 1: Clone & Configure

Clone this repository and configure your client's specific environment variables.

```bash
# 1. Clone the repo for the client
git clone https://github.com/shopeazy/n8n.git client-n8n
cd client-n8n

# 2. Copy the template variables
cp .env.example .env
```

Open `.env` in any text editor and populate it with the client's naming scheme:

```properties
# Make sure this is globally unique!
BUCKET_NAME=client-n8n-data-bucket-unique-id
PROJECT_ID=client-gcp-project-id
REGION=europe-west1
DOMAIN=n8n.clientdomain.com
DB_PASS=generate_a_very_secure_password_here
# ... adjust other parameters as necessary
```

### Step 2: Provision Infrastructure (`setup.sh`)

Ensure the scripts are executable, then run the setup script. This is an idempotent script that will configure all the underlying infrastructure in Google Cloud.

```bash
chmod +x scripts/*.sh

# This will take 3-5 minutes to create the database and configure IAM
./scripts/setup.sh
```

### Step 3: Deploy n8n Container (`deploy.sh`)

Once the infrastructure is ready, execute the deployment script. This pulls the official n8n Docker image, maps the environment variables to Cloud Run, and binds it to the database and storage systems.

```bash
./scripts/deploy.sh
```

### Step 4: Map the Domain DNS

The `deploy.sh` script automatically provisions a custom Domain Mapping in Cloud Run. 

As the final step, you must log into your client's DNS provider (e.g., Cloudflare, GoDaddy, Google Domains) and create the DNS records requested by Google Cloud.

1. Go to the [Google Cloud Console -> Cloud Run -> Custom Domains](https://console.cloud.google.com/run/domains).
2. Find the requested mapping for your domain (e.g., `n8n.clientdomain.com`).
3. Under the **DNS Records** column, click **View DNS records**.
4. Add the requested `CNAME` or `A`/`AAAA` records to the client's DNS registrar.

Once DNS propagates, n8n will automatically provision an SSL certificate and be ready at `https://n8n.clientdomain.com`.

---

## ⚙️ Advanced Customization & Notes

*   **Upgrading Version:** To upgrade `n8n`, simply bump the `N8N_VERSION` parameter in your `.env` file to the desired tag (e.g., `2.9.0`) and run `./scripts/deploy.sh` again. This performs a zero-downtime rolling update.
*   **Proxy Limitations Overcome:** This deployment implements specific environment variables (`N8N_TRUST_PROXY`, `N8N_EDITOR_BASE_URL`, `N8N_PUSH_BACKEND=sse`, `N8N_ENDPOINT_HEALTH`, etc.) to bypass strict origin validation issues, 500 API errors, and the infamous "Offline" UI bug that plagues n8n when put behind Cloud Run's native reverse proxies.

---
_Automated with ❤️ by ShopEazy._
