`timescale 1ns / 1ps

module datapath#(
    parameter AW = 16,
    parameter DW = 8,
    parameter B = 4,
    parameter S = 8,
    parameter W = 8,
    parameter BW = $clog2(B),
    parameter SW = $clog2(S),
    parameter WW = $clog2(W)
)(
    input clk,
    input rst,

    input mem_req,
    input mem_rw,
    input cache_req,
    input cache_rw,
    input [AW-1:0] cache_addr,
    input [DW-1:0] cache_wdata,

    // input tag_w,
    // input state_cpu_w,
    // input data_w,

    // Snoop Interface
    input snoop_req,
    input snoop_stall,
    input [AW-1:0] snoop_addr,
    input [1:0] snoop_signal,
    // input state_snoop_w,

    output reg [DW-1:0] cache_rdata,
    output reg [DW-1:0] snoop_rdata,
    output reg [AW-1:0] cache_miss_addr,
    output reg [1:0] cache_miss_state,
    output reg snoop_hit,
    output reg hit
);

    localparam tag_len = AW - BW - SW;
    localparam m = 2'b11;
    localparam e = 2'b10;
    localparam s = 2'b01;
    localparam i = 2'b00;

    reg [W-1:0] tag_we;
    reg [W-1:0] state_cpu_we;
    reg [W-1:0] data_we;
    reg [W-1:0] state_snoop_we;

    reg          s1_cache_req;
    reg          s1_cache_rw;
    reg          s1_mem_req;
    reg          s1_mem_rw;
    reg          s1_snoop_req;
    reg [1:0]    s1_snoop_signal;
    reg [AW-1:0] s1_cache_addr;
    reg [AW-1:0] s1_snoop_addr;
    reg [DW-1:0] s1_cache_wdata;

    wire [SW-1:0]      index;
    wire [tag_len-1:0] tag;
    wire [SW-1:0]      snoop_index;
    wire [tag_len-1:0] snoop_tag;

    assign index       = cache_addr[BW +: SW];
    assign tag         = cache_addr[BW + SW +: tag_len];
    assign snoop_index = snoop_addr[BW +: SW];
    assign snoop_tag   = snoop_addr[BW + SW +: tag_len];

    wire [tag_len-1:0] s1_tag;
    wire [tag_len-1:0] s1_snoop_tag;
    wire [SW-1:0]      s1_index;
    wire [SW-1:0]      s1_snoop_index;

    assign s1_index       = s1_cache_addr[BW +: SW];
    assign s1_tag         = s1_cache_addr[BW + SW +: tag_len];
    assign s1_snoop_index = s1_snoop_addr[BW +: SW];
    assign s1_snoop_tag   = s1_snoop_addr[BW + SW +: tag_len];

    // things remaining
    // 1. complete the pipeline
    // 2. implementing stall

    always @(posedge clk) begin
        if(cache_req || mem_req || snoop_req) begin
            s1_cache_req    <= cache_req;
            s1_mem_req      <= mem_req;
            s1_snoop_req    <= snoop_req;
            s1_cache_wdata  <= cache_wdata;
            s1_cache_addr   <= cache_addr;
            s1_snoop_addr   <= snoop_addr;
            s1_cache_rw     <= cache_rw;
            s1_mem_rw       <= mem_rw;
            s1_snoop_signal <= snoop_signal;
            s1_cache_wdata  <= cache_wdata;
        end
    end

    wire [tag_len-1:0] tag_out_cpu [0:W-1];
    wire [tag_len-1:0] tag_out_snoop [0:W-1];
    wire [1:0]         state_out_cpu [0:W-1];
    wire [1:0]         state_out_snoop [0:W-1];
    wire [DW-1:0]      data_out [0:W-1][0:B-1];

    genvar w_idx, b_idx;

    // --- tag array ---
    generate
        for(w_idx = 0; w_idx < W; w_idx = w_idx + 1) begin : tag_array
            reg [tag_len-1:0] tag_mem [0:S-1];
            assign tag_out_cpu[w_idx]   = tag_mem[index];
            assign tag_out_snoop[w_idx] = tag_mem[snoop_index];

            always @(posedge clk) begin
                if(tag_we[w_idx])begin
                    tag_mem[s1_index] <= s1_tag;
                end
            end
        end
    endgenerate

    // --- state array ---
    generate
        reg [1:0] next_state_logic;
        always @(*) begin
            if (|state_cpu_we) begin
                next_state_logic = m;
            end else if (|state_snoop_we) begin
                next_state_logic = (snoop_signal == 2'b01) ? s : i;
            end else begin
                next_state_logic = (snoop_hit) ? s : e;
            end
        end
        for(w_idx = 0; w_idx < W; w_idx = w_idx + 1) begin : state_array
            reg [1:0] state_mem [0:S-1];
            assign state_out_cpu[w_idx]   = state_mem[index];
            assign state_out_snoop[w_idx] = state_mem[snoop_index];

            always @(posedge clk) begin
                if(state_cpu_we[w_idx]) begin
                    state_mem[s1_index] <= next_state_logic;
                end
                else if(state_snoop_we[w_idx]) begin
                    state_mem[snoop_index] <= next_state_logic;
                end
            end
        end
    endgenerate

    // --- data array---
    generate
        for(w_idx = 0; w_idx < W; w_idx = w_idx + 1) begin : data_array

            for(b_idx = 0; b_idx < B; b_idx = b_idx + 1) begin : block_array
                reg [DW-1:0] data_mem [0:S-1];

                wire [SW-1:0] read_idx = snoop_stall ? snoop_index : index;
                assign data_out[w_idx][b_idx] = data_mem[read_idx];

                always @(posedge clk) begin
                    if(data_we[w_idx] && (b_idx == s1_cache_addr[BW-1:0])) begin // needs to be checked //
                        data_mem[s1_index] <= s1_cache_wdata;
                    end
                end
            end
        end
    endgenerate

    // --- hit detection logic ---
    integer loop;
    reg [WW-1:0] hit_way;
    reg [WW-1:0] snoop_hit_way;
    wire [WW-1:0] lru_way;

    always @(*) begin
        hit = 1'b0;
        hit_way = 0;
        snoop_hit = 1'b0;
        snoop_hit_way = 0;
        cache_rdata = 0;
        snoop_rdata = 0;

        tag_we = 0;
        state_cpu_we = 0;
        data_we = 0;
        state_snoop_we = 0;

        // 2. Hit Evaluation
        for(loop = 0; loop < W; loop = loop + 1) begin
            if(s1_tag == tag_out_cpu[loop] && state_out_cpu[loop] != i) begin
                hit = 1'b1;
                hit_way = loop;
            end
            if(s1_snoop_tag == tag_out_snoop[loop] && state_out_snoop[loop] != i) begin
                snoop_hit = 1'b1;
                snoop_hit_way = loop;
            end
        end

        // 3. Write Enables
        if(s1_mem_rw && s1_mem_req) begin
            tag_we = 1 << lru_way;
            state_cpu_we = 1 << lru_way;
            data_we = 1 << lru_way;
        end

        if(s1_snoop_req) begin
            case(s1_snoop_signal)
                2'b01 : begin // Downgrade to Shared
                    state_cpu_we = 1 << snoop_hit_way; 
                end
                2'b10 : begin // Write
                    state_snoop_we = 1 << snoop_hit_way; 
                    tag_we = 1 << snoop_hit_way;
                    data_we = 1 << snoop_hit_way;
                end
                2'b11 : begin // Invalidate
                    state_cpu_we = 1 << snoop_hit_way; 
                end
            endcase
        end

        if (hit) begin
            cache_rdata = data_out[hit_way][s1_cache_addr[BW-1:0]];
        end

        if (snoop_hit) begin
            snoop_rdata = data_out[snoop_hit_way][snoop_addr[BW-1:0]];
        end

        cache_miss_addr = {tag_out_cpu[lru_way], s1_index, {BW{1'b0}}};
        cache_miss_state = state_out_cpu[lru_way];
    end

    // --- lru ---
    lru #(
        .S(S), .W(W), .SW(SW), .WW(WW)
    ) l0 (
        .clk(clk),
        .rst(rst),
        .hit(hit),
        .s1_index(s1_index),
        .hit_way(hit_way),
        .lru_way(lru_way)
    );

endmodule