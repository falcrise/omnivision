# Real-Time Video Analysis with Vertex AI

A modern web application that performs real-time video analysis using Google Cloud Vertex AI and Firebase hosting. This app captures video from your webcam and sends frames to a deployed AI model for analysis and alerts.

## 🚀 Features

- **Real-time video analysis** using your webcam
- **AI-powered alerts** based on custom conditions  
- **SmolVLM-Instruct (2B)** vision-language model integration
- **Automated CI/CD** deployment via GitHub Actions
- **Modern UI** with Tailwind CSS
- **Configurable analysis intervals** (500ms to 5s)
- **Firebase hosting** for production deployment
- **Google Cloud Vertex AI** integration with auto-scaling

## 📋 Prerequisites

### Required Software

1. **Python 3.8+** - [Download from python.org](https://www.python.org/downloads/)
2. **Node.js and npm** - [Download from nodejs.org](https://nodejs.org/)
3. **Google Cloud CLI** - [Installation guide](https://cloud.google.com/sdk/docs/install)
4. **Firebase CLI** - Install globally:
   ```bash
   npm install -g firebase-tools
   ```

### Required Accounts

1. **Google Cloud Account** with billing enabled
2. **Firebase Project** (can be the same as your Google Cloud project)
3. **GitHub Account** for CI/CD automation

## 🛠️ Setup Instructions

### Option A: Automated Setup (Recommended)

#### Step 1: Setup CI/CD Pipeline
Follow the [GitHub Actions Deployment Guide](.github/DEPLOYMENT_GUIDE.md) to:
- Create service account with proper permissions
- Add GitHub secrets for automated deployment
- Configure staging and production environments

#### Step 2: Deploy Model via GitHub Actions
1. Go to Actions tab → "Deploy Vertex AI Model"
2. Click "Run workflow"
3. Select environment and parameters
4. Wait for deployment completion

#### Step 3: Update Configuration
After deployment, update `public/config.js` with the outputs from GitHub Actions.

#### Step 4: Deploy Web App
```bash
.\deploy.ps1
```

### Option B: Manual Setup

#### Step 1: Clone and Setup Python Environment

```bash
# Clone or download this repository
cd path/to/your/project

# Create and activate Python virtual environment
python -m venv venv

# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate

# Install required packages
pip install -r requirements.txt
```

### Step 2: Google Cloud Authentication

```bash
# Login to Google Cloud
gcloud auth login

# Set your project (replace with your project ID)
gcloud config set project YOUR_PROJECT_ID

# Setup application default credentials
gcloud auth application-default login --project=YOUR_PROJECT_ID
```

### Step 3: Deploy Vertex AI Model

```bash
# Run the deployment script
python deployGCPModels.py
```

This will:
- Deploy a Hugging Face model to Vertex AI
- Create a dedicated endpoint
- Output the endpoint details you'll need for configuration

**Important**: Save the output values:
- `ENDPOINT_ID`
- `PROJECT_NUMBER` 
- `REGION`

### Step 4: Configure the Web Application

Edit `public/config.js` with your deployment details:

```javascript
VERTEX_AI: {
    ENDPOINT_ID: "YOUR_ENDPOINT_ID",     // From deployment output
    PROJECT_ID: "YOUR_PROJECT_NUMBER",   // Project NUMBER (not string)
    PROJECT_ID_STRING: "YOUR_PROJECT_ID", // Project ID string
    REGION: "YOUR_REGION"                // e.g., "asia-southeast1"
}
```

### Step 5: Firebase Setup

```bash
# Login to Firebase
firebase login

# Initialize Firebase in your project directory
firebase init hosting
```

When prompted:
- **Use an existing project**: Select your Google Cloud project
- **Public directory**: `public` (default)
- **Configure as SPA**: `Yes`
- **Overwrite files**: `No`

Update `.firebaserc` with your project:

```json
{
  "projects": {
    "default": "your-project-id"
  }
}
```

### Step 6: Deploy to Firebase

#### Option A: Using PowerShell Script (Recommended)

```powershell
.\deploy.ps1
```

This script will:
- Check your configuration
- Verify Firebase project exists
- Deploy automatically
- Handle common issues

#### Option B: Manual Deployment

```bash
firebase deploy
```

## 🔥 Firebase Deployment

### Firebase Setup

1. **Create/Configure Firebase Project**
   ```bash
   # Login to Firebase
   firebase login
   
   # Initialize Firebase in your project directory
   firebase init hosting
   
   # Follow the prompts:
   # - Select existing project or create new one
   # - Choose 'public' as your public directory
   # - Configure as single-page app: Yes
   # - Don't overwrite index.html
   ```

2. **Configure Multiple Environments**
   
   Add projects to `.firebaserc`:
   ```json
   {
     "projects": {
       "staging": "your-staging-project-id",
       "production": "your-production-project-id"
     }
   }
   ```

3. **Manual Deployment**
   ```bash
   # Deploy to staging
   firebase deploy --project staging
   
   # Deploy to production
   firebase deploy --project production
   ```

### 🚀 Quick Firebase Deployment

Use the included PowerShell script for easy local deployment:

```powershell
# Validate configuration only
.\deploy-firebase.ps1 -ValidateOnly

# Deploy to staging
.\deploy-firebase.ps1 -Environment staging

# Deploy to production
.\deploy-firebase.ps1 -Environment production

# Preview locally before deployment
.\deploy-firebase.ps1 -Preview
```

**Script Features:**
- ✅ Validates all requirements and configuration
- 🔐 Checks for security issues (leaked secrets)
- 🌍 Supports multiple environments
- 📋 Provides detailed deployment summary
- 🔍 Includes preview mode for local testing

### 🔐 Secret Management for GitHub Actions

#### Required Secrets for Firebase Deployment

1. **FIREBASE_TOKEN** - For Firebase CLI authentication
   ```bash
   # Generate token locally
   firebase login:ci
   
   # Copy the token and add to GitHub Secrets
   ```

2. **Optional: GOOGLE_CLOUD_SERVICE_ACCOUNT_KEY** - For Google Cloud operations
   ```bash
   # Create service account with Firebase Admin SDK permissions
   gcloud iam service-accounts create firebase-deploy-sa \
     --display-name="Firebase Deploy Service Account"
   
   # Grant necessary permissions
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:firebase-deploy-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/firebase.admin"
   
   # Create and download key
   gcloud iam service-accounts keys create firebase-key.json \
     --iam-account=firebase-deploy-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
   
   # Add the entire JSON content to GitHub Secrets
   ```

#### Setting Up GitHub Secrets

1. **Go to Repository Settings** → Secrets and Variables → Actions

2. **Add Required Secrets:**
   
   | Secret Name | Description | How to Get |
   |-------------|-------------|------------|
   | `FIREBASE_TOKEN` | Firebase CLI token | Run `firebase login:ci` |
   | `GOOGLE_CLOUD_SERVICE_ACCOUNT_KEY` | Service account JSON key | Create service account with Firebase Admin role |

3. **Optional Environment-Specific Secrets:**
   ```
   STAGING_FIREBASE_PROJECT_ID=your-staging-project
   PRODUCTION_FIREBASE_PROJECT_ID=your-production-project
   ```

#### GitHub Actions Workflow Features

The Firebase deployment workflow (`.github/workflows/firebase-deploy.yml`) includes:

- **Automatic Environment Detection**: Deploys to staging for PRs, production for main branch
- **Manual Deployment**: Trigger deployments manually with environment selection
- **Security Scanning**: Checks for accidentally committed secrets
- **Build Validation**: Ensures all required files are present
- **PR Comments**: Automatically comments on PRs with deployment status

#### Triggering Deployments

1. **Automatic Deployment:**
   - Push to `main` → Production deployment
   - Create PR → Staging deployment preview

2. **Manual Deployment:**
   - Go to Actions → "Deploy to Firebase Hosting"
   - Click "Run workflow"
   - Select environment (staging/production)
   - Click "Run workflow"

#### Security Best Practices

1. **Never Commit Secrets:**
   ```bash
   # Add to .gitignore
   echo "*.key" >> .gitignore
   echo "*.json" >> .gitignore
   echo ".env*" >> .gitignore
   ```

2. **Use Environment-Specific Configs:**
   - Keep sensitive configuration in GitHub Secrets
   - Use different Firebase projects for staging/production
   - Validate configs in CI/CD before deployment

3. **Monitor Deployments:**
   - Check Firebase Console after deployments
   - Set up Firebase Analytics for usage monitoring
   - Review GitHub Actions logs for any issues

#### Troubleshooting Firebase Deployment

1. **Permission Errors:**
   ```bash
   # Check Firebase project access
   firebase projects:list
   
   # Verify project selection
   firebase use --project YOUR_PROJECT_ID
   ```

2. **Token Expiration:**
   ```bash
   # Generate new token
   firebase login:ci
   
   # Update GitHub Secret with new token
   ```

3. **Build Failures:**
   - Check GitHub Actions logs
   - Verify all required files exist in `public/` directory
   - Ensure Firebase configuration is valid

## 🔑 Authentication Setup

### For Development/Testing

Get a fresh access token:

```bash
# Run the token helper script
.\get_token.ps1

# Or manually get token
gcloud auth application-default print-access-token
```

Copy the token and paste it into the "Access Token" field in the web app.

### For Production

For production use, implement proper authentication:

1. Create a service account with Vertex AI permissions
2. Use Firebase Authentication
3. Implement a backend API to proxy Vertex AI calls
4. Never expose service account keys in frontend code

## 📁 Project Structure

```
├── .github/
│   ├── workflows/
│   │   └── deploy-model.yml      # CI/CD pipeline
│   ├── configs/
│   │   ├── staging.yml           # Staging config
│   │   └── production.yml        # Production config
│   └── DEPLOYMENT_GUIDE.md       # CI/CD setup guide
├── public/                       # Frontend files (served by Firebase)
│   ├── index.html               # Main HTML file
│   ├── config.js                # Configuration (EDIT THIS!)
│   └── app.js                   # Main application logic
├── deployGCPModels.py           # Model deployment script
├── requirements.txt             # Python dependencies
├── firebase.json                # Firebase hosting config
├── .firebaserc                  # Firebase project config
├── deploy.ps1                   # Automated deployment script
├── get_token.ps1                # Token helper script
├── diagnose_auth.ps1            # Authentication diagnosis
└── README.md                    # This file
```

## 🎯 Usage

1. **Open the deployed web app** (Firebase will provide the URL)
2. **Allow camera access** when prompted
3. **Enter your Vertex AI access token** in the configuration panel
4. **Select analysis interval** (500ms to 5s based on your needs)
5. **Click "Start Analysis"** to begin real-time scene analysis
6. **View scene descriptions** in both the main video area and results panel

### What the App Does

The app continuously analyzes your webcam feed and provides:
- **Real-time scene descriptions** of what's visible
- **Detailed analysis** including people, objects, activities
- **Timestamped results** showing the history of observations
- **Live feedback** with color-coded status indicators

### Analysis Features

- **Generic scene understanding**: Describes everything visible in the frame
- **People detection**: Identifies people and their activities
- **Object recognition**: Identifies objects, furniture, environments
- **Activity analysis**: Describes what's happening in the scene
- **Environment context**: Room type, lighting, setting details

### Example Scene Descriptions

The AI model will provide descriptions like:
- `"A person sitting at a desk with a laptop computer in a well-lit office environment"`
- `"Two people having a conversation in a living room with a couch and coffee table"`
- `"An empty kitchen with modern appliances and natural lighting from a window"`
- `"A person walking through a hallway carrying a bag"`

## 🔧 Configuration Options

### Analysis Intervals

Choose how often to analyze frames:
- **500ms**: Very responsive, higher API usage
- **1s**: Good balance (default)
- **2-5s**: Less responsive, lower costs

### Access Token

You need a valid Google Cloud access token with Vertex AI permissions:
```bash
# Get token for testing
gcloud auth print-access-token

# For production, use service account tokens
```

### Environment Detection

The app automatically detects the environment:
- **Development**: `localhost` - enables debug logging
- **Production**: Any other domain - minimal logging

### Debug Mode

Enable detailed logging in `config.js`:

```javascript
DEBUG: {
    ENABLED: true,  // Set to true for detailed logs
    LOG_RESPONSES: true
}
```

### Environment Variables

The deployment script supports several environment variables for customization:

- **`DEBUG`**: Set to `true` to enable detailed logging during deployment
- **`FORCE_REDEPLOY`**: Set to `true` to force redeployment even if endpoint exists
- **`SKIP_STATUS_CHECK`**: Set to `true` to skip deployment status verification (useful for Model Garden deployments that don't support status checking)
- **`PROJECT_ID`**: Override the GCP project ID from configuration
- **`REGION`**: Override the GCP region from configuration

Example:
```bash
# Enable debug mode and skip status check
set DEBUG=true
set SKIP_STATUS_CHECK=true
python deployGCPModels.py staging

# Force redeploy
set FORCE_REDEPLOY=true
python deployGCPModels.py production
```

## 🚨 Troubleshooting

### Common Issues

#### 1. 403 Permission Errors

```bash
# Check authentication
gcloud auth list

# Ensure correct project is set
gcloud config get-value project

# Re-authenticate if needed
gcloud auth application-default login --project=YOUR_PROJECT_ID
```

#### 2. 400 Bad Request Errors

- Check endpoint ID, project number, and region in `config.js`
- Verify the model expects the correct input format
- Check the model deployment status in Google Cloud Console

#### 3. CORS Errors

Add your Firebase domain to allowed origins in Google Cloud:
1. Go to Google Cloud Console → API & Services → Credentials
2. Edit your OAuth client
3. Add your Firebase hosting domain to authorized origins

#### 4. Camera Access Issues

- Ensure HTTPS (required for camera access)
- Check browser permissions
- Try a different browser

### Diagnostic Tools

Run the authentication diagnosis:

```powershell
.\diagnose_auth.ps1
```

Test the endpoint directly:

```powershell
.\test_endpoint.ps1
```

## 💰 Cost Considerations

- **Vertex AI**: Charged per prediction request
- **Firebase Hosting**: Free tier available
- **Storage**: Minimal for this app

Monitor usage in Google Cloud Console to avoid unexpected charges.

## 🔒 Security Best Practices

1. **Never commit access tokens** to version control
2. **Use service accounts** for production
3. **Implement proper authentication** for production apps
4. **Monitor API usage** to prevent abuse
5. **Use HTTPS** always (Firebase provides this automatically)

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
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)

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

### Option A: Automated CI/CD (Recommended)
```bash
# 1. Setup GitHub Secrets (GCP_SA_KEY, GCP_PROJECT_ID)
# 2. Go to Actions tab → "Deploy Vertex AI Model" → Run workflow
# 3. Update config.js with deployment outputs
# 4. Deploy web app
.\deploy.ps1
```

### Option B: Manual Setup
```bash
# 1. Setup Python environment
python -m venv venv && venv\Scripts\activate
pip install -r requirements.txt

# 2. Authenticate with Google Cloud
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login --project=YOUR_PROJECT_ID

# 3. Deploy Vertex AI model
python deployGCPModels.py

# 4. Update config.js with deployment details

# 5. Setup Firebase
firebase login
firebase init hosting

# 6. Deploy
.\deploy.ps1

# 7. Get access token and use the app
.\get_token.ps1
```

🎉 **Your real-time video analysis app is now live!**
