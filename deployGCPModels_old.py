from google.cloud import aiplatform

# 1. Initialize client
PROJECT_ID = "your-firebase-project-id"
REGION     = "asia-southeast1"
aiplatform.init(project=PROJECT_ID, location=REGION)

# 2. Register the Hugging Face model
MODEL_ID = "HuggingFaceTB/SmolVLM-Instruct"  # SmolVLM-Instruct (2B) for vision-language tasks
CONTAINER_URI = "us-docker.pkg.dev/vertex-ai/prediction/pytorch-gpu.2-1.py310"  # PyTorch container for vision models

model = aiplatform.Model.upload(
    display_name=f"smolvlm-instruct-2b",
    serving_container_image_uri=CONTAINER_URI,
    serving_container_environment_variables={
        "MODEL_ID": MODEL_ID,
        "TASK": "image-text-to-text",
        "AIP_HEALTH_ROUTE": "/health",
        "AIP_PREDICT_ROUTE": "/predict",
        "AIP_HTTP_PORT": "8080"
    },
)

# 3. Create an endpoint
endpoint = aiplatform.Endpoint.create(
    display_name=f"smolvlm-instruct-endpoint"
)  

# 4. Deploy the model
deployed = model.deploy(
    endpoint=endpoint,
    deployed_model_display_name=f"smolvlm-instruct-deployment",
    machine_type="g2-standard-12",           # 12 vCPU | 48 GiB RAM
    accelerator_type="NVIDIA_L4",            # attaches 1× NVIDIA L4 GPU
    accelerator_count=1,
    min_replica_count=1,
    max_replica_count=3,
)

print(f"Model deployed to endpoint: {endpoint.resource_name}")
print(f"\n=== Deployment Summary ===")
print(f"Model: SmolVLM-Instruct (2B)")
print(f"Project: {PROJECT_ID}")
print(f"Region: {REGION}")
print(f"Machine Type: g2-standard-12 (12 vCPU, 48 GiB RAM)")
print(f"GPU: NVIDIA L4")
print(f"Endpoint ID: {endpoint.name.split('/')[-1]}")
print(f"Endpoint Resource Name: {endpoint.resource_name}")
print(f"\n=== Configuration for config.js ===")
print(f"ENDPOINT_ID: \"{endpoint.name.split('/')[-1]}\"")
print(f"PROJECT_ID: \"{aiplatform.initializer.global_config.project}\"")
print(f"REGION: \"{REGION}\"")
print(f"\n=== API Endpoint URL ===")
project_number = aiplatform.initializer.global_config.project
endpoint_id = endpoint.name.split('/')[-1]
api_url = f"https://{endpoint_id}.{REGION}-{project_number}.prediction.vertexai.goog/v1/projects/{project_number}/locations/{REGION}/endpoints/{endpoint_id}:predict"
print(f"{api_url}")
print(f"\nDeployment completed successfully! 🎉") 