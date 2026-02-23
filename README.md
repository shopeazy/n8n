# n8n Client Deployment Repository

This repository automates standing up a production-ready, self-hosted n8n instance on Google Cloud Run for any client.

## Infrastructure
- **Network Stateless App:** Google Cloud Run (Gen 2 execution environment)
- **Database Persistence:** Google Cloud SQL (PostgreSQL)
- **Binary Data Persistence:** Google Cloud Storage bucket (mounted via Cloud Run Volume mounts to `/home/node/.n8n`)
- **Secrets Management:** Cloud Secret Manager for the critical `N8N_ENCRYPTION_KEY`

## Deployment Steps

1. Copy `.env.example` to `.env` and configure parameters.
2. Ensure you are logged into gcloud (`gcloud auth login`).
3. Run `chmod +x scripts/*.sh`
4. Run `./scripts/setup.sh` (Provisions the database and bucket)
5. Run `./scripts/deploy.sh` (Builds Docker image and ships to Cloud Run)

### Upgrading n8n
To upgrade n8n in the future to a new version:
1. Edit the `N8N_VERSION` setting in `.env`.
2. Run `./scripts/deploy.sh`. 

This will output a new container image and execute a zero-downtime deployment.
