#!/usr/bin/env python3
"""
Quick Model Garden Deployment Script
Simplified version that matches Google's exact sample format for immediate deployment.
"""

import os
import sys
import vertexai
from vertexai import model_garden
from datetime import datetime

def quick_deploy():
    """Deploy SmolVLM using exact Google sample format."""
    
    # Required environment variables
    project_id = os.getenv('PROJECT_ID')
    region = os.getenv('REGION', 'us-central1')
    
    if not project_id:
        print("❌ Error: PROJECT_ID environment variable not set")
        print("Usage: set PROJECT_ID=your-project-id && python quick_deploy.py")
        return False
    
    print(f"🚀 Quick deploying SmolVLM to {project_id} in {region}")
    print("📋 Using Google's exact sample format...")
    
    try:
        # Initialize Vertex AI
        vertexai.init(project=project_id, location=region)
        print(f"✅ Initialized Vertex AI")
        
        # Create model
        model = model_garden.OpenModel("HuggingFaceTB/smolvlm-instruct")
        print(f"✅ Created Model Garden model")
        
        # Generate timestamp for unique names
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        
        # Deploy with exact Google sample parameters
        print(f"🚀 Deploying model...")
        endpoint = model.deploy(
            accept_eula=True,
            machine_type="g2-standard-12",
            accelerator_type="NVIDIA_L4",
            accelerator_count=1,
            endpoint_display_name=f"smolvlm-instruct-mg-one-click-deploy-{timestamp}",
            model_display_name=f"smolvlm-instruct-{timestamp}",
            use_dedicated_endpoint=True,
        )
        
        print(f"✅ Deployment initiated successfully!")
        print(f"📋 Endpoint: {endpoint}")
        
        # Extract endpoint details
        if hasattr(endpoint, 'name'):
            endpoint_id = endpoint.name.split('/')[-1]
            print(f"📋 Endpoint ID: {endpoint_id}")
            print(f"📋 Region: {region}")
            print(f"📋 Project: {project_id}")
            
            # Create the dedicated endpoint domain
            # We need to get the project number for this
            dedicated_domain = f"{endpoint_id}.{region}-<PROJECT_NUMBER>.prediction.vertexai.goog"
            print(f"📋 Dedicated Domain Format: {dedicated_domain}")
            print(f"💡 Replace <PROJECT_NUMBER> with your actual project number")
        
        print(f"✅ Quick deployment completed!")
        return True
        
    except Exception as e:
        print(f"❌ Deployment failed: {str(e)}")
        return False

if __name__ == "__main__":
    success = quick_deploy()
    if not success:
        sys.exit(1)
