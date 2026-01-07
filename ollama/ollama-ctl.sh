#!/bin/bash
# Ollama Control Script
# Manage Ollama server with CPU or GPU support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
show_banner() {
    echo -e "${BLUE}"
    echo "================================================"
    echo "         Ollama Control Script"
    echo "================================================"
    echo -e "${NC}"
}

show_usage() {
    show_banner
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start-cpu           Start Ollama in CPU-only mode"
    echo "  start-gpu           Start Ollama with GPU support"
    echo "  stop                Stop all services"
    echo "  restart-cpu         Restart in CPU mode"
    echo "  restart-gpu         Restart in GPU mode"
    echo "  status              Show service status"
    echo "  logs [service]      Show logs"
    echo "  pull <model>        Download a model"
    echo "  list                List downloaded models"
    echo "  run <model>         Interactive chat with model"
    echo "  rm <model>          Remove a model"
    echo "  check-gpu           Verify GPU support"
    echo "  test                Test service connectivity"
    echo "  clean               Stop and remove all data"
    echo ""
    echo "Examples:"
    echo "  $0 start-cpu                 # Start with CPU only"
    echo "  $0 start-gpu                 # Start with GPU"
    echo "  $0 pull llama3.2             # Download Llama 3.2"
    echo "  $0 run llama3.2              # Chat with model"
    echo "  $0 logs ollama               # Show Ollama logs"
    echo ""
}

check_env() {
    if [ ! -f .env ]; then
        echo -e "${RED}✗ .env file not found!${NC}"
        echo "  Copy from example: cp .env.example .env"
        exit 1
    fi
}

update_gpu_mode() {
    local mode=$1
    if [ "$mode" = "cpu" ]; then
        sed -i 's/^GPU_COUNT=.*/GPU_COUNT=0/' .env
        echo -e "${GREEN}✓ Configured for CPU mode (GPU_COUNT=0)${NC}"
    else
        sed -i 's/^GPU_COUNT=.*/GPU_COUNT=1/' .env
        echo -e "${GREEN}✓ Configured for GPU mode (GPU_COUNT=1)${NC}"
    fi
}

start_cpu() {
    echo -e "${BLUE}Starting Ollama in CPU-only mode...${NC}"
    check_env
    update_gpu_mode "cpu"
    docker compose up -d
    echo ""
    echo -e "${GREEN}✓ Ollama started successfully (CPU mode)${NC}"
    show_access_info
}

start_gpu() {
    echo -e "${BLUE}Starting Ollama with GPU acceleration...${NC}"
    check_env
    
    # Quick GPU check
    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${YELLOW}⚠ Warning: nvidia-smi not found. GPU may not be available.${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    update_gpu_mode "gpu"
    docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
    echo ""
    echo -e "${GREEN}✓ Ollama started successfully (GPU mode)${NC}"
    
    # Wait and check GPU
    sleep 3
    if docker exec ollama nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✓ GPU is accessible from container${NC}"
    fi
    
    show_access_info
}

stop_service() {
    echo -e "${BLUE}Stopping Ollama services...${NC}"
    docker compose down --timeout 10
    echo -e "${GREEN}✓ Services stopped${NC}"
}

restart_cpu() {
    echo -e "${BLUE}Restarting Ollama in CPU mode...${NC}"
    stop_service
    sleep 2
    start_cpu
}

restart_gpu() {
    echo -e "${BLUE}Restarting Ollama in GPU mode...${NC}"
    stop_service
    sleep 2
    start_gpu
}

show_status() {
    echo -e "${BLUE}Service Status:${NC}"
    echo ""
    docker compose ps
    echo ""
    
    # Check if Ollama is responding
    if curl -s http://localhost:11434/api/tags &> /dev/null; then
        echo -e "${GREEN}✓ Ollama API is responding${NC}"
        echo ""
        echo "Downloaded models:"
        curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || echo "  No models downloaded yet"
    else
        echo -e "${YELLOW}⚠ Ollama API is not responding yet (may still be starting)${NC}"
    fi
}

show_logs() {
    local service=$1
    if [ -z "$service" ]; then
        echo -e "${BLUE}Showing logs for all services (Ctrl+C to exit)...${NC}"
        docker compose logs -f
    else
        echo -e "${BLUE}Showing logs for $service (Ctrl+C to exit)...${NC}"
        docker compose logs -f "$service"
    fi
}

pull_model() {
    local model=$1
    if [ -z "$model" ]; then
        echo -e "${RED}✗ Model name required${NC}"
        echo "  Example: $0 pull llama3.2"
        echo "  Browse models: https://ollama.com/library"
        exit 1
    fi
    
    echo -e "${BLUE}Pulling model: $model${NC}"
    docker exec -it ollama ollama pull "$model"
}

list_models() {
    echo -e "${BLUE}Downloaded models:${NC}"
    docker exec ollama ollama list
}

run_model() {
    local model=$1
    if [ -z "$model" ]; then
        echo -e "${RED}✗ Model name required${NC}"
        echo "  Example: $0 run llama3.2"
        exit 1
    fi
    
    echo -e "${BLUE}Starting interactive chat with $model${NC}"
    echo -e "${YELLOW}Type /bye to exit${NC}"
    echo ""
    docker exec -it ollama ollama run "$model"
}

remove_model() {
    local model=$1
    if [ -z "$model" ]; then
        echo -e "${RED}✗ Model name required${NC}"
        echo "  Example: $0 rm llama3.2"
        exit 1
    fi
    
    echo -e "${BLUE}Removing model: $model${NC}"
    docker exec ollama ollama rm "$model"
    echo -e "${GREEN}✓ Model removed${NC}"
}

check_gpu() {
    echo -e "${BLUE}Checking GPU support...${NC}"
    echo ""
    
    # Check nvidia-smi
    if command -v nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✓ nvidia-smi found${NC}"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
    else
        echo -e "${RED}✗ nvidia-smi not found${NC}"
        echo "  Install NVIDIA drivers first"
        exit 1
    fi
    
    echo ""
    
    # Check Docker NVIDIA runtime
    if docker info 2>/dev/null | grep -qi nvidia; then
        echo -e "${GREEN}✓ NVIDIA Docker runtime configured${NC}"
    else
        echo -e "${RED}✗ NVIDIA Docker runtime not configured${NC}"
        echo "  Install NVIDIA Container Toolkit"
        exit 1
    fi
    
    echo ""
    
    # Test GPU in container
    echo "Testing GPU access in Docker..."
    if docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu20.04 nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✓ GPU is accessible from Docker containers${NC}"
    else
        echo -e "${RED}✗ GPU is not accessible from Docker${NC}"
        echo "  Check NVIDIA Container Toolkit installation"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}✓ Your system is ready for GPU-accelerated Ollama!${NC}"
}

