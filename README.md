# N-Way Set Associative Cache Controller

A Verilog-based n-way set associative cache controller featuring an integrated Least Recently Used (LRU) replacement policy, designed for a custom 16-bit CPU architecture.

## Overview

This project implements a parameterized cache memory subsystem in RTL. The current design features an n-way set associative architecture with the LRU eviction logic built directly into the main cache controller, ensuring optimal cache hit rates for localized memory access patterns within a 16-bit processor environment.

## Key Features

*   **Custom 16-bit Architecture Support:** Designed to interface seamlessly with custom 16-bit CPU datapaths and memory hierarchies.
*   **Parameterized Configuration:** Configurable number of ways, cache size, and block size via top-level Verilog parameters.
*   **Integrated LRU Eviction:** precise Least Recently Used tracking is embedded within the core cache control logic to intelligently replace the oldest accessed blocks in a fully occupied set.
*   **Synthesizable RTL:** Written in standard Verilog, suitable for synthesis and integration into larger SoC or custom processor designs.

## Configuration Parameters

The cache controller can be tailored to specific system requirements by modifying the top-level parameters:

| Parameter | Description | Default Value |
| :--- | :--- | :--- |
| `ADDR_WIDTH` | Width of the system memory address bus | 16 |
| `DATA_WIDTH` | Width of the data bus | 16 |
| `NUM_WAYS` | Number of associative ways per set (n) | 4 |
| `CACHE_SIZE` | Total capacity of the cache (in bytes/words) | 1024 |
| `BLOCK_SIZE` | Number of words per cache line | 4 |

## LRU Implementation Details

The LRU replacement policy operates independently for each cache set and is managed directly by the main cache controller. 

*   **Cache Hit/Allocation:** Whenever a cache hit occurs, or a new block is allocated, the controller updates the internal LRU state for that specific set, protecting the most recently accessed block from eviction and shifting the priority down the hierarchy.
*   **Cache Miss:** On a cache miss where the targeted set is fully occupied, the integrated tracking logic identifies the specific "way" that has remained unaccessed for the longest duration and flags it for replacement.

## Simulation and Testing

Verification is handled via Verilog testbenches. To validate the cache behavior and the integrated LRU replacement policy:

1. Compile the main controller and memory array source files in your preferred Verilog simulator (e.g., Vivado, ModelSim, or Icarus Verilog).
2. Execute the top-level testbench to simulate the cache subsystem interacting with a simulated main memory and CPU request generator.
3. Observe the cache hit/miss signals and internal state variables to confirm the correct "way" is evicted during repetitive access patterns.
