#!/usr/bin/env bash
# scripts/deploy.sh

set -e

# Load environment variables
if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo "Error: .env file not found. Please copy .env.example to .env and configure it."
  exit 1
fi

echo "================================================="
echo " Deploying n8n to Cloud Run"
echo " Project: $PROJECT_ID"
echo " Region:  $REGION"
echo " Domain:  $DOMAIN"
echo " Version: $N8N_VERSION"
echo "================================================="

gcloud config set project "$PROJECT_ID"

IMAGE_PATH="docker.io/n8nio/n8n:${N8N_VERSION}"
SA_EMAIL="${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "1. Deploying the official n8n image directly to Cloud Run..."
# Using Cloud SQL unix socket for Postgres
# Mounting Cloud Storage for persistent /home/node/.n8n data (binary files)
# n8n standard port is 5678, so we set the container-port

gcloud run deploy n8n \
  --image "$IMAGE_PATH" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --service-account "$SA_EMAIL" \
  --port 5678 \
  --allow-unauthenticated \
  --execution-environment gen2 \
  --memory 2Gi \
  --cpu 1 \
  --no-cpu-throttling \
  --min-instances 1 \
  --max-instances 2 \
  --add-cloudsql-instances "${PROJECT_ID}:${REGION}:${DB_INSTANCE_NAME}" \
  --add-volume=name=n8n-data,type=cloud-storage,bucket=$BUCKET_NAME \
  --add-volume-mount=volume=n8n-data,mount-path=/home/node/.n8n \
  --set-env-vars="DB_TYPE=postgresdb,DB_POSTGRESDB_DATABASE=${DB_NAME},DB_POSTGRESDB_USER=${DB_USER},DB_POSTGRESDB_PASSWORD=${DB_PASS},DB_POSTGRESDB_HOST=/cloudsql/${PROJECT_ID}:${REGION}:${DB_INSTANCE_NAME},N8N_HOST=${DOMAIN},WEBHOOK_URL=https://${DOMAIN},N8N_PROTOCOL=https,N8N_EMAIL=eamon@shopeazy.co,N8N_PORT=5678,N8N_LISTEN_ADDRESS=0.0.0.0,N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false,N8N_PUSH_BACKEND=sse,N8N_EDITOR_BASE_URL=https://${DOMAIN},N8N_TRUST_PROXY=true" \
  --set-secrets="N8N_ENCRYPTION_KEY=n8n-encryption-key:latest"

echo "3. Mapping custom domain ($DOMAIN)..."
# Assuming the user has verified the domain in Cloud Console
if ! gcloud beta run domain-mappings describe --domain="$DOMAIN" --region="$REGION" &>/dev/null; then
  echo "Mapping domain. Check the Cloud Console to grab the DNS records you need to update."
  gcloud beta run domain-mappings create \
    --service=n8n \
    --domain="$DOMAIN" \
    --region="$REGION" || true
else
  echo "Domain $DOMAIN is already mapped."
fi

echo "================================================="
echo " Deployment Complete!"
echo " Navigate to: https://${DOMAIN}"
echo "================================================="
