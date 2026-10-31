#!/usr/bin/env bash
# ==============================================================================
# Hardware-Conscious Performance Engineering: 1 GB HugePages Provisioning
# Evaluated on VMware ESXi 8.0 & Bare-Metal Linux (x86-64)
# ==============================================================================
set -euo pipefail

echo "=========================================================="
echo " [HPC Engine] Provisioning 1 GB HugePages (pdpe1gb)"
echo "=========================================================="

# 1. Verify CPU support for 1GB pages
if ! grep -q "pdpe1gb" /proc/cpuinfo; then
    echo "[-] Error: CPU architecture does not support 1 GB HugePages (pdpe1gb flag missing)." >&2
    exit 1
fi
echo "[+] CPU supports 1 GB HugePages (pdpe1gb detected)."

# 2. Suppress swapping
echo "[*] Disabling kernel swap aggressiveness..."
sysctl -w vm.swappiness=0

# 3. Compact and drop caches to reduce physical memory fragmentation
echo "[*] Compacting memory and dropping caches..."
sync
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory || true

# 4. Allocate 1 GB HugePages per NUMA node
NUMA_NODES=$(ls -d /sys/devices/system/node/node[0-9]* 2>/dev/null | wc -l)
echo "[*] Detected ${NUMA_NODES} NUMA node(s)."

for node_dir in /sys/devices/system/node/node[0-9]*; do
    node_id=$(basename "$node_dir")
    hp_dir="${node_dir}/hugepages/hugepages-1048576kB"
    if [ -d "$hp_dir" ]; then
        echo "[*] Allocating 3x 1GB hugepages on ${node_id}..."
        echo 3 > "${hp_dir}/nr_hugepages"
        allocated=$(cat "${hp_dir}/nr_hugepages")
        echo "[+] ${node_id}: ${allocated} x 1GB pages successfully allocated."
    else
        echo "[-] ${node_id}: 1GB hugepage interface not found in sysfs."
    fi
done

# 5. Display Summary
echo "=========================================================="
echo " HugePage Allocation Summary:"
grep -i huge /proc/meminfo
echo "=========================================================="
