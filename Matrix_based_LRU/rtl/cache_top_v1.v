`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/07/2026 01:45:40 PM
// Design Name: 
// Module Name: cache_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module cache_top #(
    parameter AW = 16,
    parameter DW = 8,
    parameter B = 4, // block size = B*DW
    parameter W = 4, // no. of ways
    parameter S = 8  // no. of blocks
)(
    input                   clk,
    input                   rst,
    
    // cpu signals
    input [AW - 1 : 0]      cpu_addr,
    input                   cpu_read_en,
    input                   cpu_write_en,
    input [DW - 1 : 0]      cpu_data_in,
    output[DW - 1 : 0]      cpu_data_out,

    // axi signals for memory
    output [AW - 1 : 0]      ar_addr,
    output [7 : 0]           ar_len,
    input                    ar_ready,
    output                   ar_valid,

    input  [DW - 1 : 0]      r_data,
    input                    r_last,
    output                   r_ready,
    input                    r_valid,

    output [AW - 1 : 0]      aw_addr,
    output [7 : 0]           aw_len,
    input                    aw_ready,
    output                   aw_valid,

    output [DW - 1 : 0]      w_data,
    output                   w_last,
    input                    w_ready,
    output                   w_valid
);

    wire hit;
    wire miss;
    wire cache_read_en;
    wire cache_write_en;
    wire mem_read_en;
    wire mem_write_en;
    
    wire [AW-1 : 0] cache_address;
    wire [DW-1 : 0] cache_read_data;
    wire [DW-1 : 0] cache_write_data;

    wire lru_valid;
    wire lru_dirty;
    wire [AW-1 : 0] lru_miss_addr;

    assign cpu_data_out = cache_read_data;

    cache_ctrl #(
        .AW(AW), .DW(DW), .B(B), .W(W), .S(S)
    ) cache_controller (
        .clk(clk),
        .rst(rst),

        .cpu_read_en(cpu_read_en),
        .cpu_write_en(cpu_write_en),
        .cpu_addr(cpu_addr),
        .cpu_data_in(cpu_data_in),

        .ar_addr(ar_addr),
        .ar_len(ar_len),
        .ar_ready(ar_ready),
        .ar_valid(ar_valid),

        .r_data(r_data),
        .r_last(r_last),
        .r_ready(r_ready),
        .r_valid(r_valid),

        .aw_addr(aw_addr),
        .aw_len(aw_len),
        .aw_ready(aw_ready),
        .aw_valid(aw_valid),

        .w_data(w_data),
        .w_last(w_last),
        .w_ready(w_ready),
        .w_valid(w_valid),

        .mem_read_en(mem_read_en),   
        .mem_write_en(mem_write_en), 
        .cache_read_en(cache_read_en),
        .cache_write_en(cache_write_en),
        .cache_read_data(cache_read_data),
        .cache_write_data(cache_write_data),
        .cache_address(cache_address),

        .hit(hit),
        .miss(miss),
        .valid(lru_valid),
        .dirty(lru_dirty),
        .cache_miss_addr(lru_miss_addr)
    );

    cache_block_v1 #(
        .AW(AW), .DW(DW), .B(B), .W(W), .S(S)
    ) block (
        .clk(clk),
        .rst(rst),

        .cpu_read_en(cpu_read_en),
        .cpu_write_en(cpu_write_en),

        .mem_read_en(mem_read_en),
        .mem_write_en(mem_write_en),

        .addr(cache_address),
        .data_in(cache_write_data),
        .data_out(cache_read_data),
        
        .hit(hit),
        .miss(miss),
        .v(lru_valid),
        .d(lru_dirty),
        .cache_miss_addr(lru_miss_addr)
    );

endmodule
