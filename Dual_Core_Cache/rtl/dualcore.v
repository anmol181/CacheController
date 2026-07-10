`timescale 1ns / 1ps

module dualcore #(
    parameter AW = 32,            // Address Width
    parameter DW = 8,             // Data Width (8-bit bytes)
    parameter W  = 8,             // Number of Ways
    parameter S  = 8,             // Number of Sets
    parameter B  = 4              // Block Size (Words)
)(
    input wire clk,
    input wire rst,


    // --- CPU 0 Interface ---

    input  wire          cpu_req0,
    input  wire          cpu_rw0,
    input  wire [AW-1:0] cpu_addr0,
    input  wire [DW-1:0] cpu_wdata0,
    output wire [DW-1:0] cpu_rdata0,
    output wire          cpu_ready0,


    // --- CPU 1 Interface ---

    input  wire          cpu_req1,
    input  wire          cpu_rw1,
    input  wire [AW-1:0] cpu_addr1,
    input  wire [DW-1:0] cpu_wdata1,
    output wire [DW-1:0] cpu_rdata1,
    output wire          cpu_ready1,


    // --- Shared Main Memory AXI Interface ---

    output wire [AW-1:0] mem_aw_addr,
    output wire [7:0]    mem_aw_len,
    output wire          mem_aw_valid,
    input  wire          mem_aw_ready,

    output wire [DW-1:0] mem_w_data,
    output wire          mem_w_last,
    output wire          mem_w_valid,
    input  wire          mem_w_ready,

    output wire [AW-1:0] mem_ar_addr,
    output wire [7:0]    mem_ar_len,
    output wire          mem_ar_valid,
    input  wire          mem_ar_ready,

    input  wire [DW-1:0] mem_r_data,
    input  wire          mem_r_last,
    input  wire          mem_r_valid,
    output wire          mem_r_ready
);

    localparam BW = $clog2(B);
    localparam SW = $clog2(S);
    localparam WW = $clog2(W);


    // Internal Wires: Core 0 <-> Interconnect

    wire          c0_snoop_hit_in;
    wire          c0_snoop_hit_out;
    wire          c0_cpu_hit;
    wire [AW-1:0] c0_snoop_addr;
    wire          c0_ask_snoop;
    wire [DW-1:0] c0_snoop_wdata;     // Data FROM interconnect TO core 0
    wire [DW-1:0] c0_snoop_rdata;     // Data FROM core 0 TO interconnect
    wire [1:0]    c0_snoop_signal;
    wire          c0_snoop_stall;
    wire          c0_snoop_req;
    wire          c0_snoop_dirty;
    wire          c0_snoop_valid;
    wire          c0_snoop_data_valid; // Added: Tells core 0 when snoop_rdata is valid

    // Core 0 AXI Wires
    wire [AW-1:0] c0_aw_addr;
    wire [7:0] c0_aw_len;
    wire c0_aw_valid;
    wire c0_aw_ready;
    wire [DW-1:0] c0_w_data;
    wire c0_w_last;
    wire c0_w_valid;
    wire c0_w_ready;
    wire [AW-1:0] c0_ar_addr;
    wire [7:0] c0_ar_len;
    wire c0_ar_valid;
    wire c0_ar_ready;
    wire [DW-1:0] c0_r_data;
    wire c0_r_last;
    wire c0_r_valid;
    wire c0_r_ready;


    // Internal Wires: Core 1 <-> Interconnect

    wire          c1_snoop_hit_in;
    wire          c1_snoop_hit_out;
    wire          c1_cpu_hit;
    wire [AW-1:0] c1_snoop_addr;
    wire          c1_ask_snoop;
    wire [DW-1:0] c1_snoop_wdata;
    wire [DW-1:0] c1_snoop_rdata;
    wire [1:0]    c1_snoop_signal;
    wire          c1_snoop_stall;
    wire          c1_snoop_req;
    wire          c1_snoop_dirty;
    wire          c1_snoop_valid;
    wire          c1_snoop_data_valid; // Added: Tells core 1 when snoop_rdata is valid

    // Core 1 AXI Wires
    wire [AW-1:0] c1_aw_addr;
    wire [7:0] c1_aw_len;
    wire c1_aw_valid;
    wire c1_aw_ready;
    wire [DW-1:0] c1_w_data;
    wire c1_w_last;
    wire c1_w_valid;
    wire c1_w_ready;
    wire [AW-1:0] c1_ar_addr;
    wire [7:0] c1_ar_len;
    wire c1_ar_valid;
    wire c1_ar_ready;
    wire [DW-1:0] c1_r_data;
    wire c1_r_last;
    wire c1_r_valid;
    wire c1_r_ready;



    // --- Core 0 Instantiation ---

    cache_top #(
        .AW(AW),
        .DW(DW),
        .W(W),
        .S(S),
        .B(B),
        .BW(BW),
        .SW(SW),
        .WW(WW)
    ) CORE_0 (
        .clk(clk),
        .rst(rst),
        // CPU
        .cpu_req(cpu_req0),
        .cpu_rw(cpu_rw0),
        .cpu_addr(cpu_addr0),
        .cpu_wdata(cpu_wdata0),
        .cpu_rdata(cpu_rdata0),
        .cpu_ready(cpu_ready0),

        // Snoop Interconnect Inputs
        .snoop_req(c0_snoop_req),
        .snoop_stall(c0_snoop_stall),
        .snoop_addr(c0_snoop_addr),
        .snoop_signal(c0_snoop_signal),
        .snoop_wdata(c0_snoop_wdata),
        .snoop_data_valid(c0_snoop_data_valid),
        .snoop_valid(c0_snoop_valid),

        // Snoop Interconnect Outputs
        .snoop_rdata(c0_snoop_rdata),
        .snoop_hit_in(c0_snoop_hit_in),
        .snoop_hit_out(c0_snoop_hit_out),
        .snoop_dirty(c0_snoop_dirty),
        .ask_snoop(c0_ask_snoop),
        .cpu_hit(c0_cpu_hit),

        // AXI Interface
        .aw_addr(c0_aw_addr),
        .aw_len(c0_aw_len),
        .aw_valid(c0_aw_valid),
        .aw_ready(c0_aw_ready),
        .w_data(c0_w_data),
        .w_last(c0_w_last),
        .w_valid(c0_w_valid),
        .w_ready(c0_w_ready),
        .ar_addr(c0_ar_addr),
        .ar_len(c0_ar_len),
        .ar_valid(c0_ar_valid),
        .ar_ready(c0_ar_ready),
        .r_data(c0_r_data),
        .r_last(c0_r_last),
        .r_valid(c0_r_valid),
        .r_ready(c0_r_ready)
    );


    // --- Core 1 Instantiation ---

    cache_top #(
        .AW(AW),
        .DW(DW),
        .W(W),
        .S(S),
        .B(B),
        .BW(BW),
        .SW(SW),
        .WW(WW)
    ) CORE_1 (
        .clk(clk),
        .rst(rst),
        // CPU
        .cpu_req(cpu_req1),
        .cpu_rw(cpu_rw1),
        .cpu_addr(cpu_addr1),
        .cpu_wdata(cpu_wdata1),
        .cpu_rdata(cpu_rdata1),
        .cpu_ready(cpu_ready1),

        // Snoop Interconnect Inputs
        .snoop_req(c1_snoop_req),
        .snoop_stall(c1_snoop_stall),
        .snoop_addr(c1_snoop_addr),
        .snoop_signal(c1_snoop_signal),
        .snoop_wdata(c1_snoop_wdata),
        .snoop_data_valid(c1_snoop_data_valid),
        .snoop_valid(c1_snoop_valid),

        // Snoop Interconnect Outputs
        .snoop_rdata(c1_snoop_rdata),
        .snoop_hit_in(c1_snoop_hit_in),
        .snoop_hit_out(c1_snoop_hit_out),
        .snoop_dirty(c1_snoop_dirty),
        .ask_snoop(c1_ask_snoop),
        .cpu_hit(c1_cpu_hit),

        // AXI Interface
        .aw_addr(c1_aw_addr),
        .aw_len(c1_aw_len),
        .aw_valid(c1_aw_valid),
        .aw_ready(c1_aw_ready),
        .w_data(c1_w_data),
        .w_last(c1_w_last),
        .w_valid(c1_w_valid),
        .w_ready(c1_w_ready),
        .ar_addr(c1_ar_addr),
        .ar_len(c1_ar_len),
        .ar_valid(c1_ar_valid),
        .ar_ready(c1_ar_ready),
        .r_data(c1_r_data),
        .r_last(c1_r_last),
        .r_valid(c1_r_valid),
        .r_ready(c1_r_ready)
    );


    // --- Snoop Interconnect Instantiation ---

    snoop_interconnect #(
        .AW(AW),
        .DW(DW),
        .B(B)
    ) INTERCONNECT (
        .clk(clk),
        .rst(rst),

        // Core 0 Snoop Wires
        .cpu_req0(cpu_req0),
        .snoop_req0(c0_snoop_req),
        .cpu_hit0(c0_cpu_hit),
        .snoop_hit_in0(c0_snoop_hit_in),
        .snoop_hit_out0(c0_snoop_hit_out),
        .cpu_rw0(cpu_rw0),
        .cpu_addr0(cpu_addr0),
        .snoop_addr0(c0_snoop_addr),
        .snoop_signal0(c0_snoop_signal),
        .snoop_stall0(c0_snoop_stall),

        // Data crossover: Interconnect's rdata0 output goes to Core 0's wdata input
        .snoop_rdata0(c0_snoop_wdata),
        .snoop_wdata0(c0_snoop_rdata),
        .snoop_ask0(c0_ask_snoop),
        .snoop_dirty0(c0_snoop_dirty),
        .snoop_valid0(c0_snoop_valid),
        .snoop_data_valid0(c0_snoop_data_valid),


        // Core 1 Snoop Wires
        .cpu_req1(cpu_req1),
        .snoop_req1(c1_snoop_req),
        .cpu_hit1(c1_cpu_hit),
        .snoop_hit_in1(c1_snoop_hit_in),
        .snoop_hit_out1(c1_snoop_hit_out),
        .cpu_rw1(cpu_rw1),
        .cpu_addr1(cpu_addr1),
        .snoop_addr1(c1_snoop_addr),
        .snoop_signal1(c1_snoop_signal),
        .snoop_stall1(c1_snoop_stall),

        // Data crossover: Interconnect's rdata1 output goes to Core 1's wdata input
        .snoop_rdata1(c1_snoop_wdata),
        .snoop_wdata1(c1_snoop_rdata),
        .snoop_ask1(c1_ask_snoop),
        .snoop_dirty1(c1_snoop_dirty),
        .snoop_valid1(c1_snoop_valid),
        .snoop_data_valid1(c1_snoop_data_valid),

        // Core 0 AXI Wires
        .mem_aw_addr0(c0_aw_addr),
        .mem_aw_len0(c0_aw_len),
        .mem_aw_valid0(c0_aw_valid),
        .mem_aw_ready0(c0_aw_ready),
        .mem_w_data0(c0_w_data),
        .mem_w_last0(c0_w_last),
        .mem_w_valid0(c0_w_valid),
        .mem_w_ready0(c0_w_ready),
        .mem_ar_addr0(c0_ar_addr),
        .mem_ar_len0(c0_ar_len),
        .mem_ar_valid0(c0_ar_valid),
        .mem_ar_ready0(c0_ar_ready),
        .mem_r_data0(c0_r_data),
        .mem_r_last0(c0_r_last),
        .mem_r_valid0(c0_r_valid),
        .mem_r_ready0(c0_r_ready),

        // Core 1 AXI Wires
        .mem_aw_addr1(c1_aw_addr),
        .mem_aw_len1(c1_aw_len),
        .mem_aw_valid1(c1_aw_valid),
        .mem_aw_ready1(c1_aw_ready),
        .mem_w_data1(c1_w_data),
        .mem_w_last1(c1_w_last),
        .mem_w_valid1(c1_w_valid),
        .mem_w_ready1(c1_w_ready),
        .mem_ar_addr1(c1_ar_addr),
        .mem_ar_len1(c1_ar_len),
        .mem_ar_valid1(c1_ar_valid),
        .mem_ar_ready1(c1_ar_ready),
        .mem_r_data1(c1_r_data),
        .mem_r_last1(c1_r_last),
        .mem_r_valid1(c1_r_valid),
        .mem_r_ready1(c1_r_ready),

        // Shared Main Memory AXI Bus (Goes out of module)
        .mem_aw_addr(mem_aw_addr),
        .mem_aw_len(mem_aw_len),
        .mem_aw_valid(mem_aw_valid),
        .mem_aw_ready(mem_aw_ready),
        .mem_w_data(mem_w_data),
        .mem_w_last(mem_w_last),
        .mem_w_valid(mem_w_valid),
        .mem_w_ready(mem_w_ready),
        .mem_ar_addr(mem_ar_addr),
        .mem_ar_len(mem_ar_len),
        .mem_ar_valid(mem_ar_valid),
        .mem_ar_ready(mem_ar_ready),
        .mem_r_data(mem_r_data),
        .mem_r_last(mem_r_last),
        .mem_r_valid(mem_r_valid),
        .mem_r_ready(mem_r_ready)
    );

endmodule