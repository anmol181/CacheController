`timescale 1ns / 1ps

module cache_top #(
    parameter AW = 16,
    parameter DW = 8,
    parameter B  = 4,
    parameter W  = 4,
    parameter S  = 8
)(
    input  wire          clk,
    input  wire          rst,

    // --- CPU Interface ---

    input  wire          cpu_valid,
    input  wire          cpu_ready,
    output wire          cache_ready,
    output wire          cache_valid,
    input  wire          cpu_we,
    input  wire [AW-1:0] cpu_addr,
    input  wire [DW-1:0] cpu_data_in,
    output wire [DW-1:0] cpu_data_out,

    output wire [AW-1:0] ar_addr,
    output wire [7:0]    ar_len,
    output wire          ar_valid,
    input  wire          ar_ready,

    input  wire [DW-1:0] r_data,
    input  wire          r_valid,
    input  wire          r_last,
    output wire          r_ready,

    output wire [AW-1:0] aw_addr,
    output wire [7:0]    aw_len,
    output wire          aw_valid,
    input  wire          aw_ready,

    output wire [DW-1:0] w_data,
    output wire          w_valid,
    output wire          w_last,
    input  wire          w_ready,

    input  wire [1:0]    bcode,
    input  wire          bvalid,
    output wire          bready
);

    wire          hit;
    wire          valid;
    wire          dirty;
    wire [AW-1:0] cache_miss_addr;
    wire [AW-1:0] cache_addr;
    wire          c_valid;
    wire          cache_read_en;
    wire          cache_write_en;
    wire          mem_read_en;
    wire          mem_write_en;
    wire [DW-1:0] cache_data_in;
    wire [DW-1:0] cache_data_out;

    cache_ctrl #(
        .AW(AW),
        .DW(DW),
        .B(B)
    ) cu(
        .clk(clk),
        .rst(rst),

        .cpu_addr(cpu_addr),
        .cpu_data_in(cpu_data_in),
        .cpu_valid(cpu_valid),
        .cpu_we(cpu_we),
        .cache_ready(cache_ready),
        .cache_valid(cache_valid),

        .hit(hit),
        .valid(valid),
        .dirty(dirty),

        .c_valid(c_valid),
        .cache_addr(cache_addr),
        .cache_data_in(cache_data_in),

        .cache_miss_addr(cache_miss_addr),
        .cache_data_out(cache_data_out),

        .cache_read_en(cache_read_en),
        .cache_write_en(cache_write_en),

        .mem_read_en(mem_read_en),
        .mem_write_en(mem_write_en),

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

        .bready(bready)
    );

    datapath #(
        .AW(AW),
        .DW(DW),
        .B(B),
        .W(W),
        .S(S)
    ) block(
        .clk(clk),
        .rst(rst),

        .c_valid(c_valid),
        .addr(cache_addr),

        .data_in(cache_data_in),
        .data_out(cache_data_out),

        .cache_read_en(cache_read_en),
        .cache_write_en(cache_write_en),

        .mem_read_en(mem_read_en),
        .mem_write_en(mem_write_en),

        .hit(hit),

        .valid(valid),
        .dirty(dirty),
        .cache_miss_addr(cache_miss_addr)
    );

    assign cpu_data_out = cache_data_out;

endmodule
