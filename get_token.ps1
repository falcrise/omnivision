# Get fresh access token for Vertex AI web app
Write-Host "=== Getting Fresh Access Token for Vertex AI Web App ===" -ForegroundColor Green
Write-Host ""

# Ensure we're using the correct project
$currentProject = gcloud config get-value project 2>$null
if ($currentProject -ne "falcon-deeptech-ai-stuff") {
    Write-Host "Setting correct project..." -ForegroundColor Yellow
    gcloud config set project falcon-deeptech-ai-stuff
}

Write-Host "Getting fresh access token..." -ForegroundColor Yellow
try {
    $token = gcloud auth application-default print-access-token
    if ($token) {
        Write-Host ""
        Write-Host "✓ Fresh access token generated successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Copy this token and paste it into the web app:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host $token -ForegroundColor White
        Write-Host ""
        Write-Host "This token is valid for about 1 hour." -ForegroundColor Yellow
        Write-Host ""
        
        # Also copy to clipboard if possible
        try {
            $token | Set-Clipboard
            Write-Host "✓ Token has been copied to your clipboard!" -ForegroundColor Green
        } catch {
            Write-Host "Note: Could not copy to clipboard automatically." -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "=== How to use ===" -ForegroundColor Cyan
        Write-Host "1. Open your web app (run 'firebase serve' or 'npm start')"
        Write-Host "2. Paste the token into the 'Access Token' field"
        Write-Host "3. Set your alert condition (e.g., 'person in frame')"
        Write-Host "4. Click 'Start Analysis'"
        Write-Host ""
        
    } else {
        Write-Host "✗ Failed to get access token" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Error getting access token: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try running: gcloud auth application-default login --project=falcon-deeptech-ai-stuff" -ForegroundColor Yellow
}
