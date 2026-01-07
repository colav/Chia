<img src="https://raw.githubusercontent.com/colav/colav.github.io/master/img/Logo.png"/>

# Chai
Dev-Ops for Colav services


# Description
This is a mono repo with DevOps packages for multiple Colav services.

## Available Services

### 🔍 OpenSearch (NEW)
- **Version:** 3.4.0
- **Features:** 2-node cluster + Dashboards, CPU/GPU support
- **Location:** `opensearch/`
- **GPU Support:** ✅ NVIDIA CUDA 11.6+ for ML acceleration
- **Documentation:** [opensearch/README.md](opensearch/README.md) | [GPU Setup Guide](opensearch/GPU_SETUP.md)

### 🤖 Ollama (NEW)
- **Version:** v0.13.5
- **Features:** Local LLM server, 100+ models, GPU support
- **Location:** `ollama/`
- **GPU Support:** ✅ NVIDIA CUDA for faster inference
- **Documentation:** [ollama/README.md](ollama/README.md)

### 🔍 Elasticsearch
- **Location:** `elasticsaerch/`
- **Documentation:** [elasticsaerch/README.md](elasticsaerch/README.md)

### 🗄️ MongoDB
- **Location:** `mongodb/`
- **Documentation:** [mongodb/README.md](mongodb/README.md)

### 🎨 Guatquyca (Impactu UI)
- **Description:** Frontend package for Impactu services
- **Location:** `guatquyca/`
- **Documentation:** [guatquyca/README.md](guatquyca/README.md)

### 🤖 OpenAlex Topic Classification
- **Description:** AI model for document topic prediction
- **Location:** `openalex-topic-classification/`
- **Documentation:** [openalex-topic-classification/README.md](openalex-topic-classification/README.md)

# Installation

# OS Prerequisite
Run the next command to increase the vm max_map_count
```bash
sudo sysctl -w vm.max_map_count=262144
```

## Dependencies
Docker with Compose plugin v2 is required.
* Install Docker: https://docs.docker.com/engine/install/ubuntu/ (or https://docs.docker.com/engine/install/debian/, etc)
* Docker Compose v2 comes bundled with Docker Desktop and Docker Engine
* Verify installation: `docker compose version`

* Post-installation steps: https://docs.docker.com/engine/install/linux-postinstall/


# Usage

Please read the README of every folder to deploy the service.

# License
BSD-3-Clause License 

# Links
http://colav.udea.edu.co/

