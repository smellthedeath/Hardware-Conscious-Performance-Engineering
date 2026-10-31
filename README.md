<div align="center">

# Hardware-Conscious Performance Engineering
### Cache Hierarchy Optimization, NUMA Topologies, and Hypervisor Resource Scheduling for Memory-Hard HPC Workloads

[![Architecture: x86-64 & ARM64](https://img.shields.io/badge/Architecture-x86--64%20%7C%20ARM64-0078D7.svg?logo=intel&logoColor=white)](https://github.com/smellthedeath/Hardware-Conscious-Performance-Engineering)
[![Hypervisor: VMware ESXi 8.0](https://img.shields.io/badge/Hypervisor-VMware%20ESXi%208.0-607078.svg?logo=vmware&logoColor=white)](https://www.vmware.com)
[![Kernel: Low-Level MSR](https://img.shields.io/badge/Kernel-Linux%20MSR%20%26%20sysctl-FCC624.svg?logo=linux&logoColor=black)](https://kernel.org)
[![HugePages: 1GB pdpe1gb](https://img.shields.io/badge/Memory-1%20GB%20HugePages-4CAF50.svg)]()
[![Throughput Gain](https://img.shields.io/badge/Throughput%20Gain-%2B35%25%20to%20%2B40%25-brightgreen.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Format: IEEE TPDS](https://img.shields.io/badge/Publication-IEEE%20TPDS%20Format-informational.svg)]()

**A systematic, hardware-conscious systems engineering framework for co-scheduling memory-hard HPC benchmarks in multi-tenant enterprise hypervisors.**

*Author:* **Mohammadali Nastaran**  
*Principal HPC Systems Architect and Senior Linux Kernel Engineer*

[📄 Read Full Paper (PDF)](./Hardware-Conscious-Performance-Engineering.pdf) • [🛠 Reproduction Scripts](./scripts) • [📚 Citation](#-citation)

</div>

---

## 📌 Abstract

Executing stochastic, non-linear memory-bound high-performance computing (HPC) workloads within multi-tenant virtualized environments presents severe architectural challenges due to cache thrashing, cross-socket interconnect saturation, translation lookaside buffer (TLB) misses, and hypervisor scheduling contention. 

This paper presents a systematic, hardware-conscious performance engineering framework evaluated across heterogeneous **x86-64** and **ARM64** architectures hosted on **VMware ESXi 8.0** enterprise hypervisors. By aligning execution thread counts with last-level cache (LLC) capacity, eliminating Simultaneous Multithreading (SMT) execution port contention, partitioning working datasets across Non-Uniform Memory Access (NUMA) domains, deploying 1 GB huge pages to eliminate Extended Page Table (EPT) walks, disabling speculative hardware prefetchers via Model-Specific Registers (MSRs), and enforcing proportional-share hypervisor CPU scheduling, we demonstrate aggregate throughput improvements of **35% to 40% in instructions per cycle (IPC) efficiency**. 

Furthermore, our co-scheduled virtualization methodology recovers **6.1 GHz of host compute capacity** per hypervisor node while guaranteeing zero degradation to co-located latency-sensitive production virtual machines.

---

## 🔬 Mathematical Workload Model

The target benchmark executes pseudo-random read-modify-write operations over a shared read-only state table $S$ ($M_S \approx 2.3\text{ GB}$) and a private thread-local scratchpad buffer $B_i$ ($M_B = 2.0\text{ MB}$).

During iteration $k$, an active thread $i$ evaluates the non-linear dependency chain:

$$A_{k+1} = f\left(A_k \oplus B_i[\phi(A_k)] \oplus S[\psi(A_k)]\right)$$

Where:
- $\phi, \psi$: Uniform pseudo-random indexing functions mapping into scratchpad $B_i$ and global state $S$.
- $f$: Mixed integer and vectorizable (AVX2) arithmetic transformation.
- **Microarchitectural Bottleneck:** Because $\phi(A_k)$ exhibits zero spatial or temporal locality, any cache eviction of $B_i$ from L3 forces a full main-memory round-trip penalty (~60–140 ns), stalling the core Reorder Buffer (ROB).

---

## 🖥️ Heterogeneous Evaluation Testbed

The experimental testbed encompasses four heterogeneous hardware tiers across server, client, and unified-memory architectures:

| Node Type | Processor Architecture | Physical Cores | Total L3 Cache | Memory Topology | Interconnect |
|:---:|:---|:---:|:---:|:---|:---|
| **Node A** | 2× Intel Xeon E5-2680 v4 (Broadwell-EP) | 28 cores (56 vCPUs) | 70 MB (35 MB/socket) | Dual-NUMA DDR4 (Quad-channel) | Intel QPI / UPI |
| **Node B** | 2× Intel Xeon E5-2620 v2 (Ivy Bridge-EP) | 12 cores (24 vCPUs) | 30 MB (15 MB/socket) | Dual-NUMA DDR3 (Quad-channel) | Intel QPI |
| **Node C** | Intel Core i5-8500T (Coffee Lake) | 6 physical cores | 9 MB shared L3 | Single-UMA DDR4 | Ring Bus |
| **Node D** | Apple Silicon M-Series (ARM64 Baseline) | 8 cores (4P + 4E) | Unified SLC | Unified LPDDR5 | High-bandwidth Fabric |

---

## ⚙️ Core Optimization Pillars

```
+---------------------------------------------------------------------------------------------------+
|                                 Hardware-Conscious Optimization Stack                             |
+---------------------------------------------------------------------------------------------------+
|  1. Hypervisor Scheduling : Proportional CPU Shares (500 Low vs 1000 Normal), vCPU Right-Sizing   |
|  2. Hardware Registers    : MSR 0x1A4 Prefetcher Suppression (Bits [3:0]=0xF via wrmsr)          |
|  3. Memory Virtualization : 1 GB HugePages (pdpe1gb, L1 dTLB 4-entry residency, zero EPT walks)   |
|  4. NUMA Topology         : Dual-Dataset Partitioning (AMAT 100ns -> 60ns, numa_balancing=0)      |
|  5. Cache Hierarchy       : 2.0 MB L3 Capacity Law & Strict SMT Logical Thread Elimination        |
+---------------------------------------------------------------------------------------------------+
```

### 1. The 2.0 MB L3 Cache Law & SMT Elimination
To execute at pipeline speed without main memory stalls, each thread's entire 2.0 MB scratchpad $B_i$ must reside in L3 cache:

$$T_{\max} = \min\left(N_{\text{phys}}, \left\lfloor \frac{C_{L3}}{2.0\text{ MB}} \right\rfloor\right)$$

- **Empirical Case Study (Node C):** $N_{\text{phys}}=6$, $C_{L3}=9.0\text{ MB} \implies T_{\max} = 4\text{ threads}$. Spawning 6 threads degrades aggregate throughput by **25%** due to cache way contention. Pinning 4 threads allocates 2.25 MB effective cache per thread, saturating execution pipelines.
- **SMT Hazard Mitigation:** Eliminating logical sibling threads prevents execution port serialization (competition for 256-bit AVX2/ALU ports) and L1/L2 cache pollution, removing a **15% to 20% execution stall penalty**.

### 2. NUMA Topology & Interconnect Optimization
In dual-socket platforms, cross-socket QPI traversal imposes severe penalties:

$$\tau_{\text{local}} \approx 60\text{ ns}, \quad \tau_{\text{remote}} \approx 140\text{ ns}$$

$$\text{AMAT}_{\text{interleaved}} = (1 - p_{\text{remote}})\tau_{\text{local}} + p_{\text{remote}}\tau_{\text{remote}} = 100\text{ ns} \quad (p_{\text{remote}}=0.5)$$

- **Dual-Dataset Partitioning:** We re-engineered the memory initialization to instantiate independent 2.3 GB replicas on each socket ($S_0$ on Node 0, $S_1$ on Node 1). With $p_{\text{remote}} \to 0$, sustained throughput surged on Node B from **1,712 units/s to 2,077 units/s (+21.3%)**.
- **Kernel NUMA Balancing Suppression:** `kernel.numa_balancing=0` prevents periodic PTE unmapping and soft page faults.

### 3. Memory Virtualization & 1 GB HugePages
Under VMware ESXi 8.0, TLB misses trigger two-dimensional guest/host page walks:

$$N_{\text{accesses}} = (4 + 1) \times 4 + 4 = 24\text{ memory references}$$

| Page Size ($P$) | Required TLB Entries ($E_{\text{TLB}}$ per socket) | Hardware STLB Coverage (1,536 entries) | Translation Penalty |
|:---:|:---:|:---:|:---|
| **4 KB** | 588,800 entries | < 0.26% coverage | ~100% TLB miss rate on stochastic reads |
| **2 MB** | 1,168 entries | 100% STLB coverage | Fits within L2 STLB |
| **1 GB (`pdpe1gb`)** | **3 entries** | **Resides in L1 dTLB** (4 dedicated entries/core) | **Zero address translation overhead (+5.0% IPC uplift)** |

### 4. Low-Level MSR Tuning & UEFI Lockdown Remediation
Intel hardware prefetchers (L2 Streamer, L2 Adjacent Line, DCU Streamer, DCU IP) double DRAM bus traffic by fetching non-contiguous lines.
- **Remediation:** Writing `0xF` to `MSR 0x1A4` (`MSR_PREFETCH_CONTROL`) disables all four engines.
- **UEFI Secure Boot Override:** UEFI Secure Boot forces the Linux kernel into `[integrity]` lockdown, returning `EPERM` on `/dev/cpu/*/msr`. Remediation requires disabling UEFI Secure Boot in ESXi Boot Options and applying `wrmsr -a 0x1a4 0xf`, stabilizing L3 hit ratios above **99.4%**.

### 5. Hypervisor Multi-Tenancy & Proportional Scheduling
Hosting 21 concurrent VMs on a 28-core ESXi host (67.12 GHz capacity) pushed CPU utilization to 95.0%, leaving only 3.5 GHz headroom:
- **vCPU Right-Sizing:** Right-sizing compute VMs from 18 vCPUs to 16 physical cores recovered **6.1 GHz** of unreserved compute capacity.
- **Proportional Shares:** Production VMs ($V_{\text{prod}}$, 1000 shares) preempt HPC VMs ($V_{\text{hpc}}$, 500 shares) at microsecond granularity during production bursts:

$$E_j = C_{\text{host}} \times \frac{S_j}{\sum_{i \in V_{\text{prod}} \cup V_{\text{hpc}}} S_i}$$

---

## 📊 Empirical Results

| Platform / Config | Threads | Memory & TLB Configuration | Throughput | Performance Delta |
|:---|:---:|:---|:---:|:---:|
| **Node A (Baseline Unoptimized)** | 56 (SMT) | 4 KB Interleaved | 8,420 units/s | Baseline |
| **Node A (Tuned Architecture)** | **28 (Physical)** | **1 GB NUMA + MSR 0x1A4** | **11,710 units/s** | **+39.1%** 🚀 |
| **Node B (Single Interleaved)** | 14 (SMT) | 2 MB Interleaved | 1,712 units/s | Baseline |
| **Node B (Dual-NUMA Partitioned)** | **12 (Physical)** | **2 MB NUMA + MSR 0x1A4** | **2,077 units/s** | **+21.3%** 🚀 |

---

## 🚀 Quick Start / Deployment Playbook

### 1. Provision 1 GB HugePages
```bash
# Execute scripts/hugepages_1gb_setup.sh
sudo bash scripts/hugepages_1gb_setup.sh
```

### 2. Disable Hardware Prefetchers via MSR
```bash
# Verify UEFI Secure Boot is disabled in ESXi, then run:
sudo bash scripts/disable_msr_prefetchers.sh
```

### 3. Enforce Static NUMA Topology
```bash
# Suppress kernel NUMA balancing daemon
sudo bash scripts/numa_tuning.sh
```

---

## 📁 Repository Structure

```
.
├── CITATION.cff                                        # Academic citation metadata
├── Hardware-Conscious-Performance-Engineering.pdf      # Complete IEEE TPDS-formatted research paper
├── LICENSE                                             # MIT Open-Source License
├── README.md                                           # Comprehensive research documentation
└── scripts/
    ├── disable_msr_prefetchers.sh                      # Kernel MSR 0x1A4 prefetcher suppression
    ├── hugepages_1gb_setup.sh                          # 1 GB HugePage dynamic provisioning
    └── numa_tuning.sh                                  # NUMA balancer suppression and pinning rules
```

---

## 📚 Citation

If you utilize this architectural framework, cache law formulation, or hypervisor co-scheduling methodology in your research, please cite:

```bibtex
@article{nastaran2026hardwareconscious,
  title={Hardware-Conscious Performance Engineering: Cache Hierarchy Optimization, NUMA Topologies, and Hypervisor Resource Scheduling for Memory-Hard HPC Workloads},
  author={Nastaran, Mohammadali},
  journal={IEEE Transactions on Parallel and Distributed Systems},
  year={2026},
  url={https://github.com/smellthedeath/Hardware-Conscious-Performance-Engineering}
}
```

---

<div align="center">
<sub>Crafted with microarchitectural precision by <b>Mohammadali Nastaran</b></sub>
</div>
