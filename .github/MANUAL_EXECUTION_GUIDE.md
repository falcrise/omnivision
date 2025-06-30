# Manual Workflow Execution Guide

## 🎯 How to Run the Deployment Pipeline Manually

Your GitHub Actions workflow supports manual execution with full customization options. Here's how to use it:

### 📋 **Step-by-Step Instructions**

#### 1. **Navigate to GitHub Actions**
   - Go to your GitHub repository
   - Click on the **"Actions"** tab at the top
   - Look for **"Deploy Vertex AI Model"** in the workflow list on the left

#### 2. **Start Manual Execution**
   - Click on **"Deploy Vertex AI Model"** workflow
   - You'll see a **"Run workflow"** button on the right side
   - Click **"Run workflow"**

#### 3. **Configure Deployment Parameters**

The workflow will present you with these options:

| Parameter | Options | Description | Recommendation |
|-----------|---------|-------------|----------------|
| **Model** | `smolvlm-instruct`, `custom` | AI model to deploy | Use `smolvlm-instruct` |
| **Machine Type** | `g2-standard-4/8/12/16` | Compute resources | `g2-standard-12` for production |
| **Min Replicas** | `1-10` | Always-running instances | `1` for testing, `2` for production |
| **Max Replicas** | `1-20` | Auto-scaling limit | `3` for testing, `5` for production |
| **Environment** | `staging`, `production` | Deployment target | `staging` for testing |
| **Force Redeploy** | `true`, `false` | Replace existing endpoint | `false` unless updating |

#### 4. **Recommended Configurations**

##### 🧪 **For Testing/Development:**
```
Model: smolvlm-instruct
Machine Type: g2-standard-8
Min Replicas: 1
Max Replicas: 2
Environment: staging
Force Redeploy: false
```

##### 🚀 **For Production:**
```
Model: smolvlm-instruct
Machine Type: g2-standard-12
Min Replicas: 2
Max Replicas: 5
Environment: production
Force Redeploy: false
```

#### 5. **Execute Deployment**
   - After configuring parameters, click **"Run workflow"**
   - The deployment will start immediately
   - Monitor progress in the Actions tab

### 📊 **Understanding Machine Types**

| Machine Type | vCPU | RAM | GPU | Use Case | Cost |
|--------------|------|-----|-----|----------|------|
| `g2-standard-4` | 4 | 16GB | 1x L4 | Light testing | Lower |
| `g2-standard-8` | 8 | 32GB | 1x L4 | Development/Staging | Medium |
| `g2-standard-12` | 12 | 48GB | 1x L4 | **Recommended Production** | Higher |
| `g2-standard-16` | 16 | 64GB | 1x L4 | High-performance | Highest |

### 🔍 **Monitoring Deployment**

#### **During Deployment:**
1. **Real-time Logs**: Click on the running workflow to see live logs
2. **Progress Steps**: Each step shows status (✅ success, ❌ failed, 🔄 running)
3. **Configuration Display**: Verify your selected parameters

#### **After Deployment:**
1. **Deployment Summary**: Comprehensive table with all details
2. **Artifacts**: Download `deployment_outputs.json` with endpoint configuration
3. **Next Steps**: Clear instructions for updating your web app

### 📥 **Using Deployment Outputs**

After successful deployment:

1. **Download Artifacts**:
   - Go to the completed workflow run
   - Scroll down to "Artifacts" section
   - Download `deployment-outputs-[run-number]`

2. **Extract Configuration**:
   - Unzip the downloaded file
   - Open `deployment_outputs.json`
   - Find the `api_config` section

3. **Update Your App**:
   ```javascript
   // Update public/config.js with these values:
   VERTEX_AI: {
       ENDPOINT_ID: "from deployment_outputs.json",
       PROJECT_ID: "your-project-number",
       REGION: "asia-southeast1"
   }
   ```

### 🚨 **Troubleshooting Manual Runs**

#### **Common Issues:**

1. **"Run workflow" button not visible**
   - Ensure you're on the correct repository
   - Check that you have write permissions
   - Verify you're on the main branch

2. **Deployment fails immediately**
   - Check GitHub Secrets are configured (`GCP_SA_KEY`, `GCP_PROJECT_ID`)
   - Verify service account has proper permissions
   - Ensure Google Cloud project has Vertex AI API enabled

3. **Resource quota errors**
   - Check GPU quotas in your Google Cloud region
   - Try a smaller machine type
   - Request quota increase if needed

#### **Debug Steps:**
1. Check the workflow logs for specific error messages
2. Verify your Google Cloud project settings
3. Test authentication with a simple workflow first
4. Review the deployment guide for setup requirements

### ⚡ **Quick Manual Deployment**

For experienced users, here's the fastest way:

1. **Actions** → **Deploy Vertex AI Model** → **Run workflow**
2. **Select**: `g2-standard-12`, `staging`, `1-3 replicas`
3. **Click**: "Run workflow"
4. **Wait**: ~10-15 minutes for completion
5. **Download**: Artifacts and update `config.js`

### 🔄 **Redeployment**

To update an existing deployment:
- Set **Force Redeploy** to `true`
- Use the same or different configuration
- The old endpoint will be replaced

### 💡 **Pro Tips**

1. **Start Small**: Use `staging` environment and `g2-standard-8` for initial testing
2. **Monitor Costs**: Check Google Cloud Console for resource usage
3. **Save Configs**: Document successful configurations for reuse
4. **Test First**: Always test in staging before production deployment
5. **Backup**: Keep deployment artifacts for configuration history

---

## 🎉 **Ready to Deploy?**

Your manual deployment workflow is fully configured and ready to use! The process typically takes 10-15 minutes and provides all the configuration details needed for your web application.

**Next Step**: Go to your repository's Actions tab and click "Run workflow" to get started! 🚀
