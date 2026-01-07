<img src="https://raw.githubusercontent.com/colav/colav.github.io/master/img/Logo.png"/>

# Ollama - Local LLM Server

Run large language models locally with Ollama. Deploy with Docker in CPU or GPU mode.

## 🎯 Features

- **Latest Ollama Version:** v0.13.5
- **GPU Acceleration:** NVIDIA CUDA support for faster inference
- **Model Library:** Access to 100+ open models (Llama 3, Gemma 3, DeepSeek-R1, QwQ, Phi 4, Mistral, etc.)
- **Easy Management:** Control script for quick start/stop/status
- **Docker Based:** Isolated, reproducible environment
- **REST API:** OpenAI-compatible API endpoints

## 📁 Project Structure

```
ollama/
├── docker-compose.yml         # Main compose file (CPU/GPU)
├── docker-compose.gpu.yml     # GPU-specific overrides
├── .env                       # Configuration variables
├── .env.example              # Example CPU configuration
├── .env.gpu.example          # Example GPU configuration
├── ollama-ctl.sh             # Control script (start/stop/status)
├── README.md                 # This file
└── .gitignore                # Git ignore rules
```

## System Requirements

### CPU Mode (Default)
- **RAM:** 8GB minimum (16GB+ recommended)
- **Storage:** 10GB+ for models
- **CPU:** Modern multi-core processor

### GPU Mode (Optional)
- **GPU:** NVIDIA GPU with CUDA 11.6+
- **VRAM:** 4GB minimum (8GB+ recommended)
- **RAM:** 8GB+ system RAM
- **Drivers:** NVIDIA Container Toolkit installed

## Quick Start

### 1. Initial Setup

```bash
# Copy example configuration
cp .env.example .env

# Edit configuration if needed
nano .env
```

### 2. Start Ollama

**CPU Mode:**
```bash
./ollama-ctl.sh start-cpu
```

**GPU Mode:**
```bash
./ollama-ctl.sh start-gpu
```

### 3. Access Services

- **Ollama API:** http://localhost:11434
- **API Docs:** https://github.com/ollama/ollama/blob/main/docs/api.md

### 4. Pull and Run Models

```bash
# Pull a model
./ollama-ctl.sh pull llama3.2

# List downloaded models
./ollama-ctl.sh list

# Chat with a model
./ollama-ctl.sh run llama3.2

# Remove a model
./ollama-ctl.sh rm llama3.2
```

## Control Script Commands

```bash
./ollama-ctl.sh <command>
```

| Command | Description |
|---------|-------------|
| `start-cpu` | Start in CPU-only mode |
| `start-gpu` | Start with GPU acceleration |
| `stop` | Stop all services |
| `restart-cpu` | Restart in CPU mode |
| `restart-gpu` | Restart in GPU mode |
| `status` | Show service status |
| `logs [service]` | Show logs |
| `pull <model>` | Download a model |
| `list` | List downloaded models |
| `run <model>` | Interactive chat with model |
| `rm <model>` | Remove a model |
| `check-gpu` | Verify GPU support |
| `test` | Test services |
| `--help` | Show all commands |

## Configuration

Edit `.env` file to customize:

```bash
# Ollama Settings
OLLAMA_PORT=11434                  # API port
OLLAMA_NUM_PARALLEL=1              # Parallel requests
OLLAMA_MAX_LOADED_MODELS=1         # Models in memory
OLLAMA_KEEP_ALIVE=5m               # Model unload time

# GPU Settings
GPU_COUNT=0                        # 0=CPU, 1+=GPU count
```

## GPU Setup

### Prerequisites

1. **NVIDIA GPU** with CUDA 11.6+
2. **NVIDIA Container Toolkit:**

```bash
# Ubuntu/Debian
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Enable GPU

```bash
# Method 1: Edit .env
GPU_COUNT=1

# Method 2: Use control script
./ollama-ctl.sh start-gpu
```

### Verify GPU

```bash
# Check GPU support
./ollama-ctl.sh check-gpu

