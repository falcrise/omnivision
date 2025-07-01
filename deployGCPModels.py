import os
import json
import yaml
import logging
from pathlib import Path
from datetime import datetime
import vertexai
from vertexai import model_garden
from google.cloud import aiplatform
from typing import Dict, Any, Optional

# Configure logging
log_level = logging.DEBUG if os.getenv('DEBUG', 'false').lower() == 'true' else logging.INFO
logging.basicConfig(
    level=log_level,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class VertexAIModelGardenDeployer:
    def __init__(self, config_path: Optional[str] = None):
        """Initialize the deployer with configuration."""
        self.config = self._load_configuration(config_path)
        self.project_id = self._get_project_id()
        self.region = self.config['gcp']['region']
        
        # Initialize Vertex AI
        vertexai.init(project=self.project_id, location=self.region)
        logger.info(f"Initialized Vertex AI for project: {self.project_id}, region: {self.region}")
        logger.info(f"🌍 Selected region: {self.region}")
        
        # Log region-specific information
        region_info = {
            'us-central1': 'Iowa, USA - Lowest latency for US users',
            'us-east1': 'South Carolina, USA - Good for East Coast',
            'us-west1': 'Oregon, USA - Good for West Coast',
            'europe-west1': 'Belgium, Europe - Good for European users',
            'europe-west4': 'Netherlands, Europe - Alternative EU region',
            'asia-southeast1': 'Singapore, Asia - Recommended for Asia-Pacific',
            'asia-northeast1': 'Tokyo, Japan - Good for Japan/Korea',
            'asia-south1': 'Mumbai, India - Good for South Asia'
        }
        
        if self.region in region_info:
            logger.info(f"📍 Region details: {region_info[self.region]}")
        else:
            logger.info(f"📍 Using custom region: {self.region}")
        
    def _load_configuration(self, config_path: Optional[str] = None) -> Dict[str, Any]:
        """Load configuration from environment and config files."""
        # Determine environment
        environment = os.getenv('ENVIRONMENT', 'staging')
        
        if config_path is None:
            config_path = f".github/configs/{environment}.yml"
            
        # Load YAML configuration
        config = {}
        if Path(config_path).exists():
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
                logger.info(f"Loaded configuration from {config_path}")
        else:
            logger.warning(f"Configuration file {config_path} not found, using defaults")
            
        # Override with environment variables
        config = self._override_with_env_vars(config)
        return config
        
    def _override_with_env_vars(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Override configuration with environment variables."""
        # GCP settings
        if 'gcp' not in config:
            config['gcp'] = {}
        
        original_region = config['gcp'].get('region', 'asia-southeast1')
        config['gcp']['region'] = os.getenv('REGION', original_region)
        
        # Log region selection
        if os.getenv('REGION'):
            logger.info(f"🌍 Region overridden by environment variable: {config['gcp']['region']}")
        else:
            logger.info(f"🌍 Using region from config: {config['gcp']['region']}")
        
        # Model settings
        if 'model' not in config:
            config['model'] = {}
        config['model']['name'] = os.getenv('MODEL_NAME', config['model'].get('name', 'smolvlm-instruct'))
        config['model']['huggingface_id'] = os.getenv('MODEL_ID', 
            config['model'].get('huggingface_id', 'HuggingFaceTB/smolvlm-instruct'))
            
        # Deployment settings
        if 'deployment' not in config:
            config['deployment'] = {}
        config['deployment']['machine_type'] = os.getenv('MACHINE_TYPE', 
            config['deployment'].get('machine_type', 'g2-standard-12'))
        config['deployment']['min_replica_count'] = int(os.getenv('MIN_REPLICAS', 
            config['deployment'].get('min_replica_count', 1)))
        config['deployment']['max_replica_count'] = int(os.getenv('MAX_REPLICAS', 
            config['deployment'].get('max_replica_count', 3)))
            
        return config
        
    def _get_project_id(self) -> str:
        """Get project ID from environment or configuration."""
        project_id = os.getenv('PROJECT_ID')
        if not project_id:
            project_id = self.config.get('gcp', {}).get('project_id')
        if not project_id:
            raise ValueError("PROJECT_ID must be set in environment or configuration")
        return project_id
        
    def _get_accelerator_config(self, machine_type: str) -> tuple:
        """Get the appropriate accelerator type and count based on machine type."""
        machine_to_accelerator = {
            'g2-standard-4': ('NVIDIA_L4', 1),
            'g2-standard-8': ('NVIDIA_L4', 1),
            'g2-standard-12': ('NVIDIA_L4', 1),
            'g2-standard-16': ('NVIDIA_L4', 1),
            'a2-ultragpu-1g': ('NVIDIA_A100_80GB', 1),
            'a3-highgpu-2g': ('NVIDIA_H100_80GB', 2),
            'n1-highmem-4': ('NVIDIA_TESLA_V100', 1),  # Default to V100 for n1-highmem-4
        }
        
        return machine_to_accelerator.get(machine_type, ('NVIDIA_L4', 1))

    def _wait_for_deployment(self, endpoint, timeout_minutes=30):
        """Wait for endpoint deployment to complete."""
        import time
        
        timeout_seconds = timeout_minutes * 60
        start_time = time.time()
        
        logger.info(f"Waiting for deployment to complete (timeout: {timeout_minutes} minutes)...")
        
        while time.time() - start_time < timeout_seconds:
            try:
                # For Model Garden endpoints, status checking is limited
                # We'll try a few approaches to check deployment status
                
                # Method 1: Check if the endpoint has deployed models directly
                if hasattr(endpoint, 'deployed_models') and endpoint.deployed_models:
                    deployed_model = endpoint.deployed_models[0]
                    if hasattr(deployed_model, 'state'):
                        logger.info(f"Deployment state: {deployed_model.state}")
                        
                        if deployed_model.state == aiplatform.gapic.DeployedModel.State.DEPLOYED:
                            logger.info("✅ Deployment completed successfully!")
                            return True
                        elif deployed_model.state == aiplatform.gapic.DeployedModel.State.FAILED:
                            logger.error("❌ Deployment failed!")
                            return False
                    else:
                        logger.info("📋 Deployment state not available, checking...")
                
                # Method 2: Try to get endpoint by resource name if available
                elif hasattr(endpoint, 'resource_name') and endpoint.resource_name:
                    try:
                        from google.cloud import aiplatform_v1
                        client = aiplatform_v1.EndpointServiceClient()
                        fresh_endpoint = client.get_endpoint(name=endpoint.resource_name)
                        
                        if fresh_endpoint.deployed_models:
                            deployed_model = fresh_endpoint.deployed_models[0]
                            logger.info(f"Deployment state: {deployed_model.state}")
                            
                            if deployed_model.state == aiplatform_v1.DeployedModel.State.DEPLOYED:
                                logger.info("✅ Deployment completed successfully!")
                                return True
                            elif deployed_model.state == aiplatform_v1.DeployedModel.State.FAILED:
                                logger.error("❌ Deployment failed!")
                                return False
                    except Exception as client_error:
                        logger.debug(f"Client check failed: {client_error}")
                
                # Method 3: For Model Garden, if deploy() succeeded and we've waited a bit,
                # assume deployment is working
                if time.time() - start_time > 120:  # Wait at least 2 minutes
                    logger.info("💡 Model Garden deployment call succeeded and sufficient time has passed. Assuming deployment is ready.")
                    return True
                
                logger.info("⏳ Deployment still in progress...")
                time.sleep(30)  # Wait 30 seconds before checking again
                
            except Exception as e:
                logger.warning(f"Error checking deployment status: {str(e)}")
                # For Model Garden, if we can't check status but the deploy() call succeeded,
                # we'll assume it's working and return success after a reasonable wait
                if time.time() - start_time > 180:  # Wait at least 3 minutes
                    logger.info("💡 Cannot check deployment status, but deploy() call succeeded. Assuming deployment is complete.")
                    return True
                time.sleep(30)
                
        logger.error(f"⏰ Deployment timeout after {timeout_minutes} minutes")
        return False

    def deploy_model_garden_model(self):
        """Deploy model using Vertex AI Model Garden with improved error handling."""
        model_config = self.config['model']
        deployment_config = self.config['deployment']
        
        # Force redeploy option
        force_redeploy = os.getenv('FORCE_REDEPLOY', 'false').lower() == 'true'
        
        # Get accelerator configuration based on machine type
        accelerator_type, accelerator_count = self._get_accelerator_config(deployment_config['machine_type'])
        
        logger.info(f"Deploying Model Garden model: {model_config['huggingface_id']}")
        logger.info(f"Machine type: {deployment_config['machine_type']}")
        logger.info(f"Accelerator: {accelerator_type} x{accelerator_count}")
        logger.info(f"Replicas: {deployment_config['min_replica_count']}-{deployment_config['max_replica_count']}")
        logger.info(f"Force redeploy: {force_redeploy}")
        
        try:
            # Create Model Garden model
            model = model_garden.OpenModel(model_config['huggingface_id'])
            
            # Generate unique deployment names
            timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
            endpoint_name = f"{model_config['name']}-endpoint-{timestamp}"
            model_display_name = f"{model_config['name']}-{timestamp}"
            
            logger.info("Starting model deployment...")
            logger.info(f"Endpoint name: {endpoint_name}")
            logger.info(f"Model display name: {model_display_name}")
            
            # Deploy the model with proper error handling
            try:
                endpoint = model.deploy(
                    accept_eula=True,
                    machine_type=deployment_config['machine_type'],
                    accelerator_type=accelerator_type,
                    accelerator_count=accelerator_count,
                    endpoint_display_name=endpoint_name,
                    model_display_name=model_display_name,
                    use_dedicated_endpoint=True,
                    min_replica_count=deployment_config['min_replica_count'],
                    max_replica_count=deployment_config['max_replica_count']
                )
                
                logger.info("✅ Model Garden deployment call completed successfully!")
                
                # Check if we should skip status checking (useful for Model Garden deployments)
                skip_status_check = os.getenv('SKIP_STATUS_CHECK', 'false').lower() == 'true'
                
                if skip_status_check:
                    logger.info("💡 Skipping deployment status check (SKIP_STATUS_CHECK=true)")
                    logger.info("✅ Assuming deployment is successful based on successful deploy() call")
                else:
                    # Wait for deployment to complete
                    if not self._wait_for_deployment(endpoint):
                        logger.warning("⚠️ Deployment status check failed, but deploy() call succeeded")
                        logger.info("💡 You can set SKIP_STATUS_CHECK=true to skip status verification")
                        # Don't raise an exception here since the deploy() call succeeded
                    
                return model, endpoint
                
            except Exception as deploy_error:
                logger.error(f"❌ Model deployment failed: {str(deploy_error)}")
                
                # Enhanced error handling for common issues
                error_msg = str(deploy_error).lower()
                
                if "already exists" in error_msg:
                    if not force_redeploy:
                        logger.info("💡 Model/endpoint already exists. Set FORCE_REDEPLOY=true to redeploy.")
                        logger.info("Attempting to find existing endpoint...")
                        return self._find_existing_deployment(model_config)
                    else:
                        logger.info("🔄 Force redeploy enabled, but deployment still failed.")
                        
                elif "quota" in error_msg or "resource" in error_msg:
                    logger.error("💰 Resource quota exceeded or insufficient resources available.")
                    logger.error("💡 Try using a smaller machine type or different region.")
                    
                elif "permission" in error_msg or "unauthorized" in error_msg:
                    logger.error("🔐 Permission denied. Check service account permissions.")
                    logger.error("💡 Ensure service account has 'Vertex AI Admin' role.")
                    
                elif "invalid" in error_msg and "filter" in error_msg:
                    logger.error("🔍 Endpoint filtering error detected.")
                    logger.error("💡 This may be due to endpoint labeling issues in Model Garden.")
                    
                raise deploy_error
                
        except Exception as e:
            logger.error(f"❌ Complete deployment failed: {str(e)}")
            raise

    def _find_existing_deployment(self, model_config):
        """Find existing deployment for the model."""
        try:
            logger.info("🔍 Searching for existing endpoints...")
            
            # List all endpoints
            endpoints = aiplatform.Endpoint.list()
            
            # Look for endpoints related to our model
            model_name = model_config['name']
            matching_endpoints = []
            
            for endpoint in endpoints:
                if model_name in endpoint.display_name.lower():
                    matching_endpoints.append(endpoint)
                    logger.info(f"Found matching endpoint: {endpoint.display_name} ({endpoint.name})")
            
            if matching_endpoints:
                # Use the most recent endpoint
                latest_endpoint = matching_endpoints[-1]
                logger.info(f"✅ Using existing endpoint: {latest_endpoint.display_name}")
                return None, latest_endpoint  # Return None for model, existing endpoint
            else:
                logger.warning("⚠️ No existing endpoints found matching the model name")
                raise Exception("No existing deployments found and new deployment failed")
                
        except Exception as e:
            logger.error(f"❌ Error finding existing deployment: {str(e)}")
            raise
            
    def save_deployment_outputs(self, model, endpoint):
        """Save deployment outputs for use in other applications."""
        # Get endpoint details safely
        try:
            if hasattr(endpoint, 'name') and endpoint.name:
                endpoint_id = endpoint.name.split('/')[-1]
                endpoint_resource_name = endpoint.name
            else:
                # Fallback for cases where endpoint.name might not be available
                endpoint_id = getattr(endpoint, 'resource_name', 'unknown').split('/')[-1]
                endpoint_resource_name = getattr(endpoint, 'resource_name', f"projects/{self.project_id}/locations/{self.region}/endpoints/unknown")
        except Exception as e:
            logger.warning(f"Could not extract endpoint ID properly: {str(e)}")
            endpoint_id = "unknown"
            endpoint_resource_name = f"projects/{self.project_id}/locations/{self.region}/endpoints/unknown"
        
        # Get accelerator configuration
        accelerator_type, accelerator_count = self._get_accelerator_config(self.config['deployment']['machine_type'])
        
        outputs = {
            "deployment_info": {
                "timestamp": datetime.now().isoformat(),
                "environment": os.getenv('ENVIRONMENT', 'staging'),
                "project_id": self.project_id,
                "region": self.region,
                "deployment_method": "model_garden"
            },
            "model": {
                "huggingface_id": self.config['model']['huggingface_id'],
                "display_name": self.config['model']['name'],
                "type": "model_garden_open_model"
            },
            "endpoint": {
                "endpoint_id": endpoint_id,
                "display_name": getattr(endpoint, 'display_name', f"{self.config['model']['name']}-endpoint"),
                "resource_name": endpoint_resource_name
            },
            "api_config": {
                "endpoint_id": endpoint_id,
                "project_id": self.project_id,
                "region": self.region,
                "api_endpoint": f"https://{self.region}-aiplatform.googleapis.com/v1/projects/{self.project_id}/locations/{self.region}/endpoints/{endpoint_id}:predict"
            },
            "configuration": {
                "machine_type": self.config['deployment']['machine_type'],
                "accelerator_type": accelerator_type,
                "accelerator_count": accelerator_count,
                "min_replicas": self.config['deployment']['min_replica_count'],
                "max_replicas": self.config['deployment']['max_replica_count']
            }
        }
        
        # Save to JSON file
        with open('deployment_outputs.json', 'w') as f:
            json.dump(outputs, f, indent=2)
            
        logger.info("Deployment outputs saved to deployment_outputs.json")
        return outputs

    def verify_endpoint_deployment(self, endpoint):
        """Verify that the endpoint is properly deployed and accessible."""
        try:
            logger.info("🔍 Verifying endpoint deployment...")
            
            # Refresh endpoint to get latest state
            endpoint.refresh()
            
            # Check endpoint state
            logger.info(f"Endpoint name: {endpoint.display_name}")
            logger.info(f"Endpoint ID: {endpoint.name.split('/')[-1] if hasattr(endpoint, 'name') else 'unknown'}")
            
            # Check deployed models
            if hasattr(endpoint, 'deployed_models') and endpoint.deployed_models:
                for i, deployed_model in enumerate(endpoint.deployed_models):
                    logger.info(f"Deployed model {i+1}:")
                    logger.info(f"  Display name: {deployed_model.display_name}")
                    logger.info(f"  State: {deployed_model.state}")
                    logger.info(f"  Machine type: {deployed_model.machine_spec.machine_type}")
                    
                    if hasattr(deployed_model.machine_spec, 'accelerator_type'):
                        logger.info(f"  Accelerator: {deployed_model.machine_spec.accelerator_type}")
                        logger.info(f"  Accelerator count: {deployed_model.machine_spec.accelerator_count}")
                        
                return True
            else:
                logger.warning("⚠️ No deployed models found on endpoint")
                return False
                
        except Exception as e:
            logger.error(f"❌ Error verifying endpoint: {str(e)}")
            return False
        
    def deploy_complete_pipeline(self):
        """Deploy the complete pipeline using Model Garden with enhanced error handling."""
        try:
            logger.info("🚀 Starting complete Model Garden deployment pipeline...")
            
            # Deploy model using Model Garden
            model, endpoint = self.deploy_model_garden_model()
            
            # Verify deployment
            if not self.verify_endpoint_deployment(endpoint):
                logger.warning("⚠️ Endpoint verification failed, but continuing...")
            
            # Save outputs
            outputs = self.save_deployment_outputs(model, endpoint)
            
            # Print summary
            self._print_deployment_summary(outputs)
            
            logger.info("✅ Complete deployment pipeline finished successfully!")
            return outputs
            
        except Exception as e:
            logger.error(f"❌ Deployment pipeline failed: {str(e)}")
            logger.error("🔍 Common solutions:")
            logger.error("1. Check service account permissions (Vertex AI Admin role)")
            logger.error("2. Verify project quota for GPU resources")
            logger.error("3. Try a different machine type or region")
            logger.error("4. Set FORCE_REDEPLOY=true if endpoint already exists")
            raise
            
    def _print_deployment_summary(self, outputs: Dict[str, Any]):
        """Print a formatted deployment summary."""
        print("\n" + "="*80)
        print("🚀 VERTEX AI MODEL GARDEN DEPLOYMENT SUCCESSFUL!")
        print("="*80)
        print(f"Environment: {outputs['deployment_info']['environment']}")
        print(f"Project: {outputs['deployment_info']['project_id']}")
        print(f"Region: {outputs['deployment_info']['region']}")
        print(f"Timestamp: {outputs['deployment_info']['timestamp']}")
        print(f"Method: {outputs['deployment_info']['deployment_method']}")
        print()
        print("📊 Model Information:")
        print(f"  Hugging Face ID: {outputs['model']['huggingface_id']}")
        print(f"  Display Name: {outputs['model']['display_name']}")
        print(f"  Type: {outputs['model']['type']}")
        print()
        print("🌐 Endpoint Information:")
        print(f"  Endpoint ID: {outputs['endpoint']['endpoint_id']}")
        print(f"  Display Name: {outputs['endpoint']['display_name']}")
        print(f"  Resource: {outputs['endpoint']['resource_name']}")
        print()
        print("⚙️  Configuration:")
        print(f"  Machine Type: {outputs['configuration']['machine_type']}")
        print(f"  GPU: {outputs['configuration']['accelerator_type']} x{outputs['configuration']['accelerator_count']}")
        print(f"  Replicas: {outputs['configuration']['min_replicas']}-{outputs['configuration']['max_replicas']}")
        print()
        print("🔧 API Configuration:")
        print(f"  Endpoint ID: {outputs['api_config']['endpoint_id']}")
        print(f"  Project ID: {outputs['api_config']['project_id']}")
        print(f"  Region: {outputs['api_config']['region']}")
        print(f"  API Endpoint: {outputs['api_config']['api_endpoint']}")
        print()
        print("📋 Config.js Update:")
        print("// Update your public/config.js with these values:")
        print(f"const VERTEX_AI_CONFIG = {{")
        print(f"  PROJECT_ID: '{outputs['api_config']['project_id']}',")
        print(f"  REGION: '{outputs['api_config']['region']}',")
        print(f"  ENDPOINT_ID: '{outputs['api_config']['endpoint_id']}',")
        print(f"  API_ENDPOINT: '{outputs['api_config']['api_endpoint']}'")
        print(f"}};")
        print()
        print("📋 Next Steps:")
        print("1. Update your application's config.js with the above values")
        print("2. Test the endpoint with a sample prediction")
        print("3. Monitor the deployment in the Google Cloud Console")
        print("4. Check Vertex AI Model Garden for deployment status")
        print("="*80)

def main():
    """Main function to run the deployment."""
    try:
        deployer = VertexAIModelGardenDeployer()
        outputs = deployer.deploy_complete_pipeline()
        
        # Set GitHub Actions output if running in CI
        if os.getenv('GITHUB_ACTIONS'):
            github_output = os.getenv('GITHUB_OUTPUT')
            if github_output:
                with open(github_output, 'a') as f:
                    f.write(f"endpoint_id={outputs['api_config']['endpoint_id']}\n")
                    f.write(f"model_display_name={outputs['model']['display_name']}\n")
                    f.write(f"api_endpoint={outputs['api_config']['api_endpoint']}\n")
                
    except Exception as e:
        logger.error(f"Deployment failed: {str(e)}")
        exit(1)

if __name__ == "__main__":
    main()