test_service() {
    echo -e "${BLUE}Testing Ollama service...${NC}"
    echo ""
    
    echo "1. Testing API endpoint..."
    if response=$(curl -s http://localhost:11434/api/tags 2>&1); then
        echo -e "${GREEN}✓ Ollama API is accessible${NC}"
        echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | head -5 || true
    else
        echo -e "${RED}✗ Ollama API is not accessible${NC}"
        echo "  Service may not be running"
        return 1
    fi
    
    # Check GPU if enabled
    local gpu_count=$(grep "^GPU_COUNT=" .env | cut -d'=' -f2 | tr -d ' ')
    if [[ "$gpu_count" =~ ^[0-9]+$ ]] && [ "$gpu_count" -gt 0 ]; then
        echo ""
        echo "2. Testing GPU access..."
        if docker exec ollama nvidia-smi 2>&1 | grep -q "NVIDIA-SMI"; then
            echo -e "${GREEN}✓ GPU is accessible${NC}"
            docker exec ollama nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader 2>/dev/null || true
        else
            echo -e "${RED}✗ GPU is not accessible${NC}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✓ Test completed!${NC}"
}

clean_all() {
    echo -e "${RED}WARNING: This will stop services and DELETE ALL DATA!${NC}"
    echo "  - All downloaded models will be removed"
    echo ""
    read -p "Are you sure? (type 'yes' to confirm) " -r
    echo
    if [ "$REPLY" = "yes" ]; then
        echo -e "${BLUE}Stopping services and removing data...${NC}"
        docker compose down -v --timeout 10
        echo -e "${GREEN}✓ All data removed${NC}"
    else
        echo "Cancelled"
        exit 0
    fi
}

show_access_info() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${GREEN}Access Information:${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo "Ollama API:   http://localhost:11434"
    echo ""
    echo "Quick commands:"
    echo "  $0 pull llama3.2     # Download a model"
    echo "  $0 run llama3.2      # Chat with model"
    echo "  $0 list              # List models"
    echo "  $0 status            # Check status"
    echo ""
    echo "Browse models:"
    echo "  https://ollama.com/library"
    echo -e "${BLUE}================================================${NC}"
}

# Main
case "${1:-}" in
    start-cpu)
        start_cpu
        ;;
    start-gpu)
        start_gpu
        ;;
    stop)
        stop_service
        ;;
    restart-cpu)
        restart_cpu
        ;;
    restart-gpu)
        restart_gpu
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "${2:-}"
        ;;
    pull)
        pull_model "${2:-}"
        ;;
    list)
        list_models
        ;;
    run)
        run_model "${2:-}"
        ;;
    rm)
        remove_model "${2:-}"
        ;;
    check-gpu)
        check_gpu
        ;;
    test)
        test_service
        ;;
    clean)
        clean_all
        ;;
    -h|--help|help)
        show_usage
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
