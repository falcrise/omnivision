#!/bin/bash
# setup-github-secrets.sh

echo "🚀 Setting up GitHub Secrets for Vertex AI Deployment"
echo "=================================================="

# Get project ID
read -p "Enter your GCP Project ID (e.g., falcon-deeptech-ai-stuff): " PROJECT_ID

echo "📋 Creating service account..."
gcloud iam service-accounts create vertex-ai-deployer \
    --project=$PROJECT_ID \
    --display-name="Vertex AI Model Deployer" \
    --description="Service account for GitHub Actions to deploy Vertex AI models"

echo "🔐 Adding required permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:vertex-ai-deployer@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/aiplatform.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:vertex-ai-deployer@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:vertex-ai-deployer@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"

echo "🔑 Creating service account key..."
gcloud iam service-accounts keys create vertex-ai-deployer-key.json \
    --iam-account=vertex-ai-deployer@$PROJECT_ID.iam.gserviceaccount.com

echo ""
echo "✅ Setup Complete!"
echo "==================="
echo ""
echo "📋 Next Steps:"
echo "1. Go to your GitHub repository"
echo "2. Navigate to Settings → Secrets and variables → Actions"
echo "3. Add these repository secrets:"
echo ""
echo "🔒 Secret Name: GCP_SA_KEY"
echo "   Secret Value: [Copy the entire content of vertex-ai-deployer-key.json]"
echo ""
echo "🔒 Secret Name: GCP_PROJECT_ID"
echo "   Secret Value: $PROJECT_ID"
echo ""
echo "📄 The service account key file has been saved as: vertex-ai-deployer-key.json"
echo "🗑️  Remember to delete this file after adding it to GitHub Secrets!"
echo ""
echo "🚀 After adding the secrets, you can run the GitHub Actions workflow!"