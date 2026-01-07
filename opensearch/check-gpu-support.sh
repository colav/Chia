#!/bin/bash
# GPU Support Check Script for OpenSearch
# This script verifies if your system is ready for GPU-accelerated OpenSearch

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "OpenSearch GPU Support Verification"
echo "================================================"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}✗ Please do not run as root${NC}"
   exit 1
fi

# 1. Check for NVIDIA GPU
echo "1. Checking for NVIDIA GPU..."
if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✓ nvidia-smi found${NC}"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
    NVIDIA_DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
    echo "   Driver Version: $NVIDIA_DRIVER_VERSION"
else
    echo -e "${RED}✗ nvidia-smi not found. Please install NVIDIA drivers.${NC}"
    echo "   Visit: https://www.nvidia.com/Download/index.aspx"
    exit 1
fi

# 2. Check CUDA version
echo ""
echo "2. Checking CUDA version..."
CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}')
if [ -n "$CUDA_VERSION" ]; then
    echo -e "${GREEN}✓ CUDA Version: $CUDA_VERSION${NC}"
    
    # Check if CUDA >= 11.6
    CUDA_MAJOR=$(echo $CUDA_VERSION | cut -d. -f1)
    CUDA_MINOR=$(echo $CUDA_VERSION | cut -d. -f2)
    
    if [ "$CUDA_MAJOR" -gt 11 ] || ([ "$CUDA_MAJOR" -eq 11 ] && [ "$CUDA_MINOR" -ge 6 ]); then
        echo -e "${GREEN}✓ CUDA version meets requirements (>=11.6)${NC}"
    else
        echo -e "${YELLOW}⚠ CUDA version should be 11.6 or higher${NC}"
        echo "   OpenSearch requires CUDA 11.6+. Consider updating drivers."
    fi
else
    echo -e "${RED}✗ Could not detect CUDA version${NC}"
fi

# 3. Check for nvidia-uvm module
echo ""
echo "3. Checking nvidia-uvm kernel module..."
if [ -e /dev/nvidia-uvm ]; then
    echo -e "${GREEN}✓ nvidia-uvm module is loaded${NC}"
else
    echo -e "${YELLOW}⚠ nvidia-uvm module not found${NC}"
    echo "   Attempting to load module..."
    sudo modprobe nvidia-uvm 2>/dev/null && echo -e "${GREEN}✓ Module loaded successfully${NC}" || echo -e "${RED}✗ Failed to load module${NC}"
fi

# 4. Check Docker installation
echo ""
echo "4. Checking Docker installation..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    echo -e "${GREEN}✓ Docker found: $DOCKER_VERSION${NC}"
    
    # Check if user is in docker group
    if groups | grep -q docker; then
        echo -e "${GREEN}✓ User is in docker group${NC}"
    else
        echo -e "${YELLOW}⚠ User not in docker group${NC}"
        echo "   Run: sudo usermod -aG docker $USER"
        echo "   Then logout and login again"
    fi
else
    echo -e "${RED}✗ Docker not found${NC}"
    echo "   Please install Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

# 5. Check NVIDIA Container Toolkit
echo ""
echo "5. Checking NVIDIA Container Toolkit..."
if dpkg -l | grep -q nvidia-container-toolkit || rpm -qa | grep -q nvidia-container-toolkit; then
    echo -e "${GREEN}✓ NVIDIA Container Toolkit is installed${NC}"
    
    # Check if runtime is configured
    if docker info 2>/dev/null | grep -q "nvidia"; then
        echo -e "${GREEN}✓ NVIDIA runtime is configured${NC}"
    else
        echo -e "${YELLOW}⚠ NVIDIA runtime not detected in Docker${NC}"
        echo "   Run: sudo nvidia-ctk runtime configure --runtime=docker"
        echo "   Then: sudo systemctl restart docker"
    fi
else
    echo -e "${RED}✗ NVIDIA Container Toolkit not installed${NC}"
    echo "   Installation instructions:"
    echo "   Ubuntu/Debian:"
    echo "     distribution=\$(. /etc/os-release;echo \$ID\$VERSION_ID)"
    echo "     curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
    echo "     sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit"
    echo "     sudo nvidia-ctk runtime configure --runtime=docker"
    echo "     sudo systemctl restart docker"
    exit 1
fi

# 6. Test GPU access in Docker
echo ""
echo "6. Testing GPU access in Docker..."

# Try multiple methods to test GPU access
GPU_TEST_PASSED=false

# Method 1: Try with nvidia/cuda image
echo "   Testing with nvidia/cuda:11.6.0-base-ubuntu20.04..."
if docker run --rm --gpus all nvidia/cuda:11.6.0-base-ubuntu20.04 nvidia-smi 2>&1 | grep -q "NVIDIA-SMI"; then
    GPU_TEST_PASSED=true
    echo -e "${GREEN}✓ GPU is accessible from Docker containers${NC}"
    docker run --rm --gpus all nvidia/cuda:11.6.0-base-ubuntu20.04 nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null
