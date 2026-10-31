#!/usr/bin/env bash
# ==============================================================================
# Hardware-Conscious Performance Engineering: NUMA Interconnect & Kernel Tuning
# Dual-Socket Enterprise Architecture (Broadwell-EP / Ivy Bridge-EP)
# ==============================================================================
set -euo pipefail

echo "=========================================================="
echo " [HPC Engine] Enforcing Static NUMA Affinity & Latency Rules"
echo "=========================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This script must be executed with root privileges." >&2
    exit 1
fi

# 1. Inspect NUMA topology
echo "[*] Querying NUMA nodes..."
if command -v numactl &>/dev/null; then
    numactl --hardware
else
    echo "[-] Warning: numactl not found. Install numactl for advanced affinity control."
fi

# 2. Disable kernel automatic NUMA balancing
# Eliminates soft page faults, PTE unmapping, and kernel scheduler migration jitter
echo "[*] Disabling kernel automatic NUMA balancing daemon..."
sysctl -w kernel.numa_balancing=0

# Verify sysctl setting
current_setting=$(sysctl -n kernel.numa_balancing)
if [ "$current_setting" -eq 0 ]; then
    echo "[+] kernel.numa_balancing successfully set to 0."
else
    echo "[-] Failed to set kernel.numa_balancing."
fi

# 3. Best Practice: Launching pinned NUMA benchmarks
echo ""
echo "=========================================================="
echo " Recommended Dual-Dataset Execution Model:"
echo "----------------------------------------------------------"
echo " To execute on Socket 0 with local Node 0 memory allocation:"
echo "   numactl --cpunodebind=0 --membind=0 ./hpc_benchmark --dataset S0"
echo ""
echo " To execute on Socket 1 with local Node 1 memory allocation:"
echo "   numactl --cpunodebind=1 --membind=1 ./hpc_benchmark --dataset S1"
echo "=========================================================="
