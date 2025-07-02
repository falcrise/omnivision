# Firebase Deployment Script for Video Analysis App
# Run this script from PowerShell in the project directory

param(
    [switch]$Init,         # Initialize Firebase project
    [switch]$Deploy,       # Deploy to Firebase  
    [switch]$Serve,        # Serve locally for testing
    [switch]$SetProject,   # Set Firebase project
    [switch]$CreateProject, # Create new Firebase project
    [switch]$Force,        # Force deployment even if prerequisites fail
    [switch]$Help          # Show help
)

function Show-Help {
    Write-Host "Firebase Deployment Script for Video Analysis App" -ForegroundColor Cyan
    Write-Host ""    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\deploy.ps1 -SetProject     # Set Firebase project"
    Write-Host "  .\deploy.ps1 -CreateProject  # Create new Firebase project"
    Write-Host "  .\deploy.ps1 -Init           # Initialize Firebase project"
    Write-Host "  .\deploy.ps1 -Deploy         # Deploy to Firebase"
    Write-Host "  .\deploy.ps1 -Serve          # Serve locally for testing"
    Write-Host "  .\deploy.ps1 -Help           # Show this help"
    Write-Host ""
    Write-Host "Prerequisites:" -ForegroundColor Yellow
    Write-Host "  - Node.js and npm installed"
    Write-Host "  - Firebase CLI installed: npm install -g firebase-tools"
    Write-Host "  - Logged in to Firebase: firebase login"
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  Edit public/config.js with your Vertex AI settings before deployment"
}

function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    # Check Node.js
    try {
        $nodeVersion = node --version
        Write-Host "✓ Node.js: $nodeVersion" -ForegroundColor Green
    } catch {
        Write-Host "✗ Node.js not found. Please install from https://nodejs.org/" -ForegroundColor Red
        return $false
    }
    
    # Check Firebase CLI
    try {
        $firebaseVersion = firebase --version
        Write-Host "✓ Firebase CLI: $firebaseVersion" -ForegroundColor Green
    } catch {
        Write-Host "✗ Firebase CLI not found. Install with: npm install -g firebase-tools" -ForegroundColor Red
        return $false
    }
      # Check if logged in to Firebase
    try {
        firebase projects:list --limit 1 2>$null | Out-Null
        Write-Host "✓ Firebase authentication verified" -ForegroundColor Green
    } catch {
        Write-Host "✗ Not logged in to Firebase. Run: firebase login" -ForegroundColor Red
        return $false
    }    # Check if a project is selected
    try {
        # Check if .firebaserc exists first
        if (Test-Path ".firebaserc") {
            $firebaserc = Get-Content ".firebaserc" | ConvertFrom-Json
            $defaultProject = $firebaserc.projects.default
            if ($defaultProject) {
                Write-Host "✓ Firebase project (from .firebaserc): $defaultProject" -ForegroundColor Green
                
                # Check if the project actually exists in Firebase
                if (Test-FirebaseProjectExists -ProjectId $defaultProject) {
                    # Try to verify the project exists and set it as active
                    try {
                        firebase use $defaultProject 2>$null | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "✓ Project verified and set as active" -ForegroundColor Green
                            return $true
                        }
                    } catch {
                        Write-Host "⚠️  Project in .firebaserc may not be accessible" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "✗ Project '$defaultProject' not found in Firebase" -ForegroundColor Red
                    $createProject = Read-Host "Do you want to create the Firebase project '$defaultProject'? (y/N)"
                    if ($createProject -eq "y" -or $createProject -eq "Y") {
                        if (New-FirebaseProject -ProjectId $defaultProject) {
                            # Try again after creation
                            firebase use $defaultProject 2>$null | Out-Null
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "✓ Project created and set as active" -ForegroundColor Green
                                return $true
                            }
                        }
                    }
                    Write-Host "Please create the project or update .firebaserc with an existing project ID" -ForegroundColor Yellow
                    return $false
                }
            }
        }
        
        # Fallback to checking current project
        $currentProject = firebase use --current 2>$null
        if ($currentProject -and $currentProject -notmatch "No project" -and $currentProject -notmatch "Error") {
            Write-Host "✓ Firebase project: $currentProject" -ForegroundColor Green
        } else {
            Write-Host "⚠️  No active Firebase project selected" -ForegroundColor Yellow
            Write-Host "Quick fix: Run .\deploy.ps1 -SetProject" -ForegroundColor Cyan
            Write-Host "Or manually: firebase use falcon-deeptech-ai-stuff" -ForegroundColor Gray
            return $false
        }
    } catch {
        Write-Host "⚠️  Could not determine active Firebase project" -ForegroundColor Yellow
        Write-Host "Quick fix: Run .\deploy.ps1 -SetProject" -ForegroundColor Cyan
        return $false
    }
    
    return $true
}

