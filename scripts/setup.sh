#!/usr/bin/env bash
# scripts/setup.sh

set -e

# Load environment variables
if [ -f .env ]; then
  export $(cat .env | xargs)
else
  echo "Error: .env file not found. Please copy .env.example to .env and configure it."
  exit 1
fi

echo "================================================="
echo " Setting up infrastructure for n8n"
echo " Project: $PROJECT_ID"
echo " Region:  $REGION"
echo "================================================="

# Set current project
gcloud config set project "$PROJECT_ID"

echo "1. Enabling required Google Cloud APIs..."
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  storage.googleapis.com \
  storage-component.googleapis.com \
  compute.googleapis.com

echo "2. Creating Artifact Registry repository ($AR_REPO)..."
# Check if repo exists
if ! gcloud artifacts repositories describe "$AR_REPO" --location="$REGION" &>/dev/null; then
  gcloud artifacts repositories create "$AR_REPO" \
    --repository-format=docker \
    --location="$REGION" \
    --description="Docker repository for n8n images"
else
  echo "Repository $AR_REPO already exists."
fi

echo "3. Creating Cloud Storage bucket ($BUCKET_NAME) for n8n data persistence..."
# Check if bucket exists
if ! gcloud storage ls "gs://$BUCKET_NAME" &>/dev/null; then
  gcloud storage buckets create "gs://$BUCKET_NAME" --location="$REGION"
else
  echo "Bucket gs://$BUCKET_NAME already exists."
fi

echo "4. Creating Cloud SQL PostgreSQL Instance ($DB_INSTANCE_NAME)..."
echo "   (This may take 5-10 minutes if creating a new instance)"
if ! gcloud sql instances describe "$DB_INSTANCE_NAME" &>/dev/null; then
  gcloud sql instances create "$DB_INSTANCE_NAME" \
    --database-version=POSTGRES_15 \
    --tier=db-f1-micro \
    --region="$REGION"
else
  echo "Cloud SQL instance $DB_INSTANCE_NAME already exists."
fi

echo "5. Creating n8n Database ($DB_NAME)..."
if ! gcloud sql databases describe "$DB_NAME" --instance="$DB_INSTANCE_NAME" &>/dev/null; then
  gcloud sql databases create "$DB_NAME" --instance="$DB_INSTANCE_NAME"
else
  echo "Database $DB_NAME already exists."
fi

echo "6. Creating Database User ($DB_USER)..."
# In a real environment, you'd auto-generate a strong password. We use DB_PASS from .env here.
gcloud sql users create "$DB_USER" \
  --instance="$DB_INSTANCE_NAME" \
  --password="$DB_PASS"

echo "7. Creating Service Account ($SERVICE_ACCOUNT) for Cloud Run..."
SA_EMAIL="${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"
if ! gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
  gcloud iam service-accounts create "$SERVICE_ACCOUNT" \
    --display-name="n8n Cloud Run Service Account"
else
  echo "Service account $SERVICE_ACCOUNT already exists."
fi

echo "8. Assigning IAM Roles to the Service Account..."
# Role to connect to Cloud SQL
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/cloudsql.client" \
  --condition=None
# Role to access the GCS Bucket
gcloud storage buckets add-iam-policy-binding "gs://$BUCKET_NAME" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/storage.objectAdmin"

echo "9. Generating and storing an n8n encryption key in Secret Manager..."
# n8n generates an encryption key automatically if not provided, but since we are replacing
# the state, keeping the key in Secret Manager ensures credentials are never lost.
SECRET_NAME="n8n-encryption-key"
if ! gcloud secrets describe "$SECRET_NAME" &>/dev/null; then
  # Generate a random 32 character key
  RANDOM_KEY=$(openssl rand -base64 24)
  gcloud secrets create "$SECRET_NAME" --replication-policy="automatic"
  echo -n "$RANDOM_KEY" | gcloud secrets versions add "$SECRET_NAME" --data-file=-
  echo "Secret $SECRET_NAME created."
else
  echo "Secret $SECRET_NAME already exists."
fi

# Role to access Secret Manager
gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/secretmanager.secretAccessor"

echo "================================================="
echo " Infrastructure Setup Complete!"
echo " You can now run: ./scripts/deploy.sh"
echo "================================================="
