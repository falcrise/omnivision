import os
import json
import yaml
import logging
from pathlib import Path
from datetime import datetime
import vertexai
from vertexai import model_garden
from typing import Dict, Any, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
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
        config['gcp']['region'] = os.getenv('REGION', config['gcp'].get('region', 'asia-southeast1'))
        
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
        
    def deploy_model_garden_model(self):
        """Deploy model using Vertex AI Model Garden."""
        model_config = self.config['model']
        deployment_config = self.config['deployment']
        
        # Force redeploy option
        force_redeploy = os.getenv('FORCE_REDEPLOY', 'false').lower() == 'true'
        
        logger.info(f"Deploying Model Garden model: {model_config['huggingface_id']}")
        logger.info(f"Machine type: {deployment_config['machine_type']}")
        logger.info(f"Replicas: {deployment_config['min_replica_count']}-{deployment_config['max_replica_count']}")
        logger.info(f"Force redeploy: {force_redeploy}")
        
        try:
            # Create Model Garden model
            model = model_garden.OpenModel(model_config['huggingface_id'])
            
            # Generate unique deployment names
            timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
            endpoint_name = f"{model_config['name']}-endpoint-{timestamp}"
            model_display_name = f"{model_config['name']}-{timestamp}"
            
            # Deploy the model
            logger.info("Starting model deployment...")
            endpoint = model.deploy(
                accept_eula=True,
                machine_type=deployment_config['machine_type'],
                accelerator_type=deployment_config.get('accelerator_type', 'NVIDIA_L4'),
                accelerator_count=deployment_config.get('accelerator_count', 1),
                endpoint_display_name=endpoint_name,
                model_display_name=model_display_name,
                use_dedicated_endpoint=True,
                min_replica_count=deployment_config['min_replica_count'],
                max_replica_count=deployment_config['max_replica_count']
            )
            
            logger.info("Model deployed successfully!")
            return model, endpoint
            
        except Exception as e:
            logger.error(f"Model deployment failed: {str(e)}")
            
            # Check if it's because the model already exists
            if "already exists" in str(e).lower() and not force_redeploy:
                logger.info("Model appears to already exist. Set FORCE_REDEPLOY=true to redeploy.")
                
            raise
            
    def save_deployment_outputs(self, model, endpoint):
        """Save deployment outputs for use in other applications."""
        # Get endpoint details
        endpoint_id = endpoint.name.split('/')[-1] if hasattr(endpoint, 'name') else str(endpoint)
        
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
                "resource_name": getattr(endpoint, 'resource_name', f"projects/{self.project_id}/locations/{self.region}/endpoints/{endpoint_id}")
            },
            "api_config": {
                "endpoint_id": endpoint_id,
                "project_id": self.project_id,
                "region": self.region,
                "api_endpoint": f"https://{self.region}-aiplatform.googleapis.com/v1/projects/{self.project_id}/locations/{self.region}/endpoints/{endpoint_id}:predict"
            },
            "configuration": {
                "machine_type": self.config['deployment']['machine_type'],
                "accelerator_type": self.config['deployment'].get('accelerator_type', 'NVIDIA_L4'),
                "accelerator_count": self.config['deployment'].get('accelerator_count', 1),
                "min_replicas": self.config['deployment']['min_replica_count'],
                "max_replicas": self.config['deployment']['max_replica_count']
            }
        }
        
        # Save to JSON file
        with open('deployment_outputs.json', 'w') as f:
            json.dump(outputs, f, indent=2)
            
        logger.info("Deployment outputs saved to deployment_outputs.json")
        return outputs
        
    def deploy_complete_pipeline(self):
        """Deploy the complete pipeline using Model Garden."""
        try:
            # Deploy model using Model Garden
            model, endpoint = self.deploy_model_garden_model()
            
            # Save outputs
            outputs = self.save_deployment_outputs(model, endpoint)
            
            # Print summary
            self._print_deployment_summary(outputs)
            
            return outputs
            
        except Exception as e:
            logger.error(f"Deployment failed: {str(e)}")
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