function Initialize-Firebase {
    Write-Host "Initializing Firebase project..." -ForegroundColor Cyan
    
    # Get project ID from config
    $configProjectId = Get-ProjectIdFromConfig
    
    # First, let's set the project
    Write-Host "Setting up Firebase project..." -ForegroundColor Yellow
    Write-Host "Your project ID from config.js: $configProjectId" -ForegroundColor Cyan
    Write-Host ""
    
    # Try to use the project from config
    $useProject = Read-Host "Use project '$configProjectId' from your config? (Y/n)"
    if ($useProject -eq "" -or $useProject -eq "y" -or $useProject -eq "Y") {
        Write-Host "Setting active project to '$configProjectId'..." -ForegroundColor Yellow
        firebase use $configProjectId
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to set project. Let's see available projects:" -ForegroundColor Red
            firebase projects:list
            Write-Host ""
            Write-Host "Please run: firebase use --add" -ForegroundColor Yellow
            Write-Host "Then select your project from the list" -ForegroundColor Yellow
            return
        }
    } else {
        Write-Host "Please set your project manually:" -ForegroundColor Yellow
        Write-Host "firebase use --add" -ForegroundColor Gray
        return
    }
    
    if (Test-Path "firebase.json") {
        Write-Host "Firebase project already initialized (firebase.json exists)" -ForegroundColor Yellow
        $overwrite = Read-Host "Do you want to reinitialize hosting? (y/N)"
        if ($overwrite -ne "y" -and $overwrite -ne "Y") {
            Write-Host "✓ Using existing Firebase configuration" -ForegroundColor Green
            return
        }
    }
    
    Write-Host "Running firebase init hosting..." -ForegroundColor Yellow
    Write-Host "When prompted:" -ForegroundColor Yellow
    Write-Host "  - Use an existing project: YES (should be pre-selected)" -ForegroundColor Yellow
    Write-Host "  - Public directory: public" -ForegroundColor Yellow
    Write-Host "  - Configure as SPA: Yes" -ForegroundColor Yellow
    Write-Host "  - Overwrite files: No" -ForegroundColor Yellow
    Write-Host ""
    
    firebase init hosting
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Firebase project initialized successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Firebase initialization failed" -ForegroundColor Red
    }
}

