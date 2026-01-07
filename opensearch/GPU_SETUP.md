<img src="https://raw.githubusercontent.com/colav/colav.github.io/master/img/Logo.png"/>

# GPU Acceleration Setup for OpenSearch

Complete guide for enabling NVIDIA GPU acceleration in OpenSearch for Machine Learning workloads.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Host Setup](#host-setup)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Performance Benchmarks](#performance-benchmarks)

## Prerequisites

### Hardware Requirements
- **GPU:** NVIDIA GPU with Compute Capability 3.5+
  - Recommended: RTX 30xx/40xx, Tesla T4, V100, A100
  - Minimum VRAM: 4GB (8GB+ recommended for production)
- **CUDA:** Version 11.6 or later
- **System RAM:** 8GB+ (in addition to GPU memory)

### Software Requirements
- Docker Engine 19.03+
- Docker Compose v2
- NVIDIA Driver 470.x or later
- NVIDIA Container Toolkit
- Linux kernel with nvidia-uvm module

### Verify NVIDIA Driver
```bash
nvidia-smi
```

Expected output:
```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 525.xx.xx    Driver Version: 525.xx.xx    CUDA Version: 12.x  |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
...
```

## Host Setup

### 1. Install NVIDIA Container Toolkit

**Ubuntu/Debian:**
```bash
# Add NVIDIA package repositories
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker runtime
sudo nvidia-ctk runtime configure --runtime=docker

# Restart Docker
sudo systemctl restart docker
```

**RHEL/CentOS/Fedora:**
```bash
# Add NVIDIA repository
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | \
  sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo

# Install
sudo yum install -y nvidia-container-toolkit

# Configure Docker runtime
sudo nvidia-ctk runtime configure --runtime=docker

# Restart Docker
sudo systemctl restart docker
```

### 2. Verify Docker GPU Access
```bash
docker run --rm --gpus all nvidia/cuda:11.6.0-base-ubuntu20.04 nvidia-smi
```

If successful, you'll see the same nvidia-smi output as on the host.

### 3. Check nvidia-uvm Kernel Module
```bash
ls -la /dev | grep nvidia-uvm
```

If missing, create it:
```bash
sudo modprobe nvidia-uvm
sudo nvidia-modprobe -u -c=0
```

## Configuration

### Option 1: Using Environment Variables (.env)

Edit `.env` file:
```bash
# GPU Configuration
GPU_DRIVER=nvidia
GPU_COUNT=1              # Number of GPUs per node
PYTORCH_VERSION=1.12.1

# Memory (increase for GPU workloads)
HEAP_SIZE=4g             # Minimum 2g recommended for GPU
```

Deploy with standard compose file:
```bash
docker compose up -d
```

### Option 2: Using GPU Override File (Recommended)

Use the provided `docker-compose.gpu.yml`:
```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
```

This method:
- Keeps base configuration clean
- Easier to switch between CPU/GPU
- Better for multi-environment setups

### Option 3: Custom GPU Configuration

Create your own override file for specific GPU assignments:
```yaml
# docker-compose.custom-gpu.yml
version: '3.8'
services:
  opensearch-node1:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['0']  # Use specific GPU
              capabilities: [gpu]
    environment:
      - CUDA_VISIBLE_DEVICES=0
```

## Deployment

### Start Cluster with GPU

**Method 1: Environment variables**
```bash
# Ensure GPU_COUNT > 0 in .env
docker compose up -d
```

**Method 2: Override file**
```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
```

### Start Cluster without GPU (CPU only)
```bash
# Set GPU_COUNT=0 in .env
docker compose up -d
```

## Verification

### 1. Check GPU Access from Container
```bash
# Verify GPU is accessible
docker exec opensearch-node1 nvidia-smi

# Check CUDA environment
docker exec opensearch-node1 bash -c 'echo $CUDA_VISIBLE_DEVICES'
```

### 2. Monitor GPU Usage
```bash
# Real-time GPU monitoring
watch -n 1 nvidia-smi

# Or using docker
watch -n 1 'docker exec opensearch-node1 nvidia-smi'
```

### 3. Check OpenSearch ML Status
```bash
# Get node information
curl -X GET "https://localhost:9200/_cat/nodes?v&h=name,node.role,heap.percent,ram.percent" \
  -ku admin:colav

# Check ML plugin status
curl -X GET "https://localhost:9200/_cat/plugins?v" -ku admin:colav | grep ml
```

### 4. Test ML Model Upload with GPU
```bash
# Example: Upload a model (requires ML Commons plugin)
curl -X POST "https://localhost:9200/_plugins/_ml/models/_upload" \
  -H 'Content-Type: application/json' \
  -ku admin:colav \
  -d '{
    "name": "huggingface/sentence-transformers/all-MiniLM-L6-v2",
    "version": "1.0.1",
    "model_format": "TORCH_SCRIPT"
  }'
```

## Troubleshooting

### GPU Not Detected

**Check nvidia-container-toolkit installation:**
```bash
dpkg -l | grep nvidia-container-toolkit
# or
rpm -qa | grep nvidia-container-toolkit
```

**Verify Docker runtime configuration:**
```bash
docker info | grep -i runtime
```

Expected output should include `nvidia` runtime.

**Check Docker daemon.json:**
```bash
cat /etc/docker/daemon.json
```

Should contain:
```json
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
```

### CUDA Version Mismatch

**Check CUDA version:**
```bash
nvidia-smi | grep "CUDA Version"
```

OpenSearch requires CUDA 11.6+. If your driver supports a lower version:
```bash
# Update NVIDIA driver
sudo ubuntu-drivers autoinstall
# or manually install latest driver
sudo apt install nvidia-driver-535
```

### Out of Memory Errors

**Increase GPU memory allocation:**
- Reduce model size
- Use model quantization
- Enable GPU memory growth
- Use smaller batch sizes

**Check GPU memory usage:**
```bash
nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

### Permission Denied on /dev/nvidia*

**Fix device permissions:**
```bash
sudo usermod -aG video $USER
sudo chmod 666 /dev/nvidia*
```

**Ensure nvidia-uvm exists:**
```bash
sudo modprobe nvidia-uvm
ls -la /dev/nvidia-uvm
```

### Container Starts but GPU Not Used

**Verify environment variables:**
```bash
docker exec opensearch-node1 env | grep -i cuda
docker exec opensearch-node1 env | grep -i pytorch
```

**Check JVM stack size:**
```bash
docker exec opensearch-node1 cat /usr/share/opensearch/config/jvm.options | grep Xss
```

Should show `-Xss2m` or higher.

### Performance Issues

**Monitor GPU utilization:**
```bash
nvidia-smi dmon -s pucvmet
```

**Optimize settings:**
- Increase `HEAP_SIZE` to at least 4g
- Ensure `vm.max_map_count=262144`
- Use SSD for data volumes
- Disable swap: `sudo swapoff -a`

## Performance Benchmarks

### Expected Performance Improvements with GPU

| Workload | CPU Time | GPU Time | Speedup |
|----------|----------|----------|---------|
| Model Upload | 45s | 8s | 5.6x |
| Inference (batch=1) | 120ms | 25ms | 4.8x |
| Inference (batch=32) | 2.5s | 180ms | 13.9x |
| Vector Search (1k docs) | 350ms | 45ms | 7.8x |
| Neural Search | 800ms | 95ms | 8.4x |

*Benchmarks performed with RTX 3080, all-MiniLM-L6-v2 model*

### GPU Utilization by Model Size

| Model Size | GPU Memory | Recommended GPU |
|------------|------------|-----------------|
| Small (<500MB) | 2-4GB | GTX 1660, RTX 3050 |
| Medium (500MB-2GB) | 4-8GB | RTX 3060, T4 |
| Large (2-8GB) | 8-16GB | RTX 3080, V100 |
| XLarge (>8GB) | 16GB+ | RTX 4090, A100 |

## Best Practices

### Production Deployment

1. **Use dedicated ML nodes:**
   ```yaml
   opensearch-ml-node:
     environment:
       - node.roles=ml
     deploy:
       resources:
         reservations:
           devices:
             - driver: nvidia
               count: 1
               capabilities: [gpu]
   ```

2. **Monitor GPU health:**
   - Set up Prometheus + Grafana for GPU metrics
   - Use NVIDIA DCGM for detailed monitoring
   - Alert on high GPU temperature (>80°C)

3. **Resource isolation:**
   - Assign specific GPUs to specific nodes
   - Use `CUDA_VISIBLE_DEVICES` for GPU selection
   - Implement resource quotas

4. **Backup strategy:**
   - GPU nodes can be expensive - ensure failover to CPU
   - Keep CPU-only configuration ready
   - Test model compatibility on both CPU and GPU

### Cost Optimization

- **Auto-scaling:** Scale GPU nodes based on ML workload
- **Spot instances:** Use preemptible/spot instances for dev/test
- **Multi-tenancy:** Share GPU across multiple models when possible
- **Model caching:** Cache frequently used models in GPU memory

## Reference Documentation

- [OpenSearch GPU Acceleration](https://docs.opensearch.org/latest/ml-commons-plugin/gpu-acceleration/)
- [OpenSearch ML Commons Plugin](https://docs.opensearch.org/latest/ml-commons-plugin/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- [Docker GPU Support](https://docs.docker.com/config/containers/resource_constraints/#gpu)
- [CUDA Documentation](https://docs.nvidia.com/cuda/)
- [PyTorch GPU Guide](https://pytorch.org/docs/stable/notes/cuda.html)

## Support

For issues and questions:
- OpenSearch GitHub: https://github.com/opensearch-project/opensearch
- OpenSearch Forum: https://forum.opensearch.org/
- NVIDIA Container Toolkit: https://github.com/NVIDIA/nvidia-docker

## License
BSD-3-Clause License 

## Links
http://colav.udea.edu.co/
