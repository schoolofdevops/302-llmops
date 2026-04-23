FROM python:3.11-slim

WORKDIR /workspace

# Install CPU torch first (separate index URL)
RUN pip install --no-cache-dir \
    "torch==2.11.0" \
    --index-url https://download.pytorch.org/whl/cpu

# Install remaining ML dependencies
RUN pip install --no-cache-dir \
    transformers==5.5.4 \
    peft==0.19.0 \
    accelerate==1.13.0 \
    datasets==4.8.4

COPY train_lora.py merge_lora.py ./

# Default: run training (override for merge)
CMD ["python", "train_lora.py"]