function Deploy-ToFirebase {
    Write-Host "Deploying to Firebase..." -ForegroundColor Cyan
    
    if (-not (Test-Path "firebase.json")) {
        Write-Host "✗ Firebase not initialized. Run with -Init first" -ForegroundColor Red
        return
    }
    
    if (-not (Test-Path "public/index.html")) {
        Write-Host "✗ public/index.html not found. Make sure you're in the correct directory" -ForegroundColor Red
        return
    }
    
    # Check if config.js exists and has the right structure
    if (Test-Path "public/config.js") {
        $configContent = Get-Content "public/config.js" -Raw
        if ($configContent -match "YOUR_ENDPOINT_ID" -or $configContent -match "YOUR_PROJECT_ID") {
            Write-Host "⚠️  Warning: config.js still contains placeholder values" -ForegroundColor Yellow
            Write-Host "Please update public/config.js with your actual Vertex AI settings" -ForegroundColor Yellow
            $continue = Read-Host "Continue with deployment anyway? (y/N)"
            if ($continue -ne "y" -and $continue -ne "Y") {
                return
            }
        }
    }
    
    # Try to get project from .firebaserc if project detection failed
    $projectId = $null
    if (Test-Path ".firebaserc") {
        try {
            $firebaserc = Get-Content ".firebaserc" | ConvertFrom-Json
            $projectId = $firebaserc.projects.default
        } catch {
            Write-Host "Could not read .firebaserc file" -ForegroundColor Yellow
        }
    }
    
    Write-Host "Deploying to Firebase Hosting..." -ForegroundColor Yellow
    
    if ($projectId) {
        Write-Host "Using project: $projectId" -ForegroundColor Cyan
        firebase deploy --project $projectId
    } else {
        # Try without specifying project (in case it's set but not detected)
        firebase deploy
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Deployment successful!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Your app is now live! Get the URL with:" -ForegroundColor Green
        if ($projectId) {
            Write-Host "firebase hosting:sites:list --project $projectId" -ForegroundColor Gray
        } else {
            Write-Host "firebase hosting:sites:list" -ForegroundColor Gray
        }
    } else {
        Write-Host "✗ Deployment failed" -ForegroundColor Red
        if (-not $projectId) {
            Write-Host "Try setting the project first: .\deploy.ps1 -SetProject" -ForegroundColor Yellow
        }
    }
}

function Serve-Locally {
    Write-Host "Starting local development server..." -ForegroundColor Cyan
    
    if (-not (Test-Path "firebase.json")) {
        Write-Host "✗ Firebase not initialized. Run with -Init first" -ForegroundColor Red
        return
    }
    
    Write-Host "Starting Firebase emulator..." -ForegroundColor Yellow
    Write-Host "Access your app at: http://localhost:5000" -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
    
    firebase serve
}

function Get-AccessToken {
    Write-Host "Getting Google Cloud access token..." -ForegroundColor Cyan
    
    try {
        $token = gcloud auth application-default print-access-token 2>$null
        if ($token) {
            Write-Host "✓ Access token retrieved successfully" -ForegroundColor Green
            Write-Host "Token (copy this to your app):" -ForegroundColor Yellow
            Write-Host $token -ForegroundColor Gray
            Write-Host ""
            Write-Host "Note: This token expires in about 1 hour" -ForegroundColor Yellow
        } else {
            Write-Host "✗ Failed to get access token" -ForegroundColor Red
            Write-Host "Try running: gcloud auth application-default login" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "✗ gcloud CLI not found or not authenticated" -ForegroundColor Red
        Write-Host "Install gcloud CLI and run: gcloud auth application-default login" -ForegroundColor Yellow
    }
}

function Set-FirebaseProject {
    Write-Host "Setting Firebase project..." -ForegroundColor Cyan
    
    Write-Host "Available Firebase projects:" -ForegroundColor Yellow
    firebase projects:list
    
    Write-Host ""
    $configProjectId = Get-ProjectIdFromConfig
    Write-Host "Your project ID from config.js: $configProjectId" -ForegroundColor Cyan
    Write-Host ""
    
    $projectId = Read-Host "Enter project ID to use (or press Enter for '$configProjectId')"
    if ($projectId -eq "") {
        $projectId = $configProjectId
    }
    
    # Check if the project exists before trying to use it
    if (-not (Test-FirebaseProjectExists -ProjectId $projectId)) {
        Write-Host "Project '$projectId' not found in your Firebase projects." -ForegroundColor Red
        Write-Host ""
        
        $createNew = Read-Host "Do you want to create this Firebase project? (y/N)"
        if ($createNew -eq "y" -or $createNew -eq "Y") {
            if (-not (New-FirebaseProject -ProjectId $projectId)) {
                Write-Host "Project creation failed or cancelled." -ForegroundColor Red
                return
            }
        } else {
            Write-Host "Please use an existing project ID or create the project manually at:" -ForegroundColor Yellow
            Write-Host "https://console.firebase.google.com/" -ForegroundColor Gray
            return
        }
    }
    
    Write-Host "Setting active project to '$projectId'..." -ForegroundColor Yellow
    firebase use $projectId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Project '$projectId' set successfully" -ForegroundColor Green
        
        # Enable hosting if needed
        if (Enable-FirebaseHosting -ProjectId $projectId) {
            Write-Host "✓ Firebase Hosting is ready" -ForegroundColor Green
        }
        
        # Update .firebaserc file
        $firebaserc = @{
            projects = @{
                default = $projectId
            }
        }
        $firebaserc | ConvertTo-Json | Set-Content ".firebaserc"
        Write-Host "✓ Updated .firebaserc with project '$projectId'" -ForegroundColor Green
        
    } else {
        Write-Host "✗ Failed to set project '$projectId'" -ForegroundColor Red
        Write-Host "Make sure the project ID is correct and you have access to it" -ForegroundColor Yellow
    }
}

