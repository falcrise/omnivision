#!/usr/bin/env pwsh
# Firebase Deployment Script for Local Development
# This script helps deploy the video analysis app to Firebase Hosting

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("staging", "production")]
    [string]$Environment = "staging",
    
    [Parameter(Mandatory = $false)]
    [switch]$Preview = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$ValidateOnly = $false
)

$ErrorActionPreference = "Stop"

# Color output functions
function Write-ColoredText {
    param([string]$Text, [string]$Color = "White")
    switch ($Color) {
        "Green" { Write-Host $Text -ForegroundColor Green }
        "Red" { Write-Host $Text -ForegroundColor Red }
        "Yellow" { Write-Host $Text -ForegroundColor Yellow }
        "Cyan" { Write-Host $Text -ForegroundColor Cyan }
        "Magenta" { Write-Host $Text -ForegroundColor Magenta }
        default { Write-Host $Text }
    }
}

function Write-Success { param([string]$Text) Write-ColoredText "✅ $Text" "Green" }
function Write-Error { param([string]$Text) Write-ColoredText "❌ $Text" "Red" }
function Write-Warning { param([string]$Text) Write-ColoredText "⚠️ $Text" "Yellow" }
function Write-Info { param([string]$Text) Write-ColoredText "ℹ️ $Text" "Cyan" }
function Write-Step { param([string]$Text) Write-ColoredText "🔄 $Text" "Magenta" }

# Banner
Write-Host ""
Write-ColoredText "🔥 Firebase Deployment Script" "Cyan"
Write-ColoredText "================================" "Cyan"
Write-Host ""

# Validate environment
Write-Step "Validating environment: $Environment"

# Check if required tools are installed
Write-Step "Checking required tools..."

# Check Node.js
try {
    $nodeVersion = node --version
    Write-Success "Node.js version: $nodeVersion"
} catch {
    Write-Error "Node.js is not installed or not in PATH"
    Write-Info "Please install Node.js from https://nodejs.org/"
    exit 1
}

# Check npm
try {
    $npmVersion = npm --version
    Write-Success "npm version: $npmVersion"
} catch {
    Write-Error "npm is not available"
    exit 1
}

# Check Firebase CLI
try {
    $firebaseVersion = firebase --version
    Write-Success "Firebase CLI version: $firebaseVersion"
} catch {
    Write-Error "Firebase CLI is not installed"
    Write-Info "Install with: npm install -g firebase-tools"
    exit 1
}

# Validate project structure
Write-Step "Validating project structure..."

$requiredFiles = @(
    "firebase.json",
    ".firebaserc",
    "public/index.html",
    "public/app.js",
    "public/config.js"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Success "Found: $file"
    } else {
        Write-Error "Missing: $file"
        exit 1
    }
}

# Validate Firebase configuration
Write-Step "Validating Firebase configuration..."

try {
    $firebaseConfig = Get-Content "firebase.json" | ConvertFrom-Json
    if ($firebaseConfig.hosting) {
        Write-Success "Firebase hosting configuration found"
        Write-Info "Public directory: $($firebaseConfig.hosting.public)"
    } else {
        Write-Error "No hosting configuration found in firebase.json"
        exit 1
    }
} catch {
    Write-Error "Invalid firebase.json file"
    exit 1
}

# Check Firebase login status
Write-Step "Checking Firebase authentication..."

try {
    firebase projects:list | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Not logged in to Firebase"
        Write-Info "Attempting to login..."
        firebase login
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Firebase login failed"
            exit 1
        }
    } else {
        Write-Success "Logged in to Firebase"
    }
} catch {
    Write-Error "Error checking Firebase authentication"
    exit 1
}

# Validate project configuration
Write-Step "Validating Firebase project configuration..."

