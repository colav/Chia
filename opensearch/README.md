<img src="https://raw.githubusercontent.com/colav/colav.github.io/master/img/Logo.png"/>

# OpenSearch
Colav OpenSearch DevOps

# Description
This package sets up a Docker container cluster with OpenSearch (2 nodes) and OpenSearch Dashboards for visualization and management.

OpenSearch is a community-driven, open-source search and analytics suite derived from Elasticsearch 7.10.2 & Kibana 7.10.2.

## 📁 Project Structure

```
opensearch/
├── docker-compose.yml         # Main compose file (CPU/GPU auto-detection)
├── docker-compose.gpu.yml     # GPU-specific override file
├── .env                       # Configuration variables
├── .env.gpu.example          # Example GPU configuration
├── README.md                 # This file - main documentation
├── GPU_SETUP.md              # Complete GPU setup guide
├── check-gpu-support.sh      # GPU compatibility verification script
└── .gitignore                # Git ignore rules
```

**Files description:**
- **docker-compose.yml**: Base configuration supporting both CPU and GPU modes
- **docker-compose.gpu.yml**: GPU-specific overrides (use with `-f` flag)
- **.env**: Main configuration file (customize this!)
- **.env.example**: Example CPU-only configuration (copy to `.env` to start)
- **.env.gpu.example**: Example GPU configuration for ML acceleration
- **GPU_SETUP.md**: Comprehensive GPU acceleration guide
- **check-gpu-support.sh**: Automated GPU compatibility checker

# System Requirements

- **Docker:** Docker Engine with Compose plugin v2
- **RAM:** Minimum 4GB (8GB+ recommended for production)
- **Disk:** SSD recommended for better performance
- **CPU:** 2+ cores recommended
- **OS:** Linux, macOS (with Docker Desktop), or Windows (WSL2)

# Installation

## OS Prerequisites

### Linux
Run the following commands (required for OpenSearch):

```bash
# Disable memory paging and swapping for better performance
sudo swapoff -a

# Increase the number of memory maps available to OpenSearch
sudo sysctl -w vm.max_map_count=262144
```

To make it permanent, add the following line to `/etc/sysctl.conf`:
```
vm.max_map_count=262144
```

Then reload the kernel parameters:
```bash
sudo sysctl -p
```

### Windows (WSL via Docker Desktop)
```bash
wsl -d docker-desktop
sysctl -w vm.max_map_count=262144
```

### macOS & Windows (Docker Desktop)
In Docker Desktop → Settings → Resources, set RAM to at least **4 GB**.

## Dependencies
Docker with Compose plugin is required.
* Install Docker: https://docs.docker.com/engine/install/ubuntu/ (or https://docs.docker.com/engine/install/debian/, etc)
* Docker Compose v2 comes bundled with Docker Desktop and Docker Engine installations
* Verify installation: `docker compose version`

* Post-installation steps: https://docs.docker.com/engine/install/linux-postinstall/

# Configuration

## Initial Setup

1. **Copy the example configuration:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` to customize your deployment:**
   ```bash
   nano .env
   ```

## Configuration Options

Edit the `.env` file:

## Key Configuration Options:

### Version
- `OPENSEARCH_VERSION`: OpenSearch version (default: 3.4.0)

### Cluster
- `CLUSTER_NAME`: Name of your OpenSearch cluster

### Ports
- `OPENSEARCH_PORT`: REST API port (default: 9200)
- `OPENSEARCH_PERF_PORT`: Performance analyzer port (default: 9600)
- `DASHBOARDS_PORT`: OpenSearch Dashboards UI port (default: 5601)

### Memory
- `HEAP_SIZE`: JVM heap size per node (default: 1g)
  - **Recommended: Set to at least 50% of system RAM per node**
  - Minimum: 512MB for development
  - Production: 2GB or more recommended
  - Example: For 8GB RAM available, set to 4g
  - **Important:** Docker Desktop users must allocate at least 4GB RAM to Docker

### Security
- `OPENSEARCH_PASSWORD`: Admin user password (**REQUIRED since OpenSearch 2.12**)
- `SECURITY_DISABLED`: Set to `true` to disable security (NOT recommended for production)

**⚠️ CRITICAL - Password Requirements (OpenSearch 2.12+):**

OpenSearch enforces strong password security using the zxcvbn library:
- **Minimum length:** 8 characters
- **Maximum length:** 100 characters
- **Must be rated "strong"** by entropy-based calculation
- Focus on unpredictability and length over rigid complexity rules
- Avoid common patterns, dictionary words, and sequences
- Example of strong password: `MyStr0ng!P@ssw0rd2024` or `correct-horse-battery-staple-2024`

**⚠️ IMPORTANT**: Change the default password before deploying to production!

## GPU Acceleration (Optional)

OpenSearch supports GPU acceleration for Machine Learning workloads using NVIDIA GPUs with CUDA. This can significantly improve performance for:
- Natural Language Processing (NLP) models  
- Neural search (2-10x faster)
- Vector search with ML models
- Model training and inference

### Quick Start with GPU

**1. Check GPU compatibility:**
```bash
./check-gpu-support.sh
```

**2. Prerequisites:**
- NVIDIA GPU with CUDA 11.6+
- NVIDIA Container Toolkit installed

**3. Enable GPU in .env:**
```bash
GPU_COUNT=1  # Set to number of GPUs (0=CPU only)
```

**4. Deploy:**
```bash
# Option 1: Using environment variables
docker compose up -d

