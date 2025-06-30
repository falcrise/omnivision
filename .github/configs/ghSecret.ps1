# PowerShell Script for Setting up GitHub Secrets for Vertex AI Deployment

param(
    [string]$ProjectId = "",
    [switch]$Help,
    [switch]$Debug
)

function Show-Help {
    Write-Host ""
    Write-Host "🚀 GitHub Secrets Setup for Vertex AI Deployment" -ForegroundColor Cyan
    Write-Host "=================================================="
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\ghSecret.ps1                    # Interactive mode"
    Write-Host "  .\ghSecret.ps1 -ProjectId <ID>    # Direct project ID"
    Write-Host "  .\ghSecret.ps1 -Debug             # Enable debug output"
    Write-Host "  .\ghSecret.ps1 -Help              # Show this help"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\ghSecret.ps1"
    Write-Host "  .\ghSecret.ps1 -ProjectId 'falcon-deeptech-ai-stuff'"
    Write-Host "  .\ghSecret.ps1 -ProjectId 'falcon-deeptech-ai-stuff' -Debug"
    Write-Host ""
    Write-Host "Prerequisites:" -ForegroundColor Yellow
    Write-Host "  - Google Cloud CLI (gcloud) installed and authenticated"
    Write-Host "  - Appropriate permissions to create service accounts"
    Write-Host "  - Access to your GitHub repository settings"
    Write-Host ""
}

function Write-Debug {
    param([string]$Message)
    if ($Debug) {
        Write-Host "[DEBUG] $Message" -ForegroundColor DarkGray
    }
}

# function Test-Prerequisites {
#     Write-Host "🔍 Checking prerequisites..." -ForegroundColor Yellow
    
#     # Check if gcloud is installed
#     try {
#         Write-Debug "Testing gcloud installation..."
#         $gcloudVersion = gcloud version --format="value(Google Cloud SDK)" 2>$null
#         if ($gcloudVersion) {
#             Write-Host "✓ Google Cloud CLI: $gcloudVersion" -ForegroundColor Green
#             Write-Debug "gcloud version check successful"
#         } else {
#             throw "gcloud not found"
#         }
#     } catch {
#         Write-Host "✗ Google Cloud CLI not found" -ForegroundColor Red
#         Write-Host "Please install Google Cloud CLI from: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
#         return $false
#     }
    
#     # Check if authenticated
#     try {
#         Write-Debug "Checking authentication..."
#         $currentAccount = gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null
#         if ($currentAccount) {
#             Write-Host "✓ Authenticated as: $currentAccount" -ForegroundColor Green
#             Write-Debug "Authentication check successful: $currentAccount"
#         } else {
#             throw "No active authentication"
#         }
#     } catch {
#         Write-Host "✗ Not authenticated with Google Cloud" -ForegroundColor Red
#         Write-Host "Please run: gcloud auth login" -ForegroundColor Yellow
#         return $false
#     }
    
#     # Check current project
#     try {
#         Write-Debug "Checking current project..."
#         $currentProject = gcloud config get-value project 2>$null
#         if ($currentProject) {
#             Write-Host "✓ Current project: $currentProject" -ForegroundColor Green
#             Write-Debug "Current project: $currentProject"
#         } else {
#             Write-Host "⚠️  No current project set" -ForegroundColor Yellow
#             Write-Debug "No current project configured"
#         }
#     } catch {
#         Write-Debug "Could not get current project"
#     }
    
#     return $true
# }

function Get-ProjectId {
    param([string]$InputProjectId)
    
    if ($InputProjectId) {
        Write-Debug "Using provided project ID: $InputProjectId"
        return $InputProjectId
    }
    
    # Show available projects
    Write-Host ""
    Write-Host "📋 Available projects:" -ForegroundColor Cyan
    try {
        Write-Debug "Listing available projects..."
        gcloud projects list --format="table(projectId,name,projectNumber)" --limit=10
    } catch {
        Write-Host "⚠️  Could not list projects. You may have limited access." -ForegroundColor Yellow
        Write-Debug "Project listing failed: $($_.Exception.Message)"
    }
    
    Write-Host ""
    $projectId = Read-Host "Enter your GCP Project ID (e.g., falcon-deeptech-ai-stuff)"
    
    if (-not $projectId) {
        Write-Host "✗ Project ID is required" -ForegroundColor Red
        exit 1
    }
    
    Write-Debug "User entered project ID: $projectId"
    return $projectId
}

