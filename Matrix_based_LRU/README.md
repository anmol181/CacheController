# High-Performance 4-Way Matrix LRU Cache Controller


![Language](https://img.shields.io/badge/Language-Verilog_IEEE_1364-blue.svg)

![Interface](https://img.shields.io/badge/Interface-AXI4-green.svg)

![Status](https://img.shields.io/badge/Status-Verified_&_Synthesizable-brightgreen.svg)


## 📌 Overview

This repository contains the RTL implementation and verification environment for a fully synthesizable, cycle-accurate, Dual-Purpose L1 Cache Subsystem. Designed with a strict separation of control and datapath logic, the architecture features a custom Matrix-based Least Recently Used (LRU) replacement policy and a fully compliant AXI4 memory interface for robust system-on-chip (SoC) integration.


## ✨ Key Architectural Features


### 1. Advanced Datapath & Control Segregation

* **0-Latency CPU Interface:** The CPU-to-Cache frontend utilizes a highly optimized custom interface (Address, Data, Enables) to achieve immediate, 1-cycle reads via strictly combinational hit-detection paths.

* **Write-Allocate Policy:** Enforces strict write-allocation to prevent partial block corruption (mitigating "Ghost Hits" against uninitialized SRAM). On a write miss, the controller stalls the CPU, fetches a complete 4-word block via AXI4, and subsequently executes the synchronous store.

* **Hazard Mitigation:** SRAM write ports are explicitly decoupled and mapped strictly to FSM-generated control signals, preventing state corruption mid-burst.


### 2. Matrix LRU Implementation

Traditional counter-based LRU policies suffer from deep combinational logic paths. This design utilizes a high-speed **Matrix LRU** algorithm:

* **4-Way Associativity:** Implemented using a parameterized 4x4 matrix of flip-flops per cache set.

* **Synchronous State Updates:** Upon a hit or cache fill to Way `N`, the controller asserts Row `N` and clears Column `N`.

* **Combinational Eviction Search:** Eviction targets are resolved in a single cycle using Verilog reduction NOR (`~|`) logic to identify the row containing all zeros.


### 3. Protocol-Compliant AXI4 Memory Interface

The cache acts as a bus master to a shared main memory resource, handling complex arbitration and transaction scaling:

* **AXI4 Master (Cache Controller):** Initiates dynamic `ar_len` and `aw_len` burst transactions for cache line fills and dirty writebacks, featuring robust handling of asynchronous `r_valid` drops and `r_last` synchronization.

* **AXI4 Slave (Main Memory):** A standalone, non-pipelined verification memory module featuring independent Read/Write FSMs and synchronous BRAM inference to prevent unintended latches.


## 🧪 System Verification


The repository includes a comprehensive, cycle-accurate Verilog testbench (`tb_cache_system.v`) that fully integrates the L1 Cache hierarchy with the AXI4 Main Memory. 


**Verification Highlights:**

* **Race Condition Mitigation:** Deployed synchronous `#1` delays for CPU stimulus to permanently resolve delta-cycle infinite loops and ensure accurate signal sampling.

* **AXI Deadlock Prevention:** Applied direct `bready` and `w_ready` protocol assertions to prevent stalls during Write-Allocate dirty evictions.

* **Automated Test Suite:** Achieved 100% coverage on critical edge cases, including:

  * Cold Read/Write Misses & Write-Allocations

  * Set Conflicts and Dirty Line Evictions (Writebacks)

  * 0-Latency Read/Write Hits

  * Clean Line Evictions (AXI write burst bypass)


## 📂 Directory Structure


├── rtl/

│   ├── cache_top.v          # Top-level wrapper routing datapath and FSM

│   ├── cache_ctrl.v         # AXI4 Control Finite State Machine

│   ├── cache_block_v1.v     # Datapath containing SRAM arrays, hit-detection, and Matrix LRU

│   └── memory_v1.v          # AXI4 Slave Main Memory module

├── tb/

│   ├── tb_cache_system.v    # Automated cycle-accurate system testbench

│   └── tb_memory.v          # Standalone AXI4 memory verification

└── README.md