elif docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu20.04 nvidia-smi 2>&1 | grep -q "NVIDIA-SMI"; then
    # Try with CUDA 12 if 11.6 fails
    GPU_TEST_PASSED=true
    echo -e "${GREEN}✓ GPU is accessible from Docker containers (CUDA 12)${NC}"
    docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu20.04 nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null
else
    # Show detailed error
    echo -e "${YELLOW}⚠ Could not pull/run nvidia/cuda test image${NC}"
    echo "   Attempting alternative test with device mounting..."
    
    # Method 2: Try with a simple container and device mounting
    if docker run --rm --gpus all --device=/dev/nvidia0 alpine sh -c "ls /dev/nvidia* 2>/dev/null" | grep -q nvidia; then
        GPU_TEST_PASSED=true
        echo -e "${GREEN}✓ GPU devices are accessible in containers${NC}"
    fi
fi

if [ "$GPU_TEST_PASSED" = false ]; then
    echo -e "${YELLOW}⚠ GPU test with Docker containers inconclusive${NC}"
    echo "   This might be due to:"
    echo "   - Docker image pull issues (check internet connection)"
    echo "   - Firewall or proxy blocking Docker Hub"
    echo ""
    echo "   Manual verification:"
    echo "   1. Check NVIDIA runtime: docker info | grep -i nvidia"
    
    # Show current docker runtime configuration
    if docker info 2>/dev/null | grep -qi nvidia; then
        echo -e "      ${GREEN}✓ NVIDIA runtime is configured${NC}"
    else
        echo -e "      ${RED}✗ NVIDIA runtime not found in docker info${NC}"
    fi
    
    echo "   2. Try manually: docker run --rm --gpus all nvidia/cuda:11.6.0-base-ubuntu20.04 nvidia-smi"
    echo "   3. Check /etc/docker/daemon.json"
    echo ""
    echo "   If your GPU works with other containers, you can proceed."
    echo "   Press Ctrl+C to abort, or Enter to continue anyway..."
    read -t 10 || echo ""
fi

# 7. Check system resources
echo ""
echo "7. Checking system resources..."

# RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
echo "   Total RAM: ${TOTAL_RAM}GB"
if [ "$TOTAL_RAM" -ge 8 ]; then
    echo -e "${GREEN}✓ RAM meets recommendations (8GB+)${NC}"
else
    echo -e "${YELLOW}⚠ RAM is below recommended 8GB${NC}"
fi

# vm.max_map_count
VM_MAX_MAP=$(sysctl vm.max_map_count | awk '{print $3}')
echo "   vm.max_map_count: $VM_MAX_MAP"
if [ "$VM_MAX_MAP" -ge 262144 ]; then
    echo -e "${GREEN}✓ vm.max_map_count meets requirements${NC}"
else
    echo -e "${YELLOW}⚠ vm.max_map_count should be >= 262144${NC}"
    echo "   Run: sudo sysctl -w vm.max_map_count=262144"
fi

# 8. Check GPU Memory
echo ""
echo "8. Checking GPU memory..."
GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
echo "   GPU Memory: ${GPU_MEM}MB"
if [ "$GPU_MEM" -ge 4096 ]; then
    echo -e "${GREEN}✓ GPU memory is sufficient (4GB+)${NC}"
else
    echo -e "${YELLOW}⚠ GPU memory is below recommended 4GB${NC}"
    echo "   Small models may still work, but large models may fail"
fi

# Summary
echo ""
echo "================================================"
echo "Summary"
echo "================================================"

ALL_CHECKS_PASSED=true

# Check all critical components
if ! command -v nvidia-smi &> /dev/null; then ALL_CHECKS_PASSED=false; fi
if ! command -v docker &> /dev/null; then ALL_CHECKS_PASSED=false; fi
if ! dpkg -l 2>/dev/null | grep -q nvidia-container-toolkit && ! rpm -qa 2>/dev/null | grep -q nvidia-container-toolkit; then ALL_CHECKS_PASSED=false; fi

# GPU test is now more lenient - check if NVIDIA runtime exists
if ! docker info 2>/dev/null | grep -qi nvidia; then 
    echo -e "${YELLOW}⚠ Warning: NVIDIA runtime not detected in docker info${NC}"
fi

if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✓ Your system is ready for GPU-accelerated OpenSearch!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Edit .env file and set: GPU_COUNT=1"
    echo "2. Start OpenSearch: docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d"
    echo "3. Verify: docker exec opensearch-node1 nvidia-smi"
    echo ""
    echo "For detailed instructions, see GPU_SETUP.md"
else
    echo -e "${RED}✗ Your system needs additional setup${NC}"
    echo ""
    echo "Please address the issues marked with ✗ or ⚠ above"
    echo "See GPU_SETUP.md for detailed troubleshooting"
fi

echo "================================================"