function Test-FirebaseProjectExists {
    param([string]$ProjectId)
    
    Write-Host "Checking if Firebase project '$ProjectId' exists..." -ForegroundColor Yellow
    
    try {
        # Try to get project info
        $response = firebase projects:list --json 2>$null | ConvertFrom-Json
        
        # Handle different response formats
        $projectList = $null
        if ($response.result) {
            # New format: { "status": "success", "result": [...] }
            $projectList = $response.result
        } elseif ($response -is [Array]) {
            # Old format: direct array
            $projectList = $response
        } else {
            # Single project or other format
            $projectList = @($response)
        }
        
        $project = $projectList | Where-Object { $_.projectId -eq $ProjectId }
        
        if ($project) {
            Write-Host "✓ Project '$ProjectId' found in Firebase" -ForegroundColor Green
            Write-Host "  Display Name: $($project.displayName)" -ForegroundColor Gray
            Write-Host "  Project Number: $($project.projectNumber)" -ForegroundColor Gray
            Write-Host "  State: $($project.state)" -ForegroundColor Gray
            if ($project.resources.hostingSite) {
                Write-Host "  Hosting Site: $($project.resources.hostingSite)" -ForegroundColor Gray
            }
            return $true
        } else {
            Write-Host "✗ Project '$ProjectId' not found in your Firebase projects" -ForegroundColor Red
            
            # Debug: Show available projects
            Write-Host "Available projects:" -ForegroundColor Yellow
            foreach ($p in $projectList) {
                Write-Host "  - $($p.projectId) ($($p.displayName))" -ForegroundColor Gray
            }
            
            return $false
        }
    } catch {
        Write-Host "⚠️  Could not check Firebase projects. Error: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "You may not be logged in or have permission issues." -ForegroundColor Yellow
        return $false
    }
}

