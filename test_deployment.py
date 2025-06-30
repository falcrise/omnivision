#!/usr/bin/env python3
"""
Test script for Vertex AI Model Garden deployment
This script validates configuration and tests the deployment setup without actually deploying
"""

import os
import sys
from deployGCPModels import VertexAIModelGardenDeployer

def test_configuration():
    """Test the deployment configuration"""
    print("🧪 Testing Vertex AI Model Garden Deployment Configuration")
    print("="*60)
    
    # Set test environment variables
    os.environ['PROJECT_ID'] = os.getenv('PROJECT_ID', 'falcon-deeptech-ai-stuff')
    os.environ['ENVIRONMENT'] = 'staging'
    os.environ['DEBUG'] = 'true'
    
    try:
        # Initialize deployer
        deployer = VertexAIModelGardenDeployer()
        
        # Test configuration loading
        print(f"✅ Configuration loaded successfully")
        print(f"   Project ID: {deployer.project_id}")
        print(f"   Region: {deployer.region}")
        print(f"   Model: {deployer.config['model']['huggingface_id']}")
        print(f"   Machine Type: {deployer.config['deployment']['machine_type']}")
        
        # Test accelerator configuration
        machine_type = deployer.config['deployment']['machine_type']
        accelerator_type, accelerator_count = deployer._get_accelerator_config(machine_type)
        print(f"   Accelerator: {accelerator_type} x{accelerator_count}")
        
        print("\n🔧 Testing different machine types:")
        machine_types = ['g2-standard-12', 'a2-ultragpu-1g', 'a3-highgpu-2g', 'n1-highmem-4']
        for mt in machine_types:
            acc_type, acc_count = deployer._get_accelerator_config(mt)
            print(f"   {mt}: {acc_type} x{acc_count}")
            
        print("\n✅ All configuration tests passed!")
        return True
        
    except Exception as e:
        print(f"❌ Configuration test failed: {str(e)}")
        return False

def test_environment_setup():
    """Test if the environment is properly set up"""
    print("\n🌍 Testing Environment Setup")
    print("="*30)
    
    required_vars = ['PROJECT_ID']
    optional_vars = ['REGION', 'MODEL_NAME', 'MACHINE_TYPE', 'ENVIRONMENT']
    
    print("Required environment variables:")
    for var in required_vars:
        value = os.getenv(var)
        if value:
            print(f"   ✅ {var}: {value}")
        else:
            print(f"   ❌ {var}: Not set")
            
    print("\nOptional environment variables:")
    for var in optional_vars:
        value = os.getenv(var)
        status = "✅" if value else "⚪"
        print(f"   {status} {var}: {value or 'Using default'}")

if __name__ == "__main__":
    print("🚀 Vertex AI Model Garden Deployment Test Suite")
    print("="*60)
    
    # Test environment setup
    test_environment_setup()
    
    # Test configuration
    if test_configuration():
        print("\n🎉 All tests passed! Ready for deployment.")
        print("\n📋 To run actual deployment:")
        print("   python deployGCPModels.py")
        print("\n💡 Deployment options:")
        print("   DEBUG=true python deployGCPModels.py          # Enable debug logging")
        print("   FORCE_REDEPLOY=true python deployGCPModels.py # Force redeploy existing")
        print("   MACHINE_TYPE=a2-ultragpu-1g python deployGCPModels.py # Use A100 GPU")
    else:
        print("\n❌ Tests failed. Please fix configuration issues before deployment.")
        sys.exit(1)