function Test-ProjectExists {
    param([string]$ProjectId)
    
    Write-Host "🔍 Verifying project '$ProjectId' exists..." -ForegroundColor Yellow
    Write-Debug "Testing project existence: $ProjectId"
    
    try {
        $project = gcloud projects describe $ProjectId --format="value(projectId)" 2>$null
        Write-Debug "Project describe result: '$project'"
        
        if ($project -eq $ProjectId) {
            Write-Host "✓ Project '$ProjectId' found" -ForegroundColor Green
            Write-Debug "Project verification successful"
            return $true
        } else {
            Write-Host "✗ Project '$ProjectId' not found or not accessible" -ForegroundColor Red
            Write-Debug "Project verification failed - not found or no access"
            return $false
        }
    } catch {
        Write-Host "✗ Error checking project: $($_.Exception.Message)" -ForegroundColor Red
        Write-Debug "Project check exception: $($_.Exception.Message)"
        return $false
    }
}

function Test-ServiceAccountPermissions {
    param([string]$ProjectId)
    
    Write-Host "🔐 Checking your permissions..." -ForegroundColor Yellow
    Write-Debug "Testing service account creation permissions"
    
    try {
        # Test if we can list service accounts (indicates we have IAM permissions)
        $serviceAccounts = gcloud iam service-accounts list --project=$ProjectId --format="value(email)" --limit=1 2>$null
        Write-Debug "Service account list test result: $($serviceAccounts -ne $null)"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ You have IAM permissions" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️  Limited IAM permissions detected" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "⚠️  Could not verify IAM permissions" -ForegroundColor Yellow
        Write-Debug "Permission check failed: $($_.Exception.Message)"
        return $false
    }
}

function New-ServiceAccount {
    param([string]$ProjectId)
    
    $serviceAccountEmail = "vertex-ai-deployer@$ProjectId.iam.gserviceaccount.com"
    Write-Debug "Target service account email: $serviceAccountEmail"
    
    Write-Host "📋 Creating service account..." -ForegroundColor Yellow
    
    # Check if service account already exists
    try {
        Write-Debug "Checking if service account already exists..."
        $existingAccount = gcloud iam service-accounts describe $serviceAccountEmail --project=$ProjectId --format="value(email)" 2>$null
        Write-Debug "Existing account check result: '$existingAccount'"
        
        if ($existingAccount) {
            Write-Host "⚠️  Service account already exists: $serviceAccountEmail" -ForegroundColor Yellow
            $recreate = Read-Host "Do you want to use the existing service account? (y/N)"
            if ($recreate -ne "y" -and $recreate -ne "Y") {
                Write-Host "✗ Aborted by user" -ForegroundColor Red
                exit 1
            }
            Write-Host "✓ Using existing service account" -ForegroundColor Green
            Write-Debug "Using existing service account"
            return $serviceAccountEmail
        }
    } catch {
        Write-Debug "Service account doesn't exist (expected): $($_.Exception.Message)"
        # Service account doesn't exist, which is expected
    }
    
    # Create new service account
    try {
        Write-Debug "Creating new service account..."
        $output = gcloud iam service-accounts create vertex-ai-deployer `
            --project=$ProjectId `
            --display-name="Vertex AI Model Deployer" `
            --description="Service account for GitHub Actions to deploy Vertex AI models" 2>&1
        
        Write-Debug "Service account creation output: $output"
        Write-Debug "Exit code: $LASTEXITCODE"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Service account created successfully" -ForegroundColor Green
            Write-Debug "Service account creation successful"
            return $serviceAccountEmail
        } else {
            Write-Host "✗ Service account creation failed" -ForegroundColor Red
            Write-Host "Error output: $output" -ForegroundColor Red
            throw "gcloud command failed with exit code $LASTEXITCODE"
        }
    } catch {
        Write-Host "✗ Failed to create service account: $($_.Exception.Message)" -ForegroundColor Red
        Write-Debug "Service account creation exception: $($_.Exception.Message)"
        exit 1
    }
}

function Add-ServiceAccountPermissions {
    param(
        [string]$ProjectId,
        [string]$ServiceAccountEmail
    )
    
    Write-Host "🔐 Adding required permissions..." -ForegroundColor Yellow
    Write-Debug "Adding permissions for: $ServiceAccountEmail"
    
    $roles = @(
        "roles/aiplatform.admin",
        "roles/storage.admin", 
        "roles/iam.serviceAccountUser"
    )
    
    foreach ($role in $roles) {
        Write-Host "  Adding role: $role" -ForegroundColor Gray
        Write-Debug "Adding role: $role"
        
        try {
            $output = gcloud projects add-iam-policy-binding $ProjectId `
                --member="serviceAccount:$ServiceAccountEmail" `
                --role="$role" `
                --quiet 2>&1
                
            Write-Debug "Role addition output: $output"
            Write-Debug "Exit code: $LASTEXITCODE"
                
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ Added $role" -ForegroundColor Green
                Write-Debug "Successfully added role: $role"
            } else {
                Write-Host "  ✗ Failed to add role $role" -ForegroundColor Red
                Write-Host "    Error: $output" -ForegroundColor Red
                Write-Debug "Failed to add role: $role, Error: $output"
            }
        } catch {
            Write-Host "  ✗ Failed to add role $role" -ForegroundColor Red
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Debug "Role addition exception: $($_.Exception.Message)"
        }
    }
}

