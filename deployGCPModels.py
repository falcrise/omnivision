from google.cloud import aiplatform

# 1. Initialize client
PROJECT_ID = "deeptech-ai-stuff"
REGION     = "asia-southeast1"  # :contentReference[oaicite:0]{index=0}
aiplatform.init(project=PROJECT_ID, location=REGION)  # :contentReference[oaicite:1]{index=1}

# 2. Register the Hugging Face model
MODEL_ID = "sentence-transformers/paraphrase-MiniLM-L6-v2"  # HF model repo ID
CONTAINER_URI = "us-docker.pkg.dev/deeplearning-platform-release/gcr.io/huggingface-text-embeddings-inference-cu122.1-5.ubuntu2204"  # :contentReference[oaicite:2]{index=2}

model = aiplatform.Model.upload(
    display_name=f"hf-{MODEL_ID}",
    serving_container_image_uri=CONTAINER_URI,
    serving_container_environment_variables={
        "MODEL_ID": MODEL_ID,
        "TEXT_GENERATION_TASK": "text-generation"
    },
)  

# 3. Create an endpoint
endpoint = aiplatform.Endpoint.create(
    display_name=f"{MODEL_ID}-endpoint"
)  

# 4. Deploy the model
deployed = model.deploy(
    endpoint=endpoint,
    deployed_model_display_name=f"{MODEL_ID}-deployment",
    machine_type="g2-standard-4",            # 4 vCPU | 16 GiB RAM
    accelerator_type="NVIDIA_L4",             # attaches 1× NVIDIA L4 GPU
    accelerator_count=1,
    min_replica_count=1,
    max_replica_count=3,
)

print(f"Model deployed to endpoint: {endpoint.resource_name}") 