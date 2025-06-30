import os
import json
import yaml
import logging
from pathlib import Path
from datetime import datetime
from google.cloud import aiplatform
from typing import Dict, Any, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class VertexAIDeployer:
    def __init__(self, config_path: Optional[str] = None):
        """Initialize the deployer with configuration."""
        self.config = self._load_configuration(config_path)
        self.project_id = self._get_project_id()
        self.region = self.config['gcp']['region']
        
        # Initialize AI Platform
        aiplatform.init(project=self.project_id, location=self.region)
        logger.info(f"Initialized AI Platform for project: {self.project_id}, region: {self.region}")
        
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
            config['model'].get('huggingface_id', 'HuggingFaceTB/SmolVLM-Instruct'))
            
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
        
    def upload_model(self) -> aiplatform.Model:
        """Upload the model to Vertex AI."""
        model_config = self.config['model']
        container_config = self.config['container']
        
        logger.info(f"Uploading model: {model_config['huggingface_id']}")
        
        model = aiplatform.Model.upload(
            display_name=model_config['display_name'],
            serving_container_image_uri=container_config['uri'],
            serving_container_environment_variables={
                "MODEL_ID": model_config['huggingface_id'],
                **container_config['environment_variables']
            },
        )
        
        logger.info(f"Model uploaded successfully: {model.resource_name}")
        return model
        
    def create_endpoint(self) -> aiplatform.Endpoint:
        """Create an endpoint for the model."""
        deployment_config = self.config['deployment']
        
        logger.info(f"Creating endpoint: {deployment_config['endpoint_name']}")
        
        endpoint = aiplatform.Endpoint.create(
            display_name=deployment_config['endpoint_name']
        )
        
        logger.info(f"Endpoint created successfully: {endpoint.resource_name}")
        return endpoint
        
    def deploy_model(self, model: aiplatform.Model, endpoint: aiplatform.Endpoint) -> aiplatform.Endpoint:
        """Deploy the model to the endpoint."""
        deployment_config = self.config['deployment']
        
        logger.info("Deploying model to endpoint...")
        
        deployed = model.deploy(
            endpoint=endpoint,
            deployed_model_display_name=f"{self.config['model']['name']}-deployment",
            machine_type=deployment_config['machine_type'],
            accelerator_type=deployment_config['accelerator_type'],
            accelerator_count=deployment_config['accelerator_count'],
            min_replica_count=deployment_config['min_replica_count'],
            max_replica_count=deployment_config['max_replica_count'],
        )
        
        logger.info("Model deployed successfully!")
        return deployed
        
    def save_deployment_outputs(self, model: aiplatform.Model, endpoint: aiplatform.Endpoint):
        """Save deployment outputs for use in other applications."""
        outputs = {
            "deployment_info": {
                "timestamp": datetime.now().isoformat(),
                "environment": os.getenv('ENVIRONMENT', 'staging'),
                "project_id": self.project_id,
                "region": self.region
            },
            "model": {
                "resource_name": model.resource_name,
                "model_id": model.name.split('/')[-1],
                "display_name": model.display_name
            },
            "endpoint": {
                "resource_name": endpoint.resource_name,
                "endpoint_id": endpoint.name.split('/')[-1],
                "display_name": endpoint.display_name
            },
            "api_config": {
                "endpoint_id": endpoint.name.split('/')[-1],
                "project_id": self.project_id,
                "region": self.region,
                "dedicated_endpoint_domain": f"{endpoint.name.split('/')[-1]}.{self.region}-{self.project_id}.prediction.vertexai.goog",
                "api_endpoint": f"https://{endpoint.name.split('/')[-1]}.{self.region}-{self.project_id}.prediction.vertexai.goog/v1/projects/{self.project_id}/locations/{self.region}/endpoints/{endpoint.name.split('/')[-1]}:predict"
            }
        }
        
        # Save to JSON file
        with open('deployment_outputs.json', 'w') as f:
            json.dump(outputs, f, indent=2)
            
        logger.info("Deployment outputs saved to deployment_outputs.json")
        return outputs
        
    def deploy_complete_pipeline(self):
        """Deploy the complete pipeline: model upload, endpoint creation, and deployment."""
        try:
            # Upload model
            model = self.upload_model()
            
            # Create endpoint
            endpoint = self.create_endpoint()
            
            # Deploy model to endpoint
            self.deploy_model(model, endpoint)
            
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
        print("🚀 VERTEX AI MODEL DEPLOYMENT SUCCESSFUL!")
        print("="*80)
        print(f"Environment: {outputs['deployment_info']['environment']}")
        print(f"Project: {outputs['deployment_info']['project_id']}")
        print(f"Region: {outputs['deployment_info']['region']}")
        print(f"Timestamp: {outputs['deployment_info']['timestamp']}")
        print()
        print("📊 Model Information:")
        print(f"  Display Name: {outputs['model']['display_name']}")
        print(f"  Model ID: {outputs['model']['model_id']}")
        print(f"  Resource: {outputs['model']['resource_name']}")
        print()
        print("🌐 Endpoint Information:")
        print(f"  Display Name: {outputs['endpoint']['display_name']}")
        print(f"  Endpoint ID: {outputs['endpoint']['endpoint_id']}")
        print(f"  Resource: {outputs['endpoint']['resource_name']}")
        print()
        print("🔧 API Configuration:")
        print(f"  Endpoint ID: {outputs['api_config']['endpoint_id']}")
        print(f"  Project ID: {outputs['api_config']['project_id']}")
        print(f"  Region: {outputs['api_config']['region']}")
        print(f"  API Endpoint: {outputs['api_config']['api_endpoint']}")
        print()
        print("📋 Next Steps:")
        print("1. Update your application's config.js with the above values")
        print("2. Test the endpoint with a sample prediction")
        print("3. Monitor the deployment in the Google Cloud Console")
        print("="*80)

def main():
    """Main function to run the deployment."""
    try:
        deployer = VertexAIDeployer()
        outputs = deployer.deploy_complete_pipeline()
        
        # Set GitHub Actions output if running in CI
        if os.getenv('GITHUB_ACTIONS'):
            github_output = os.getenv('GITHUB_OUTPUT')
            if github_output:
                with open(github_output, 'a') as f:
                    f.write(f"endpoint_id={outputs['api_config']['endpoint_id']}\n")
                    f.write(f"model_id={outputs['model']['model_id']}\n")
                    f.write(f"api_endpoint={outputs['api_config']['api_endpoint']}\n")
                
    except Exception as e:
        logger.error(f"Deployment failed: {str(e)}")
        exit(1)

if __name__ == "__main__":
    main()
