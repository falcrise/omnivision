# GitHub Actions Deployment Guide

This guide explains how to set up automated deployment of Vertex AI models using GitHub Actions.

## 🏗️ Project Structure

```
├── .github/
│   ├── workflows/
│   │   └── deploy-model.yml          # Main deployment pipeline
│   └── configs/
│       ├── staging.yml               # Staging environment config
│       └── production.yml            # Production environment config
├── deployGCPModels.py                # Updated deployment script
├── requirements.txt                  # Python dependencies
└── README.md                        # This guide
```

## 🔐 Required GitHub Secrets

Set up these secrets in your GitHub repository (`Settings → Secrets and variables → Actions`):

### Required Secrets:
- **`GCP_SA_KEY`**: Service Account JSON key with the following permissions:
  - Vertex AI Admin
  - Storage Admin
  - Service Account User
- **`GCP_PROJECT_ID`**: Your Google Cloud Project ID

### Creating the Service Account:

```bash
# Create service account
gcloud iam service-accounts create vertex-ai-deployer \
    --display-name="Vertex AI Model Deployer"

# Add required roles
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:vertex-ai-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/aiplatform.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:vertex-ai-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:vertex-ai-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"

# Create and download key
gcloud iam service-accounts keys create vertex-ai-deployer-key.json \
    --iam-account=vertex-ai-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

Copy the contents of `vertex-ai-deployer-key.json` to the `GCP_SA_KEY` secret.

## ⚙️ Configuration Files

### Staging Configuration (`.github/configs/staging.yml`)
- Uses smaller machine types for cost efficiency
- Lower replica counts
- Debug logging enabled

### Production Configuration (`.github/configs/production.yml`)
- Uses larger machine types for performance
- Higher replica counts for availability
- Info-level logging

Update the `project_id` values in both files to match your projects.

## 🚀 Deployment Options

### 1. Manual Deployment (Recommended)

Use the GitHub Actions UI to trigger deployments with full control over parameters.

**📖 [Complete Manual Execution Guide](MANUAL_EXECUTION_GUIDE.md)** ← **Detailed step-by-step instructions**

**Quick Steps:**
1. Go to `Actions` tab in your repository
2. Select `Deploy Vertex AI Model` workflow
3. Click `Run workflow`
4. Choose your parameters:
   - **Model**: smolvlm-instruct (recommended) or custom
   - **Machine Type**: g2-standard-4/8/12/16 (g2-standard-12 recommended)
   - **Replicas**: Min and max replica counts (1-3 for testing, 2-5 for production)
   - **Environment**: staging (testing) or production
   - **Force Redeploy**: true to replace existing endpoint
5. Click `Run workflow` to start deployment

### 2. Automatic Deployment

Deployments trigger automatically when:
- Changes are pushed to `main` branch
- Files `deployGCPModels.py` or `.github/workflows/deploy-model.yml` are modified
- Uses staging environment with default settings (g2-standard-12, 1-3 replicas)

## 📊 Deployment Outputs

After successful deployment, the pipeline provides:

1. **GitHub Actions Summary**: Deployment details in the Actions UI
2. **Artifacts**: 
   - `deployment_outputs.json`: Complete deployment information
   - `deployment-info.txt`: Human-readable summary
3. **Environment Variables**: Available for subsequent workflow steps

### Using Deployment Outputs

The deployment outputs include all information needed to update your application:

```json
{
  "api_config": {
    "endpoint_id": "1234567890",
    "project_id": "your-project-id",
    "region": "asia-southeast1",
    "api_endpoint": "https://1234567890.asia-southeast1-your-project-id.prediction.vertexai.goog/v1/projects/your-project-id/locations/asia-southeast1/endpoints/1234567890:predict"
  }
}
```

## 🔧 Customization

### Adding New Models

1. Update the model choices in `.github/workflows/deploy-model.yml`:
```yaml
options:
  - smolvlm-instruct
  - your-new-model
```

2. Add model configuration in the config files:
```yaml
model:
  name: "your-new-model"
  huggingface_id: "organization/model-name"
```

### Environment Variables Override

The deployment script accepts these environment variables:

- `PROJECT_ID`: GCP Project ID
- `REGION`: GCP Region
- `MODEL_NAME`: Model identifier
- `MODEL_ID`: Hugging Face model ID
- `MACHINE_TYPE`: Compute machine type
- `MIN_REPLICAS`: Minimum replicas
- `MAX_REPLICAS`: Maximum replicas
- `ENVIRONMENT`: Deployment environment

## 🔍 Monitoring and Troubleshooting

### Common Issues:

1. **Permission Denied**: Check service account roles
2. **Quota Exceeded**: Verify GPU quotas in your region
3. **Model Upload Failed**: Check model ID and container compatibility
4. **Deployment Timeout**: Consider using smaller machine types for testing

### Diagnostic Tools

Run the authentication diagnosis:

```powershell
.\diagnose_auth.ps1
```

Test the endpoint directly:

```powershell
.\test_endpoint.ps1
```

## 🛡️ Security Best Practices

1. **Least Privilege**: Only grant necessary permissions to service accounts
2. **Environment Separation**: Use different projects for staging/production
3. **Secret Rotation**: Regularly rotate service account keys
4. **Audit Logs**: Enable Cloud Audit Logs for deployment tracking

## 💰 Cost Management

1. **Resource Sizing**: Start with smaller machine types
2. **Auto-scaling**: Configure appropriate replica ranges
3. **Monitoring**: Set up billing alerts
4. **Cleanup**: Regularly clean up unused endpoints and models

## 📊 Monitoring

Monitor your deployment:

- **Firebase Console**: Hosting metrics and performance
- **Google Cloud Console**: Vertex AI usage and costs
- **Browser DevTools**: Debug frontend issues

## 🎨 Customization

### Styling

The app uses Tailwind CSS. Modify classes in `index.html` to customize the appearance.

### Model Integration

To use a different model:

1. Deploy your model to Vertex AI
2. Update the endpoint configuration in `config.js`
3. Modify the request format in `app.js` if needed

### Alert Logic

Customize alert conditions in the `analyzeImage()` function in `app.js`.

## 📚 Additional Resources

- [Google Cloud Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [Firebase Hosting Guide](https://firebase.google.com/docs/hosting)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Service Account Best Practices](https://cloud.google.com/iam/docs/best-practices-for-using-and-managing-service-accounts)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🚀 Quick Start Summary

```bash
# 1. Setup Python environment
python -m venv venv && venv\Scripts\activate
pip install -r requirements.txt

# 2. Authenticate with Google Cloud
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login --project=YOUR_PROJECT_ID

# 3. Deploy model via GitHub Actions
# Go to Actions tab → "Deploy Vertex AI Model" → Run workflow

# 4. Update config.js with deployment details

# 5. Deploy web app
.\deploy.ps1

# 6. Get access token and use the app
.\get_token.ps1
```

🎉 **Your real-time video analysis app is now live with automated CI/CD!**
