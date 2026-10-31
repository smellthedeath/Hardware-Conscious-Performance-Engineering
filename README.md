# Hardware-Conscious Performance Engineering: Cache Hierarchy, NUMA, and Hypervisor Optimization

[![IEEE Format](https://img.shields.io/badge/Format-IEEE%20Transactions-blue.svg)](https://www.ieee.org)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20VMware%20ESXi%208.0-orange.svg)]()
[![Workload](https://img.shields.io/badge/Workload-Memory--Bound%20HPC%20Benchmark-green.svg)]()
[![HugePages: 1GB](https://img.shields.io/badge/Memory-1%20GB%20HugePages-4CAF50.svg)]()
[![Throughput Gain](https://img.shields.io/badge/Throughput%20Gain-%2B35%25%20to%20%2B40%25-brightgreen.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

This repository contains the rigorous scientific research paper, architectural benchmarks, and low-level system configuration guides titled **"Hardware-Conscious Performance Engineering: Cache Hierarchy Optimization, NUMA Topologies, and Hypervisor Resource Scheduling for Memory-Hard HPC Workloads"**. 

The study evaluates stochastic, non-linear memory-bound high-performance computing (HPC) workloads executed across heterogeneous x86-64 and ARM64 infrastructures hosted on enterprise-grade hypervisors (VMware ESXi 8.0).

*Author:* **Mohammadali Nastaran**  
*Principal HPC Systems Architect and Senior Linux Kernel Engineer*

[📄 **Read Full Paper (PDF)**](./Hardware-Conscious-Performance-Engineering.pdf) • [📄 **LaTeX Source Code**](./hpc_performance_engineering.tex) • [🛠️ **Automation Scripts**](./scripts)

---

## 🚀 Key Architectural Contributions

1. **The 2.0 MB L3 Cache Law:** Establishes the mathematical capacity constraint $T_{\text{max}} = \min(N_{\text{phys}}, \lfloor C_{\text{L3}} / 2.0\text{ MB} \rfloor)$ to eliminate cache eviction thrashing.
2. **SMT/HyperThreading Elimination:** Proves why pinning execution threads exclusively to physical cores avoids L1/L2 cache pollution and AVX2 execution port contention.
3. **NUMA Domain Partitioning:** Mitigates the $140\text{ ns}$ remote QPI/UPI penalty via dual-dataset replication ($\tau_{\text{local}} \approx 60\text{ ns}$) and disables kernel automatic NUMA balancing (`kernel.numa_balancing=0`).
4. **1 GB HugePage TLB Consolidation:** Replaces 4 KB and 2 MB pages with native `pdpe1gb` huge pages (3 entries per socket) to eliminate 2D guest-plus-EPT page table walks.
5. **MSR Prefetcher Control:** Disables speculative hardware stream prefetchers (`MSR 0x1A4`) after resolving UEFI Secure Boot lockdown conflicts.
6. **Hypervisor Proportional Scheduling:** Right-sizes vCPU allocations and applies `Low` ($500$) CPU shares on VMware ESXi to recover $6.1\text{ GHz}$ of host compute capacity per server while protecting production SLAs.

---

## 📊 Heterogeneous Hardware Testbed Matrix

| Node Type | Processor Architecture | Physical Cores | Total L3 Cache | Memory Topology | Interconnect |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Node A** | 2$\times$ Intel Xeon E5-2680 v4 (Broadwell-EP) | 28 | 70 MB | Dual-NUMA DDR4 | Intel QPI / UPI |
| **Node B** | 2$\times$ Intel Xeon E5-2620 v2 (Ivy Bridge-EP) | 12 | 30 MB | Dual-NUMA DDR3 | Intel QPI |
| **Node C** | Intel Core i5-8500T (Coffee Lake) | 6 | 9 MB | Single-UMA DDR4 | Ring Bus |
| **Node D** | Apple Silicon M1/M2 (ARM64) | 8 | Unified SLC | Unified LPDDR5 | Fabric Interconnect |

---

## 📈 Empirical Benchmark Evaluation

| Platform / Config | Threads | Memory & TLB State | Throughput | Performance Uplift |
| :--- | :---: | :--- | :---: | :---: |
| **Node A (Baseline Unoptimized)** | 56 (SMT) | 4 KB Interleaved | 8,420 units/s | Baseline |
| **Node A (Tuned Architecture)** | **28 (Physical)** | **1 GB NUMA + MSR 0x1A4** | **11,710 units/s** | **+39.1%** 🚀 |
| **Node B (Single Interleaved)** | 14 (2 SMT) | 2 MB Interleaved | 1,712 units/s | Baseline |
| **Node B (Dual-NUMA Partitioned)** | **12 (Physical)** | **2 MB NUMA + MSR 0x1A4** | **2,077 units/s** | **+21.3%** 🚀 |

---

## 🛠️ Quick System Tuning Quickstart (Linux / ESXi)

Execute the following low-level configurations on your compute nodes to replicate the benchmark environment (or run the automated scripts in the `scripts/` directory):

```bash
# 1. Disable kernel automatic NUMA balancing
sudo sysctl -w kernel.numa_balancing=0

# 2. Configure memory management and drop slab caches for huge page allocation
sudo sysctl -w vm.swappiness=0
echo 3 | sudo tee /proc/sys/vm/drop_caches

# 3. Provision 1 GB HugePages (3 per NUMA node)
echo 3 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-1048576kB/nr_hugepages
echo 3 | sudo tee /sys/devices/system/node/node1/hugepages/hugepages-1048576kB/nr_hugepages

# 4. Suppress speculative hardware prefetchers via MSR 0x1A4 (requires lockdown=none)
sudo modprobe msr
sudo wrmsr -a 0x1a4 0xf
```

---

## 📁 Repository Structure

```
.
├── CITATION.cff                                        # Academic citation metadata
├── Hardware-Conscious-Performance-Engineering.pdf      # Complete IEEE TPDS research paper
├── LICENSE                                             # MIT License
├── README.md                                           # Repository documentation
├── hpc_performance_engineering.bib                     # BibTeX bibliography
├── hpc_performance_engineering.tex                     # Full IEEEtran LaTeX source code
├── references.bib                                      # BibTeX reference library
└── scripts/
    ├── disable_msr_prefetchers.sh                      # Kernel MSR 0x1A4 prefetcher suppression
    ├── hugepages_1gb_setup.sh                          # 1 GB HugePage dynamic provisioning
    └── numa_tuning.sh                                  # NUMA balancer suppression & affinity rules
```

---

## 📄 Compilation & LaTeX Source

To compile the IEEE two-column paper locally from the included LaTeX source (`hpc_performance_engineering.tex`):

```bash
pdflatex hpc_performance_engineering.tex
bibtex hpc_performance_engineering
pdflatex hpc_performance_engineering.tex
pdflatex hpc_performance_engineering.tex
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

## 📜 License

This academic work, reproduction scripts, and documentation are released under the [MIT License](LICENSE).