# View GPU usage
docker exec ollama nvidia-smi
```

## Popular Models

| Model | Size | Download | Best For |
|-------|------|----------|----------|
| Llama 3.2 | 3B | `./ollama-ctl.sh pull llama3.2` | General purpose, fast |
| Gemma 3 | 4B | `./ollama-ctl.sh pull gemma3` | Fast, efficient |
| DeepSeek-R1 | 7B | `./ollama-ctl.sh pull deepseek-r1` | Reasoning, complex tasks |
| QwQ | 32B | `./ollama-ctl.sh pull qwq` | High quality responses |
| Phi 4 | 14B | `./ollama-ctl.sh pull phi4` | Balanced performance |
| Mistral | 7B | `./ollama-ctl.sh pull mistral` | Fast, multilingual |
| CodeLlama | 7B | `./ollama-ctl.sh pull codellama` | Code generation |

**Browse all models:** https://ollama.com/library

## API Usage

### cURL Examples

```bash
# Generate response
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?"
}'

# Chat conversation
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2",
  "messages": [
    { "role": "user", "content": "Hello!" }
  ]
}'

# List models
curl http://localhost:11434/api/tags

# Model info
curl http://localhost:11434/api/show -d '{"name": "llama3.2"}'
```

### Python Example

```python
import requests

response = requests.post(
    'http://localhost:11434/api/generate',
    json={
        'model': 'llama3.2',
        'prompt': 'Explain quantum computing'
    }
)

for line in response.iter_lines():
    print(line.decode('utf-8'))
```

## Performance Tips

### CPU Mode
- Keep only 1-2 models loaded: `OLLAMA_MAX_LOADED_MODELS=1`
- Use smaller models (1B-7B parameters)
- Increase `OLLAMA_NUM_PARALLEL` with more CPU cores

### GPU Mode
- Load multiple small models or 1 large model
- Monitor VRAM usage: `nvidia-smi`
- Increase `OLLAMA_NUM_PARALLEL` for concurrent requests
- Set `OLLAMA_KEEP_ALIVE=0` to keep models in VRAM

### Model Size Guide
- **1B-3B:** Fast, light tasks (< 4GB RAM/VRAM)
- **7B:** Balanced performance (8GB RAM/VRAM)
- **13B-30B:** High quality (16-32GB RAM/VRAM)
- **70B+:** Best quality (64GB+ RAM/VRAM, multi-GPU)

## Troubleshooting

### Service won't start
```bash
# Check logs
./ollama-ctl.sh logs

# Check port availability
sudo lsof -i :11434
sudo lsof -i :8080
```

### GPU not detected
```bash
# Verify NVIDIA runtime
docker info | grep -i nvidia

# Test GPU in container
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

### Models are slow
- Check system resources: `htop`, `nvidia-smi`
- Use smaller models
- Enable GPU if available
- Close other applications

### Out of Memory
- Use smaller models
- Reduce `OLLAMA_MAX_LOADED_MODELS`
- Lower `OLLAMA_NUM_PARALLEL`
- Increase system swap (not recommended for GPU)

## Advanced Usage

### Custom Models

Create a `Modelfile`:
```
FROM llama3.2

PARAMETER temperature 0.8
PARAMETER top_p 0.9

SYSTEM """
You are a helpful AI assistant specialized in Python programming.
"""
```

Build and run:
```bash
docker exec ollama ollama create my-python-assistant -f ./Modelfile
docker exec ollama ollama run my-python-assistant
```

### Multiple GPUs

```bash
# Use all GPUs
GPU_COUNT=all

# Or specific GPUs
CUDA_VISIBLE_DEVICES=0,1
```

### Production Deployment

```bash
# Increase limits
OLLAMA_NUM_PARALLEL=4
OLLAMA_MAX_LOADED_MODELS=3
OLLAMA_KEEP_ALIVE=1h

# Enable GPU
GPU_COUNT=1

# Secure WebUI
WEBUI_AUTH=true
WEBUI_SECRET_KEY=$(openssl rand -hex 32)
```
- **LangChain** (Python, JS, Go, Java, Rust)
- **LlamaIndex**
- **OpenAI API** (drop-in replacement)
- **Continue** (VS Code extension)
- **Open WebUI** (included)
- And 100+ other tools

See: https://github.com/ollama/ollama#community-integrations
LiteLLM** (unified API)
- **Semantic Kernel**
## Documentation

- **Official Docs:** https://docs.ollama.com/
- **API Reference:** https://github.com/ollama/ollama/blob/main/docs/api.md
- **Model Library:** https://ollama.com/library
- **GitHub:** https://github.com/ollama/ollama
- **Discord:** https://discord.gg/ollama

## License

BSD-3-Clause License 

## Links

http://colav.udea.edu.co/
