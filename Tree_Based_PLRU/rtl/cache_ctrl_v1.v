`timescale 1ns / 1ps

module cache_ctrl #(
    parameter AW = 16,
    parameter DW = 32,
    parameter B  = 4
)(
    input  wire          clk,
    input  wire          rst,

    // Request Channel
    input  wire          cpu_valid,
    input  wire          cpu_we,
    output reg           cache_ready,   // Cache accepts request
    
    // Response Channel(to be added)
    // output reg           cache_resp_valid,  // Cache has read data ready
    // input  wire          cpu_resp_ready,    // CPU is ready to accept read data

    // --- Datapath Interface ---
    input  wire          hit,
    input  wire          dirty,
    input  wire          valid,
    input  wire [AW-1:0] cache_miss_addr,
    output reg           cache_read_en,
    output reg           cache_write_en,
    output reg           mem_read_en,
    output reg           mem_write_en,
    output reg           miss,

    // --- AXI4 Master Interface (To Main Memory) ---
    output reg  [AW-1:0] ar_addr,
    output reg  [7:0]    ar_len,
    output reg           ar_valid,
    input  wire          ar_ready,

    input  wire          r_valid,
    input  wire          r_last,
    output reg           r_ready,
    
    output reg  [AW-1:0] aw_addr,
    output reg  [7:0]    aw_len,
    output reg           aw_valid,
    input  wire          aw_ready,

    output reg           w_valid,
    output reg           w_last,
    input  wire          w_ready,
    
    input  wire          bvalid,
    output reg           bready
);

endmodule
