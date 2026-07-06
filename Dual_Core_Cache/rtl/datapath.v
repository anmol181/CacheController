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


    // --- Snoop Interface ---
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
    output reg snoop_dirty,
    output reg snoop_valid,
    output reg hit
);

    localparam tag_len = AW - BW - SW;
    localparam m = 2'b11;
    localparam e = 2'b10;
    localparam s = 2'b01;
    localparam i = 2'b00;

    reg [W-1:0] tag_we;
    reg [W-1:0] data_we;
    reg [W-1:0] state_cpu_we;
    reg [W-1:0] state_mem_we;
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
    wire [SW-1:0]      snoop_index;

    assign index       = cache_addr[BW +: SW];
    assign snoop_index = snoop_addr[BW +: SW];

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
            s1_cache_req    <= 0;
            s1_mem_req      <= 0;
            s1_snoop_req    <= 0;
            s1_cache_wdata  <= 0;
            s1_cache_addr   <= 0;
            s1_snoop_addr   <= 0;
            s1_cache_rw     <= 0;
            s1_mem_rw       <= 0;
            s1_snoop_signal <= 0;
            s1_cache_wdata  <= 0;
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

    reg [tag_len-1:0] tag_out_snoop [0:W-1];
    reg [tag_len-1:0] tag_out_cpu [0:W-1];
    reg [1:0]         state_out_cpu [0:W-1];
    reg [1:0]         state_out_snoop [0:W-1];
    reg [DW-1:0]      data_out [0:W-1][0:B-1];

    genvar w_idx, b_idx;

    // --- tag array ---
    generate
        for(w_idx = 0; w_idx < W; w_idx = w_idx + 1) begin : tag_array
            reg [tag_len-1:0] tag_mem [0:S-1];

            always @(posedge clk) begin
                if(tag_we[w_idx])begin
                    tag_mem[s1_index] <= s1_tag;
                end
                tag_out_cpu[w_idx]   <= tag_mem[index];
                tag_out_snoop[w_idx] <= tag_mem[snoop_index];
            end
        end
    endgenerate

    // --- state array ---
    generate
        reg [1:0] next_state_cpu;
        reg [1:0] next_state_snoop;

        always @(*) begin
            // PORT A Next State
            if (|state_cpu_we) next_state_cpu = m;
            else next_state_cpu = e;

            // PORT B Next State
            if (snoop_signal == 2'b01) next_state_snoop = s;
            else next_state_snoop = i;
        end

        for(w_idx = 0; w_idx < W; w_idx = w_idx + 1) begin : state_array
            (* ram_style = "block" *) reg [1:0] state_mem [0:S-1];

            // --- PORT A ---
            always @(posedge clk) begin
                if(state_cpu_we[w_idx] || state_mem_we[w_idx]) begin
                    state_mem[s1_index] <= next_state_cpu;
                end
                state_out_cpu[w_idx] <= state_mem[index];
            end

            // --- PORT B ---
            always @(posedge clk) begin
                if(state_snoop_we[w_idx]) begin
                    state_mem[s1_snoop_index] <= next_state_snoop;
                end
                state_out_snoop[w_idx] <= state_mem[snoop_index];
            end
        end
    endgenerate

    // --- data array---
    generate
        for(w_idx = 0; w_idx < W; w_idx = w_idx + 1) begin : data_array

            for(b_idx = 0; b_idx < B; b_idx = b_idx + 1) begin : block_array
                reg [DW-1:0] data_mem [0:S-1];

                wire [SW-1:0] read_idx = snoop_stall ? snoop_index : index;

                always @(posedge clk) begin
                    if(data_we[w_idx] && (b_idx == s1_cache_addr[BW-1:0])) begin // needs to be checked //
                        data_mem[s1_index] <= s1_cache_wdata;
                    end
                    data_out[w_idx][b_idx] <= data_mem[read_idx];
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
        snoop_dirty = 1'b0;
        cache_rdata = 0;
        snoop_rdata = 0;
        snoop_valid = 1'b0;

        tag_we = 0;
        state_cpu_we = 0;
        data_we = 0;
        state_mem_we = 0;
        state_snoop_we = 0;

        // 2. Hit Evaluation
        for(loop = 0; loop < W; loop = loop + 1) begin
            if(s1_tag == tag_out_cpu[loop] && state_out_cpu[loop] != i) begin
                hit = 1'b1;
                hit_way = loop[WW-1:0];
            end
            if(s1_snoop_tag == tag_out_snoop[loop] && state_out_snoop[loop] != i) begin
                snoop_hit = 1'b1;
                snoop_hit_way = loop[WW-1:0];
            end
        end

        // 3. Write Enables
        if(s1_mem_rw && s1_mem_req) begin
            tag_we = 1 << lru_way;
            data_we = 1 << lru_way;
            state_mem_we = 1 << lru_way;
        end

        if(s1_snoop_req) begin
            case(s1_snoop_signal)
                2'b01 : begin // Downgrade to Shared
                    state_snoop_we = 1 << snoop_hit_way; // Fixed
                end
                2'b10 : begin // Write (Update)
                    state_snoop_we = 1 << snoop_hit_way;
                    tag_we = 1 << snoop_hit_way;
                    data_we = 1 << snoop_hit_way;
                end
                2'b11 : begin // Invalidate
                    state_snoop_we = 1 << snoop_hit_way; // Fixed
                end
            endcase
        end

        if (hit) begin
            cache_rdata = data_out[hit_way][s1_cache_addr[BW-1:0]];
        end

        if (snoop_hit) begin
            snoop_rdata = data_out[snoop_hit_way][s1_snoop_addr[BW-1:0]];
            snoop_valid = 1'b1;
            snoop_dirty = (state_out_snoop[snoop_hit_way] == m);
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