try {
    $firebaserc = Get-Content ".firebaserc" | ConvertFrom-Json
    $projectId = $null
    
    if ($firebaserc.projects -and $firebaserc.projects.$Environment) {
        $projectId = $firebaserc.projects.$Environment
        Write-Success "Found $Environment project: $projectId"
    } elseif ($firebaserc.default) {
        $projectId = $firebaserc.default
        Write-Warning "Using default project: $projectId (no environment-specific project found)"
    } else {
        Write-Error "No Firebase project configured for environment: $Environment"
        Write-Info "Configure with: firebase use --add"
        exit 1
    }
    
    # Set the project
    firebase use $projectId
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to set Firebase project: $projectId"
        exit 1
    }
    
    Write-Success "Using Firebase project: $projectId"
} catch {
    Write-Error "Error reading .firebaserc file"
    exit 1
}

# Validate public directory
Write-Step "Validating public directory..."

$publicFiles = Get-ChildItem -Path "public" -File
Write-Info "Files in public directory:"
foreach ($file in $publicFiles) {
    Write-Host "  📄 $($file.Name)" -ForegroundColor Gray
}

# Check for potential security issues
Write-Step "Security validation..."

$securityPatterns = @(
    "api[_-]?key",
    "secret",
    "token",
    "password",
    "private[_-]?key"
)

$securityIssues = @()
foreach ($pattern in $securityPatterns) {
    $securityMatches = Select-String -Path "public/*.js", "public/*.html" -Pattern $pattern -ErrorAction SilentlyContinue
    if ($securityMatches) {
        $securityIssues += $securityMatches
    }
}

if ($securityIssues.Count -gt 0) {
    Write-Warning "Potential security issues found:"
    foreach ($issue in $securityIssues) {
        Write-Host "  🔍 $($issue.Filename):$($issue.LineNumber) - $($issue.Line.Trim())" -ForegroundColor Yellow
    }
    
    $continue = Read-Host "Continue with deployment? (y/N)"
    if ($continue -notmatch "^[Yy]") {
        Write-Info "Deployment cancelled by user"
        exit 0
    }
}

# Stop here if validation only
if ($ValidateOnly) {
    Write-Success "Validation completed successfully!"
    Write-Info "Ready for deployment to $Environment"
    exit 0
}

# Install dependencies if package.json exists
if (Test-Path "package.json") {
    Write-Step "Installing dependencies..."
    npm ci
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install dependencies"
        exit 1
    }
    Write-Success "Dependencies installed"
}

# Build step (if needed)
Write-Step "Preparing build..."
Write-Info "No build step required for this static app"

# Deploy or preview
if ($Preview) {
    Write-Step "Starting Firebase preview..."
    Write-Info "This will start a local preview of your app"
    
    firebase serve --project $projectId
} else {
    Write-Step "Deploying to Firebase Hosting..."
    Write-Info "Environment: $Environment"
    Write-Info "Project: $projectId"
    
    # Confirm deployment
    if ($Environment -eq "production") {
        Write-Warning "You are about to deploy to PRODUCTION!"
        $confirm = Read-Host "Are you sure? (yes/N)"
        if ($confirm -ne "yes") {
            Write-Info "Deployment cancelled"
            exit 0
        }
    }
    
    # Deploy
    firebase deploy --only hosting --project $projectId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Deployment completed successfully!"
        Write-Info "Environment: $Environment"
        Write-Info "Project: $projectId"
        
        # Get hosting URL
        Write-Info "Check Firebase Console for the live URL"
        Write-Info "Visit: https://console.firebase.google.com/project/$projectId/hosting"
        
        Write-Host ""
        Write-ColoredText "🎉 Deployment Summary" "Green"
        Write-ColoredText "=====================" "Green"
        Write-Host "✅ App deployed successfully"
        Write-Host "🌐 Environment: $Environment"
        Write-Host "📁 Project: $projectId"
        Write-Host "🔗 Firebase Console: https://console.firebase.google.com/project/$projectId/hosting"
        Write-Host ""
        
    } else {
        Write-Error "Deployment failed!"
        Write-Info "Check the error messages above"
        Write-Info "Common solutions:"
        Write-Info "  - Verify Firebase authentication: firebase login"
        Write-Info "  - Check project permissions in Firebase Console"
        Write-Info "  - Ensure firebase.json is configured correctly"
        exit 1
    }
}

Write-Host ""
Write-Success "Script completed!"
