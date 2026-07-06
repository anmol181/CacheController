`timescale 1ns / 1ps

module cache_top #(
    parameter AW = 32,
    parameter DW = 8,
    parameter B  = 4,
    parameter S  = 8,
    parameter W  = 8
)(
    input  wire          clk,
    input  wire          rst,

    // --- CPU Interface ---
    input  wire          cpu_req,
    input  wire          cpu_rw,
    input  wire [AW-1:0] cpu_addr,
    input  wire [DW-1:0] cpu_wdata,
    output wire [DW-1:0] cpu_rdata,
    output wire          cpu_ready,

    // --- Snoop Interconnect Interface ---

    // Inputs from Interconnect
    input  wire          snoop_req,
    input  wire          snoop_stall, // Replaced snoop_ask. Freezes Ctrl & switches DP mux
    input  wire [AW-1:0] snoop_addr,
    input  wire [1:0]    snoop_signal,
    input  wire [DW-1:0] snoop_wdata, // Data streaming IN from another cache
    input  wire          snoop_data_valid,

    // Outputs to Interconnect
    output wire [DW-1:0] snoop_rdata, // Data streaming OUT to another cache
    output wire          snoop_hit,   // Tells interconnect this cache has the requested line
    output wire          snoop_dirty, // Tells interconnect the hit line is Modified (needs write-back)
    output wire          ask_snoop,   // Tells interconnect this cache is ready to receive data
    output wire          cpu_hit,     // Exposed to tell interconnect if a local hit occurred during snoop check
    output wire          snoop_valid,  // Tells interconnect the snoop_rdata is valid and can be used

    // --- memory interface ---
    output wire [AW-1:0] aw_addr,
    output wire [7:0]    aw_len,
    output wire          aw_valid,
    input  wire          aw_ready,

    output wire [DW-1:0] w_data,
    output wire          w_last,
    output wire          w_valid,
    input  wire          w_ready,

    output wire [AW-1:0] ar_addr,
    output wire [7:0]    ar_len,
    output wire          ar_valid,
    input  wire          ar_ready,

    input  wire [DW-1:0] r_data,
    input  wire          r_last,
    input  wire          r_valid,
    output wire          r_ready
);

    wire [AW-1:0] cache_addr_int;
    wire [DW-1:0] cache_wdata_int;
    wire [DW-1:0] cache_rdata_int;

    wire          cache_req_int;
    wire          cache_rw_int;
    wire          mem_req_int;
    wire          mem_rw_int;

    wire [AW-1:0] cache_miss_addr_int;
    wire [1:0]    cache_miss_state_int;

    wire          hit_int;

    assign cpu_hit = hit_int;

    wire snoop_hitt;
    assign snoop_hit = snoop_hitt;

    cache_ctrl #(
        .AW(AW), .DW(DW), .W(W), .S(S), .B(B)
    ) CTRL (
        .clk(clk),
        .rst(rst),

        // CPU Ports
        .cpu_req(cpu_req),
        .cpu_rw(cpu_rw),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready),

        // Snoop Ports (Control)
        .ask_snoop(ask_snoop),
        .snoop_stall(snoop_stall),
        .snoop_data_in(snoop_wdata), // Route incoming cache-to-cache data here
        .snoop_data_valid(snoop_data_valid), // Tells controller when snoop_wdata is valid

        // Internal Datapath Status
        .cache_miss_addr(cache_miss_addr_int),
        .miss_mesi_state(cache_miss_state_int),
        .hit(hit_int),
        .snoop_hit(snoop_hitt),

        // Internal Datapath Control
        .cache_addr(cache_addr_int),
        .cache_wdata(cache_wdata_int),
        .cache_rdata(cache_rdata_int),
        .cache_req(cache_req_int),
        .cache_rw(cache_rw_int),
        .mem_req(mem_req_int),
        .mem_rw(mem_rw_int),

        // AXI Master Ports
        .ar_valid(ar_valid),
        .ar_addr(ar_addr),
        .ar_len(ar_len),
        .ar_ready(ar_ready),

        .r_valid(r_valid),
        .r_data(r_data),
        .r_last(r_last),
        .r_ready(r_ready),

        .aw_addr(aw_addr),
        .aw_valid(aw_valid),
        .aw_ready(aw_ready),
        .aw_len(aw_len),

        .w_valid(w_valid),
        .w_data(w_data),
        .w_ready(w_ready),
        .w_last(w_last)
    );

    datapath #(
        .AW(AW), .DW(DW), .B(B), .S(S), .W(W)
    ) DP (
        .clk(clk),
        .rst(rst),

        // Controller Memory Commmands
        .mem_req(mem_req_int),
        .mem_rw(mem_rw_int),
        .cache_req(cache_req_int),
        .cache_rw(cache_rw_int),
        .cache_addr(cache_addr_int),
        .cache_wdata(cache_wdata_int),
        .cache_rdata(cache_rdata_int),

        // Snoop Interconnect Commands
        .snoop_req(snoop_req),
        .snoop_stall(snoop_stall),
        .snoop_addr(snoop_addr),
        .snoop_signal(snoop_signal),
        .snoop_rdata(snoop_rdata),

        // Status Outputs
        .cache_miss_addr(cache_miss_addr_int),
        .cache_miss_state(cache_miss_state_int),
        .snoop_hit(snoop_hitt),
        .snoop_dirty(snoop_dirty),
        .hit(hit_int),
        .snoop_valid(snoop_valid)
    );

endmodule