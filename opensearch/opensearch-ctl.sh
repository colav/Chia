#!/bin/bash
# OpenSearch Control Script
# Manage OpenSearch cluster with CPU or GPU support

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
    echo "    OpenSearch Cluster Control Script"
    echo "================================================"
    echo -e "${NC}"
}

show_usage() {
    show_banner
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start-cpu       Start cluster in CPU-only mode"
    echo "  start-gpu       Start cluster with GPU support"
    echo "  stop            Stop the cluster"
    echo "  restart-cpu     Restart cluster in CPU mode"
    echo "  restart-gpu     Restart cluster in GPU mode"
    echo "  status          Show cluster status"
    echo "  logs [service]  Show logs (optional: opensearch-node1, opensearch-node2, opensearch-dashboards)"
    echo "  check-gpu       Verify GPU support"
    echo "  test            Test cluster connectivity"
    echo "  clean           Stop and remove all data (destructive!)"
    echo ""
    echo "Examples:"
    echo "  $0 start-cpu              # Start with CPU only"
    echo "  $0 start-gpu              # Start with GPU acceleration"
    echo "  $0 logs opensearch-node1  # Show node1 logs"
    echo "  $0 test                   # Test cluster is working"
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
        # Set CPU mode
        sed -i 's/^GPU_COUNT=.*/GPU_COUNT=0/' .env
        echo -e "${GREEN}✓ Configured for CPU mode (GPU_COUNT=0)${NC}"
    else
        # Set GPU mode
        sed -i 's/^GPU_COUNT=.*/GPU_COUNT=1/' .env
        echo -e "${GREEN}✓ Configured for GPU mode (GPU_COUNT=1)${NC}"
    fi
}

start_cpu() {
    echo -e "${BLUE}Starting OpenSearch in CPU-only mode...${NC}"
    check_env
    update_gpu_mode "cpu"
    docker compose up -d
    echo ""
    echo -e "${GREEN}✓ Cluster started successfully (CPU mode)${NC}"
    show_access_info
}

start_gpu() {
    echo -e "${BLUE}Starting OpenSearch with GPU acceleration...${NC}"
    check_env
    
    # Quick GPU check
    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${YELLOW}⚠ Warning: nvidia-smi not found. GPU may not be available.${NC}"
        echo "  Run './check-gpu-support.sh' for detailed verification"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    update_gpu_mode "gpu"
    docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
    echo ""
    echo -e "${GREEN}✓ Cluster started successfully (GPU mode)${NC}"
    
    # Wait a bit and check GPU
    sleep 3
    echo ""
    echo "Verifying GPU access in container..."
    if docker exec opensearch-node1 nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✓ GPU is accessible from OpenSearch container${NC}"
        docker exec opensearch-node1 nvidia-smi --query-gpu=name --format=csv,noheader
    else
        echo -e "${YELLOW}⚠ Could not verify GPU access (container may still be starting)${NC}"
    fi
    
    show_access_info
}

stop_cluster() {
    echo -e "${BLUE}Stopping OpenSearch cluster...${NC}"
    docker compose down --timeout 10
    echo -e "${GREEN}✓ Cluster stopped${NC}"
}

restart_cpu() {
    echo -e "${BLUE}Restarting OpenSearch in CPU mode...${NC}"
    stop_cluster
    sleep 2
    start_cpu
}

restart_gpu() {
    echo -e "${BLUE}Restarting OpenSearch in GPU mode...${NC}"
    stop_cluster
    sleep 2
    start_gpu
}