function New-ServiceAccountKey {
    param(
        [string]$ProjectId,
        [string]$ServiceAccountEmail
    )
    
    Write-Host "🔑 Creating service account key..." -ForegroundColor Yellow
    Write-Debug "Creating key for: $ServiceAccountEmail"
    
    $keyFileName = "vertex-ai-deployer-key.json"
    $fullPath = Join-Path (Get-Location) $keyFileName
    Write-Debug "Key file path: $fullPath"
    
    # Remove existing key file if it exists
    if (Test-Path $keyFileName) {
        Write-Host "⚠️  Removing existing key file" -ForegroundColor Yellow
        Write-Debug "Removing existing key file: $keyFileName"
        Remove-Item $keyFileName -Force
    }
    
    try {
        Write-Debug "Executing gcloud iam service-accounts keys create command..."
        
        # Try with explicit output format and error capture
        $output = gcloud iam service-accounts keys create $keyFileName `
            --iam-account=$ServiceAccountEmail `
            --project=$ProjectId `
            --key-file-type=json 2>&1
            
        Write-Debug "Key creation output: $output"
        Write-Debug "Exit code: $LASTEXITCODE"
        Write-Debug "File exists after creation: $(Test-Path $keyFileName)"
        
        if (Test-Path $keyFileName) {
            $fileSize = (Get-Item $keyFileName).Length
            Write-Debug "Key file size: $fileSize bytes"
            
            if ($fileSize -gt 100) {  # JSON key should be at least a few hundred bytes
                Write-Host "✓ Service account key created: $keyFileName" -ForegroundColor Green
                Write-Debug "Key file created successfully"
                return $keyFileName
            } else {
                Write-Host "✗ Key file created but seems invalid (too small: $fileSize bytes)" -ForegroundColor Red
                Write-Debug "Key file too small, likely invalid"
                throw "Key file created but appears invalid"
            }
        } else {
            Write-Host "✗ Key file was not created" -ForegroundColor Red
            Write-Host "Command output: $output" -ForegroundColor Red
            Write-Debug "Key file not found after creation attempt"
            throw "Key file not created"
        }
    } catch {
        Write-Host "✗ Failed to create service account key: $($_.Exception.Message)" -ForegroundColor Red
        Write-Debug "Key creation exception: $($_.Exception.Message)"
        
        # Additional troubleshooting information
        Write-Host ""
        Write-Host "🔍 Troubleshooting Information:" -ForegroundColor Yellow
        Write-Host "1. Check if you have 'Service Account Key Admin' role" -ForegroundColor Gray
        Write-Host "2. Verify the service account exists and you have access" -ForegroundColor Gray
        Write-Host "3. Try running: gcloud iam service-accounts describe $ServiceAccountEmail --project=$ProjectId" -ForegroundColor Gray
        Write-Host "4. Check your current directory permissions for file creation" -ForegroundColor Gray
        
        exit 1
    }
}

function Show-NextSteps {
    param(
        [string]$ProjectId,
        [string]$KeyFileName
    )
    
    Write-Host ""
    Write-Host "✅ Setup Complete!" -ForegroundColor Green
    Write-Host "==================="
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Go to your GitHub repository" -ForegroundColor White
    Write-Host "2. Navigate to Settings → Secrets and variables → Actions" -ForegroundColor White
    Write-Host "3. Add these repository secrets:" -ForegroundColor White
    Write-Host ""
    Write-Host "🔒 Secret Name: " -NoNewline -ForegroundColor Yellow
    Write-Host "GCP_SA_KEY" -ForegroundColor Green
    Write-Host "   Secret Value: " -NoNewline -ForegroundColor Yellow
    Write-Host "[Copy the entire content of $KeyFileName]" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🔒 Secret Name: " -NoNewline -ForegroundColor Yellow  
    Write-Host "GCP_PROJECT_ID" -ForegroundColor Green
    Write-Host "   Secret Value: " -NoNewline -ForegroundColor Yellow
    Write-Host "$ProjectId" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📄 The service account key file has been saved as: " -NoNewline -ForegroundColor Cyan
    Write-Host "$KeyFileName" -ForegroundColor White
    Write-Host "🗑️  Remember to delete this file after adding it to GitHub Secrets!" -ForegroundColor Red
    Write-Host ""
    Write-Host "🚀 After adding the secrets, you can run the GitHub Actions workflow!" -ForegroundColor Green
    Write-Host ""
    
    # Show file content preview
    if (Test-Path $KeyFileName) {
        try {
            $keyContent = Get-Content $KeyFileName -Raw
            $keyPreview = $keyContent.Substring(0, [Math]::Min(200, $keyContent.Length)) + "..."
            Write-Host "📄 Key file preview (first 200 characters):" -ForegroundColor Cyan
            Write-Host $keyPreview -ForegroundColor DarkGray
            Write-Host ""
        } catch {
            Write-Debug "Could not preview key file: $($_.Exception.Message)"
        }
    }
    
    # Offer to open the key file for copying
    $openFile = Read-Host "Do you want to open the key file for copying? (y/N)"
    if ($openFile -eq "y" -or $openFile -eq "Y") {
        if (Test-Path $KeyFileName) {
            Write-Host "📂 Opening $KeyFileName..." -ForegroundColor Yellow
            try {
                Start-Process notepad $KeyFileName
                Write-Debug "Opened file in notepad"
            } catch {
                Write-Host "Could not open in notepad, trying default editor..." -ForegroundColor Yellow
                try {
                    Start-Process $KeyFileName
                    Write-Debug "Opened file with default application"
                } catch {
                    Write-Host "Could not open file automatically. Please open manually: $KeyFileName" -ForegroundColor Yellow
                    Write-Debug "Failed to open file: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Host "✗ Key file not found" -ForegroundColor Red
        }
    }
    
    # Offer to copy content to clipboard
    $copyContent = Read-Host "Do you want to copy the key file content to clipboard? (y/N)"
    if ($copyContent -eq "y" -or $copyContent -eq "Y") {
        try {
            if (Test-Path $KeyFileName) {
                $content = Get-Content $KeyFileName -Raw
                Set-Clipboard -Value $content
                Write-Host "✓ Key file content copied to clipboard" -ForegroundColor Green
                Write-Debug "Key content copied to clipboard"
            } else {
                Write-Host "✗ Key file not found" -ForegroundColor Red
            }
        } catch {
            Write-Host "✗ Could not copy to clipboard: $($_.Exception.Message)" -ForegroundColor Red
            Write-Debug "Clipboard copy failed: $($_.Exception.Message)"
        }
    }
    
    # Offer to copy project ID to clipboard
    try {
        if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
            $copyProjectId = Read-Host "Do you want to copy Project ID to clipboard? (y/N)"
            if ($copyProjectId -eq "y" -or $copyProjectId -eq "Y") {
                Set-Clipboard -Value $ProjectId
                Write-Host "✓ Project ID copied to clipboard" -ForegroundColor Green
                Write-Debug "Project ID copied to clipboard"
            }
        }
    } catch {
        Write-Debug "Clipboard operations not available"
    }
}

# Main script execution
if ($Help) {
    Show-Help
    exit 0
}

Write-Host ""
Write-Host "🚀 Setting up GitHub Secrets for Vertex AI Deployment" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

if ($Debug) {
    Write-Host "🐛 Debug mode enabled" -ForegroundColor DarkYellow
    Write-Host ""
}

# Check prerequisites
if (-not (Test-Prerequisites)) {
    exit 1
}

# Get project ID
$projectId = Get-ProjectId -InputProjectId $ProjectId

# Verify project exists
if (-not (Test-ProjectExists -ProjectId $projectId)) {
    Write-Host "Please check your project ID and try again" -ForegroundColor Yellow
    exit 1
}

# Check permissions
Test-ServiceAccountPermissions -ProjectId $projectId

# Create service account
$serviceAccountEmail = New-ServiceAccount -ProjectId $projectId

# Add permissions
Add-ServiceAccountPermissions -ProjectId $projectId -ServiceAccountEmail $serviceAccountEmail

# Create key
$keyFileName = New-ServiceAccountKey -ProjectId $projectId -ServiceAccountEmail $serviceAccountEmail

# Show next steps
Show-NextSteps -ProjectId $projectId -KeyFileName $keyFileName

Write-Host ""
Write-Host "🎯 Quick Commands for GitHub Secrets:" -ForegroundColor Cyan
Write-Host "======================================"
Write-Host "Copy key to clipboard:" -ForegroundColor Yellow
Write-Host "Get-Content vertex-ai-deployer-key.json -Raw | Set-Clipboard" -ForegroundColor White
Write-Host ""
Write-Host "Secret Name: GCP_PROJECT_ID" -ForegroundColor Yellow
Write-Host "Value: $projectId" -ForegroundColor White
Write-Host ""