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

IMAGE_PATH="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/n8n-custom:${N8N_VERSION}"
SA_EMAIL="${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "1. Building the Docker Image using Cloud Build..."
# Passing N8N_VERSION as a build argument
gcloud builds submit \
  --tag "$IMAGE_PATH" \
  --timeout=15m \
  --machine-type=e2-highcpu-8 \
  --build-arg="N8N_VERSION=${N8N_VERSION}" \
  .

echo "2. Deploying to Cloud Run..."
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
  --min-instances 0 \
  --max-instances 2 \
  --add-cloudsql-instances "${PROJECT_ID}:${REGION}:${DB_INSTANCE_NAME}" \
  --add-volume=name=n8n-data,type=cloud-storage,bucket=$BUCKET_NAME \
  --add-volume-mount=volume=n8n-data,mount-path=/home/node/.n8n \
  --set-env-vars="DB_TYPE=postgresdb" \
  --set-env-vars="DB_POSTGRESDB_DATABASE=${DB_NAME}" \
  --set-env-vars="DB_POSTGRESDB_USER=${DB_USER}" \
  --set-env-vars="DB_POSTGRESDB_PASSWORD=${DB_PASS}" \
  --set-env-vars="DB_POSTGRESDB_HOST=/cloudsql/${PROJECT_ID}:${REGION}:${DB_INSTANCE_NAME}" \
  --set-env-vars="N8N_HOST=${DOMAIN}" \
  --set-env-vars="WEBHOOK_URL=https://${DOMAIN}" \
  --set-env-vars="N8N_PROTOCOL=https" \
  --set-env-vars="N8N_EMAIL=eamon@shopeazy.co" \
  --set-secrets="N8N_ENCRYPTION_KEY=n8n-encryption-key:latest"

echo "3. Mapping custom domain ($DOMAIN)..."
# Assuming the user has verified the domain in Cloud Console
if ! gcloud run domain-mappings describe --domain="$DOMAIN" --region="$REGION" &>/dev/null; then
  echo "Mapping domain. Check the Cloud Console to grab the DNS records you need to update."
  gcloud run domain-mappings create \
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