show_status() {
    echo -e "${BLUE}Cluster Status:${NC}"
    echo ""
    docker compose ps
    echo ""
    
    # Check if cluster is responding
    if curl -s -k -u "admin:$(grep OPENSEARCH_PASSWORD .env | cut -d'=' -f2)" \
        "https://localhost:9200/_cluster/health" &> /dev/null; then
        echo -e "${GREEN}✓ Cluster is responding${NC}"
        echo ""
        echo "Cluster Health:"
        curl -s -k -u "admin:$(grep OPENSEARCH_PASSWORD .env | cut -d'=' -f2)" \
            "https://localhost:9200/_cluster/health?pretty"
    else
        echo -e "${YELLOW}⚠ Cluster is not responding yet (may still be starting)${NC}"
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

check_gpu() {
    echo -e "${BLUE}Running GPU support check...${NC}"
    if [ -x ./check-gpu-support.sh ]; then
        ./check-gpu-support.sh
    else
        echo -e "${RED}✗ check-gpu-support.sh not found or not executable${NC}"
        echo "  Run: chmod +x check-gpu-support.sh"
        exit 1
    fi
}

test_cluster() {
    echo -e "${BLUE}Testing cluster connectivity...${NC}"
    echo ""
    
    local password=$(grep "^OPENSEARCH_PASSWORD=" .env | cut -d'=' -f2-)
    
    echo "1. Testing REST API..."
    if response=$(curl -s -k -u "admin:${password}" "https://localhost:9200/" 2>&1); then
        echo -e "${GREEN}✓ REST API is accessible${NC}"
        echo "$response" | grep -E "(cluster_name|version)" | head -5 || true
    else
        echo -e "${RED}✗ REST API is not accessible${NC}"
        echo "  Cluster may not be running or still starting"
        echo "  Try: ./opensearch-ctl.sh status"
        return 1
    fi
    
    echo ""
    echo "2. Testing cluster health..."
    if health=$(curl -s -k -u "admin:${password}" "https://localhost:9200/_cluster/health?pretty" 2>&1); then
        echo "$health" | grep -E "(cluster_name|status|number_of_nodes)" || echo "$health"
    else
        echo -e "${YELLOW}⚠ Could not retrieve cluster health${NC}"
    fi
    
    echo ""
    echo "3. Testing nodes..."
    if nodes=$(curl -s -k -u "admin:${password}" "https://localhost:9200/_cat/nodes?v&h=name,node.role,heap.percent,ram.percent" 2>&1); then
        echo "$nodes"
    else
        echo -e "${YELLOW}⚠ Could not retrieve nodes info${NC}"
    fi
    
    echo ""
    echo "4. Testing OpenSearch Dashboards..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5601/api/status | grep -q "200\|302\|401"; then
        echo -e "${GREEN}✓ Dashboards is accessible at http://localhost:5601${NC}"
    else
        echo -e "${YELLOW}⚠ Dashboards may not be ready yet${NC}"
    fi
    
    # Check GPU if in GPU mode
    local gpu_count=$(grep "^GPU_COUNT=" .env | cut -d'=' -f2 | tr -d ' ')
    if [[ "$gpu_count" =~ ^[0-9]+$ ]] && [ "$gpu_count" -gt 0 ]; then
        echo ""
        echo "5. Testing GPU access..."
        if docker exec opensearch-node1 nvidia-smi 2>&1 | grep -q "NVIDIA-SMI"; then
            echo -e "${GREEN}✓ GPU is accessible${NC}"
            docker exec opensearch-node1 nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader 2>/dev/null || true
        else
            echo -e "${RED}✗ GPU is not accessible${NC}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✓ Test completed!${NC}"
}

clean_all() {
    echo -e "${RED}WARNING: This will stop the cluster and DELETE ALL DATA!${NC}"
    read -p "Are you sure you want to continue? (type 'yes' to confirm) " -r
    echo
    if [ "$REPLY" = "yes" ]; then
        echo -e "${BLUE}Stopping cluster and removing volumes...${NC}"
        docker compose down -v
        echo -e "${GREEN}✓ Cluster stopped and all data removed${NC}"
    else
        echo "Cancelled"
        exit 0
    fi
}

show_access_info() {
    local password=$(grep "^OPENSEARCH_PASSWORD=" .env | cut -d'=' -f2-)
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${GREEN}Access Information:${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo "OpenSearch REST API:  https://localhost:9200"
    echo "OpenSearch Dashboards: http://localhost:5601"
    echo ""
    echo "Credentials:"
    echo "  Username: admin"
    echo "  Password: $password"
    echo ""
    echo "Quick test:"
    echo "  curl -k -u 'admin:$password' 'https://localhost:9200/'"
    echo ""
    echo "View logs:"
    echo "  $0 logs"
    echo ""
    echo "Check status:"
    echo "  $0 status"
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
        stop_cluster
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
    check-gpu)
        check_gpu
        ;;
    test)
        test_cluster
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