function New-FirebaseProject {
    param([string]$ProjectId, [string]$DisplayName = $null)
    
    Write-Host "Creating new Firebase project..." -ForegroundColor Cyan
    
    if (-not $DisplayName) {
        $DisplayName = Read-Host "Enter display name for the project (or press Enter for '$ProjectId')"
        if ($DisplayName -eq "") {
            $DisplayName = $ProjectId
        }
    }
    
    Write-Host "Creating project with:" -ForegroundColor Yellow
    Write-Host "  Project ID: $ProjectId" -ForegroundColor Gray
    Write-Host "  Display Name: $DisplayName" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Create this Firebase project? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Project creation cancelled" -ForegroundColor Yellow
        return $false
    }
    
    # Note: Firebase CLI doesn't support creating projects directly
    # We need to guide the user to the Firebase Console
    Write-Host "⚠️  Firebase CLI doesn't support creating projects directly." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please create the project manually:" -ForegroundColor Cyan
    Write-Host "1. Go to: https://console.firebase.google.com/" -ForegroundColor Gray
    Write-Host "2. Click 'Add project' or 'Create a project'" -ForegroundColor Gray
    Write-Host "3. Use Project ID: $ProjectId" -ForegroundColor Gray
    Write-Host "4. Use Display Name: $DisplayName" -ForegroundColor Gray
    Write-Host "5. Follow the setup wizard" -ForegroundColor Gray
    Write-Host ""
    
    $openBrowser = Read-Host "Open Firebase Console in browser? (y/N)"
    if ($openBrowser -eq "y" -or $openBrowser -eq "Y") {
        try {
            Start-Process "https://console.firebase.google.com/"
            Write-Host "✓ Opened Firebase Console in browser" -ForegroundColor Green
        } catch {
            Write-Host "Could not open browser. Please visit: https://console.firebase.google.com/" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    $waitForProject = Read-Host "Press Enter after creating the project to continue..."
    
    # Check if project now exists
    if (Test-FirebaseProjectExists -ProjectId $ProjectId) {
        Write-Host "✓ Project created successfully!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✗ Project still not found. Please check the project ID and try again." -ForegroundColor Red
        return $false
    }
}

function Enable-FirebaseHosting {
    param([string]$ProjectId)
    
    Write-Host "Enabling Firebase Hosting for project '$ProjectId'..." -ForegroundColor Yellow
    
    try {
        # Try to enable hosting (this will work if the project exists)
        firebase use $ProjectId 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "✗ Could not set project. Project may not exist or you may not have access." -ForegroundColor Red
            return $false
        }
        
        Write-Host "✓ Firebase Hosting is available for this project" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "⚠️  Could not verify Firebase Hosting status" -ForegroundColor Yellow
        return $false
    }
}

function Get-ProjectIdFromConfig {
    if (Test-Path "public/config.js") {
        try {
            $configContent = Get-Content "public/config.js" -Raw
            if ($configContent -match 'PROJECT_ID:\s*["''](.*?)["'']') {
                return $matches[1]
            }
        } catch {
            Write-Host "Could not read project ID from config.js" -ForegroundColor Yellow
        }
    }
    return "falcon-deeptech-ai-stuff"  # fallback
}

# Main script logic
if ($Help) {
    Show-Help
    exit
}

# Allow force deployment to bypass project checks
if ($Force -and $Deploy) {
    Write-Host "Force deployment mode - bypassing project checks" -ForegroundColor Yellow
    Deploy-ToFirebase
    exit
}

if (-not (Test-Prerequisites)) {
    if ($Deploy) {
        Write-Host ""
        Write-Host "Try force deployment: .\deploy.ps1 -Deploy -Force" -ForegroundColor Cyan
    }
    exit 1
}

if ($Init) {
    Initialize-Firebase
} elseif ($Deploy) {
    Deploy-ToFirebase
} elseif ($Serve) {
    Serve-Locally
} elseif ($SetProject) {
    Set-FirebaseProject
} elseif ($CreateProject) {
    Write-Host "Creating new Firebase project..." -ForegroundColor Cyan
    $configProjectId = Get-ProjectIdFromConfig
    $projectId = Read-Host "Enter project ID for new project (or press Enter for '$configProjectId')"
    if ($projectId -eq "") {
        $projectId = $configProjectId
    }
    New-FirebaseProject -ProjectId $projectId
} else {
    Write-Host "Video Analysis App - Firebase Deployment" -ForegroundColor Cyan
    Write-Host ""    Write-Host "Quick start:" -ForegroundColor Yellow
    Write-Host "1. .\deploy.ps1 -SetProject     # Set/create Firebase project"
    Write-Host "2. .\deploy.ps1 -Init           # Initialize Firebase hosting"
    Write-Host "3. .\deploy.ps1 -Serve          # Test locally"
    Write-Host "4. .\deploy.ps1 -Deploy         # Deploy to Firebase"
    Write-Host ""
    Write-Host "Use -Help for more information"
    Write-Host ""
    
    # Offer to get access token
    $getToken = Read-Host "Do you want to get a Google Cloud access token now? (y/N)"
    if ($getToken -eq "y" -or $getToken -eq "Y") {
        Get-AccessToken
    }
}
