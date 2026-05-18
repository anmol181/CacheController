# N-Way Set Associative Cache Controller

A standalone Verilog-based n-way set associative cache controller featuring an integrated Least Recently Used (LRU) replacement policy.

## Overview

This project implements a highly parameterized, independent cache memory subsystem in RTL. Designed as a standalone IP block, it can be integrated into various custom CPU architectures and memory hierarchies. The design features an n-way set associative architecture with the LRU eviction logic built directly into the main cache controller, optimizing cache hit rates for localized memory access patterns.

## Key Features

*   **Standalone IP Block:** Designed as a modular, independent component ready for integration into larger SoC or custom processor datapaths.
*   **Parameterized Configuration:** Highly adaptable to different system architectures. The address width, data width, number of ways, cache size, and block size are all configurable via top-level Verilog parameters.
*   **Integrated LRU Eviction:** Precise Least Recently Used tracking is embedded within the core cache control logic to intelligently replace the oldest accessed blocks in a fully occupied set.
*   **Synthesizable RTL:** Written in standard Verilog, ensuring compatibility with standard synthesis tools.

## Configuration Parameters

The cache controller can be tailored to specific system requirements (defaulting to a 16-bit architecture) by modifying the top-level parameters:

| Parameter | Description | Default Value |
| :--- | :--- | :--- |
| `ADDR_WIDTH` | Width of the system memory address bus | 8 |
| `DATA_WIDTH` | Width of the data bus | 8 |
| `NUM_WAYS` | Number of associative ways per set (n) | 4 |
| `CACHE_SIZE` | Total capacity of the cache (in bytes/words) | 32 |
| `BLOCK_SIZE` | Number of words per cache line | 1 |

## LRU Implementation Details

The LRU replacement policy operates independently for each cache set and is managed directly by the main cache controller. 

*   **Cache Hit/Allocation:** Whenever a cache hit occurs, or a new block is allocated, the controller updates the internal LRU state for that specific set. This protects the most recently accessed block from eviction and shifts the priority down the hierarchy.
*   **Cache Miss:** On a cache miss where the targeted set is fully occupied, the integrated tracking logic identifies the specific "way" that has remained unaccessed for the longest duration and flags it for replacement.