# Option 2: Using GPU override file (recommended)
docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
```

**5. Verify GPU access:**
```bash
docker exec opensearch-node1 nvidia-smi
```

### 📚 Complete GPU Documentation

For detailed GPU setup, troubleshooting, performance benchmarks, and best practices, see:
**[GPU_SETUP.md](GPU_SETUP.md)**

Includes:
- Step-by-step NVIDIA Container Toolkit installation
- GPU configuration options
- Performance benchmarks (CPU vs GPU)
- Troubleshooting guide
- Production deployment best practices

**Quick GPU check:** Run `./check-gpu-support.sh` to verify your system is ready for GPU acceleration.

### GPU vs CPU Quick Comparison

| Mode | Performance | Hardware Required | Use Case |
|------|-------------|-------------------|----------|
| **CPU** (default) | Baseline | None | General search, small ML models, dev/test |
| **GPU** | 2-10x faster | NVIDIA GPU + CUDA 11.6+ | Large ML models, neural search, high-volume inference |

### Reference
- [OpenSearch GPU Acceleration](https://docs.opensearch.org/latest/ml-commons-plugin/gpu-acceleration/)
- [Complete GPU Setup Guide](GPU_SETUP.md)

# Usage

## Quick Start with Control Script (Recommended)

The easiest way to manage your OpenSearch cluster is using the control script:

```bash
# Start with CPU only
./opensearch-ctl.sh start-cpu

# Start with GPU acceleration
./opensearch-ctl.sh start-gpu

# Stop the cluster
./opensearch-ctl.sh stop

# View cluster status
./opensearch-ctl.sh status

# View logs
./opensearch-ctl.sh logs

# Test cluster connectivity
./opensearch-ctl.sh test

# Check GPU support
./opensearch-ctl.sh check-gpu

# Show all available commands
./opensearch-ctl.sh --help
```

### Control Script Commands

| Command | Description |
|---------|-------------|
| `start-cpu` | Start cluster in CPU-only mode |
| `start-gpu` | Start cluster with GPU acceleration |
| `stop` | Stop the cluster |
| `restart-cpu` | Restart in CPU mode |
| `restart-gpu` | Restart in GPU mode |
| `status` | Show cluster status and health |
| `logs [service]` | Show logs (all or specific service) |
| `check-gpu` | Verify GPU support |
| `test` | Test cluster connectivity |
| `clean` | Stop and remove all data (destructive!) |

## Manual Start (Alternative)

If you prefer using docker compose directly:

## Start the cluster
```bash
docker compose up -d
```

## Check cluster status
```bash
# Wait for cluster to be ready (may take 1-2 minutes)
docker compose logs -f opensearch-node1

# Check cluster health
curl -X GET "https://localhost:9200/_cluster/health?pretty" -ku admin:Colav@OpenSearch2024
```

## Access OpenSearch Dashboards
Open your browser and navigate to:
```
http://localhost:5601
```

Default credentials:
- **Username**: admin
- **Password**: Colav@OpenSearch2024 (or the value you set in `.env`)

## Stop the cluster
```bash
docker compose down
```

## Stop and remove volumes (⚠️ deletes all data)
```bash
docker compose down -v
```

# API Usage Examples

## Create an index
```bash
curl -X PUT "https://localhost:9200/my-index" \
  -H 'Content-Type: application/json' \
  -ku admin:Colav@OpenSearch2024 \
  -d '{
    "settings": {
      "number_of_shards": 2,
      "number_of_replicas": 1
    }
  }'
```

## Index a document
```bash
curl -X POST "https://localhost:9200/my-index/_doc" \
  -H 'Content-Type: application/json' \
  -ku admin:Colav@OpenSearch2024 \
  -d '{
    "title": "My Document",
    "content": "This is a test document",
    "timestamp": "2024-01-01T00:00:00"
  }'
```

## Search documents
```bash
curl -X GET "https://localhost:9200/my-index/_search?pretty" \
  -H 'Content-Type: application/json' \
  -ku admin:Colav@OpenSearch2024 \
  -d '{
    "query": {
      "match": {
        "content": "test"
      }
    }
  }'
```

# Production Considerations

1. **Security**: 
   - Change default passwords
   - Configure TLS certificates
   - Enable audit logging
   - Restrict network access

2. **Performance**:
   - Allocate sufficient heap memory (50% of available RAM recommended)
   - Use SSD storage for data volumes
   - Monitor cluster health and performance metrics

3. **High Availability**:
   - Deploy at least 3 master-eligible nodes
   - Distribute nodes across availability zones
   - Configure appropriate replica settings

4. **Backup**:
   - Configure snapshot repository
   - Set up automated backup schedules
   - Test restore procedures regularly

# Troubleshooting

## Container won't start
- Check if vm.max_map_count is set: `sysctl vm.max_map_count`
- Check container logs: `docker compose logs opensearch-node1`
- Verify ports are not in use: `netstat -tulpn | grep -E '9200|5601'`

## Out of memory errors
- Increase HEAP_SIZE in `.env`
- Ensure system has enough RAM (minimum 2GB per node)

## Connection refused
- Wait for cluster initialization (1-2 minutes)
- Check if containers are running: `docker compose ps`
- Verify firewall rules

# Monitoring

## Check cluster health
```bash
curl -X GET "https://localhost:9200/_cluster/health?pretty" -ku admin:Colav@OpenSearch2024
```

## Check node stats
```bash
curl -X GET "https://localhost:9200/_nodes/stats?pretty" -ku admin:Colav@OpenSearch2024
```

## Check indices
```bash
curl -X GET "https://localhost:9200/_cat/indices?v" -ku admin:Colav@OpenSearch2024
```

# Resources

- OpenSearch Documentation: https://opensearch.org/docs/latest/
- OpenSearch GitHub: https://github.com/opensearch-project
- API Reference: https://opensearch.org/docs/latest/api-reference/

# License
BSD-3-Clause License 

# Links
http://colav.udea.edu.co/
