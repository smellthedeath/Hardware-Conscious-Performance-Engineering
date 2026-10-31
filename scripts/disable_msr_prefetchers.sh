#!/usr/bin/env bash
# ==============================================================================
# Hardware-Conscious Performance Engineering: MSR 0x1A4 Prefetcher Suppression
# Intel Broadwell-EP, Ivy Bridge-EP, Coffee Lake architectures
# ==============================================================================
set -euo pipefail

echo "=========================================================="
echo " [HPC Engine] Disabling Intel Hardware Prefetchers (0x1A4)"
echo "=========================================================="

# Check root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This script must be executed with root privileges." >&2
    exit 1
fi

# 1. Check Kernel Lockdown status
if [ -f /sys/kernel/security/lockdown ]; then
    LOCKDOWN_STATUS=$(cat /sys/kernel/security/lockdown)
    echo "[*] Current Kernel Lockdown Status: ${LOCKDOWN_STATUS}"
    if echo "${LOCKDOWN_STATUS}" | grep -q "\[integrity\]\|\[confidentiality\]"; then
        echo "[-] ERROR: Kernel is in Lockdown mode."
        echo "    UEFI Secure Boot blocks user-space MSR modification (EPERM)."
        echo "    Remediation: Disable UEFI Secure Boot in ESXi VM Boot Options."
        exit 1
    fi
fi

# 2. Check for msr-tools
if ! command -v wrmsr &>/dev/null || ! command -v rdmsr &>/dev/null; then
    echo "[*] Installing msr-tools..."
    if command -v apt-get &>/dev/null; then
        apt-get update -qq && apt-get install -y msr-tools
    elif command -v yum &>/dev/null; then
        yum install -y msr-tools
    else
        echo "[-] Package manager not found. Please install msr-tools manually." >&2
        exit 1
    fi
fi

# 3. Load msr kernel module
echo "[*] Loading 'msr' kernel module..."
modprobe msr

# 4. Write 0xF to MSR 0x1A4 across all online CPU cores
# Bits [3:0]:
# Bit 0: L2 Hardware Prefetcher Disable
# Bit 1: L2 Adjacent Cache Line Prefetcher Disable
# Bit 2: DCU Streamer Prefetcher Disable
# Bit 3: DCU IP Prefetcher Disable
echo "[*] Writing 0xF to MSR 0x1A4 (MSR_PREFETCH_CONTROL) across all physical vCPUs..."
wrmsr -a 0x1a4 0xf

# 5. Verify prefetcher state
echo "[+] Verification: Current MSR 0x1A4 register values across cores:"
rdmsr -a 0x1a4 | head -n 8
echo "[+] Speculative cache pollution successfully mitigated."
