`timescale 1ns / 1ps

module datapath #(
    parameter AW = 16,
    parameter DW = 32,
    parameter B  = 4,               
    parameter W  = 4,               
    parameter S  = 8,               
    parameter WW = $clog2(W),
    parameter SW = $clog2(S),
    parameter BW = $clog2(B)
)(
    input  wire          clk,
    input  wire          rst,

    input  wire [AW-1:0] addr,
    input  wire [DW-1:0] data_in,
    // input  wire [(DW/8)-1:0] cpu_req_wstrb, // Byte Enables
    
    // --- Control Unit Interface 
    // --- Inputs ---
    input  wire          cache_read_en,
    input  wire          cache_write_en,
    input  wire          mem_read_en,
    input  wire          mem_write_en,   
    input  wire          miss,

    // --- Outputs ---
    output reg           hit,
    output wire          dirty,
    output wire          valid,
    output reg  [DW-1:0] data_out,
    output wire [AW-1:0] cache_miss_addr
);

endmodule