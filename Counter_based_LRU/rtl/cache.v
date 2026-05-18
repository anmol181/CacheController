`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05/18/2026 03:27:42 PM
// Design Name:
// Module Name: cache
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


`timescale 1ns / 1ps

module cache #(
    parameter way = 4,
    parameter data_width = 8,
    parameter add_width = 8,
    parameter set = 8
)(
    input clk,
    input rst,
    input ena,

    input read,
    input write,
    input [data_width - 1 : 0] indata,
    input [add_width - 1 : 0] address,
    output reg [data_width - 1 : 0] outdata,
    output reg hit,
    output reg dn
);

    localparam index_width = $clog2(set);
    localparam line_width  = add_width + data_width - index_width + 2;

    localparam v = line_width - 1;
    localparam d = line_width - 2;
    localparam way_width = $clog2(way);

    // State definitions
    localparam idle    = 3'd0;
    localparam st      = 3'd1;
    localparam rd_hit  = 3'd2;
    localparam wt_hit  = 3'd3;
    localparam mem_wt  = 3'd4;
    localparam rd_temp = 3'd5;
    localparam rd_miss = 3'd6;
    localparam wt_miss = 3'd7;

    reg [2:0] ps, ns;
    reg [way_width - 1 : 0] target_way; // Latched target way to prevent race condition

    reg dirty;
    reg [way - 1 : 0] load;
    wire [way - 1 : 0] dn_cache;
    reg [data_width - 1 : 0] indata_cache;
    reg [add_width  - 1 : 0] address_cache;
    wire [line_width - 1 : 0] outdata_cache [way - 1 : 0];

    genvar loop;
    integer i,j;

    // Initializing N-way cache
    generate
        for (loop = 0; loop < way; loop = loop + 1) begin : cache_ways
            cache_block #(
                .data_width(data_width),.add_width(add_width),.set(set),.line_width(line_width),.index_width(index_width) 
            ) block_inst (
                .clk(clk), .rst(rst),.ena(ena),.load(load[loop]),.dirty(dirty),.indata(indata_cache),.address(address_cache),.out_cache_bl(outdata_cache[loop]), .dn(dn_cache[loop])
            );
        end
    endgenerate

    reg [way-1:0] current_valid_bits;
    reg valid;

    always @(*) begin
        for (i = 0; i < way; i = i + 1) begin
            current_valid_bits[i] = outdata_cache[i][v];
        end
        valid = ~(&current_valid_bits);
    end

    reg [add_width - 1 : 0] address_st; // address stored
    reg [data_width - 1 : 0] data_st;   // data stored
    reg rd;
    reg wt;

    wire wrk;
    wire [add_width - index_width - 1 : 0] tag;
    wire [index_width - 1 : 0] index;

    assign wrk = read || write;
    assign {tag,index} = rst ? {add_width{1'b0}} : address_st;

    // storing address and data for safety purpose
    always @(posedge clk) begin
        if(rst) begin
            address_st <= {add_width{1'b0}};
            data_st <= {data_width{1'b0}};
            rd <= 1'b0;
            wt <= 1'b0;
        end
        else if(ena) begin
            if(ps == idle ) begin
                if(wrk) begin
                    address_st <= address;
                    data_st <= indata;
                    rd <= read;
                    wt <= write;
                end
                else begin
                    address_st <= {add_width{1'b0}};
                    data_st <= {data_width{1'b0}};
                end
            end
        end
    end

    wire mem_ena;
    wire mem_wrt;
    wire mem_rd;
    reg  [add_width  - 1 : 0] mem_add;
    reg  [data_width - 1 : 0] mem_indata;
    wire [data_width - 1 : 0] mem_outdata;
    wire mem_dn;

    assign mem_ena = (ps == mem_wt && !mem_dn) || (ps == rd_temp && !mem_dn);
    assign mem_wrt = (ps == mem_wt && !mem_dn);
    assign mem_rd  = (ps == rd_temp && !mem_dn);

    memory #(
        .data_width(data_width),.add_width(add_width)
    ) main_mem (
        .clk(clk),.rst(rst),.ena(mem_ena),.read(mem_rd),.write(mem_wrt),.indata(mem_indata),.address(mem_add),.outdata(mem_outdata),.dn(mem_dn)
    );

    reg [way_width - 1 : 0] hit_way;
    reg [way - 1 : 0] hit_w;

    // Combinational hit detection logic
    always @(*) begin
        hit_w = {way{1'b0}};
        hit_way = {way_width{1'b0}};

        for (i = 0; i < way; i = i + 1) begin
            if (outdata_cache[i][v] && outdata_cache[i][data_width +: (add_width - index_width)] == tag) begin
                hit_w[i] = 1'b1;
                hit_way = i;
            end
        end
        hit = |hit_w[way - 1 : 0];
    end

    reg [way_width - 1 : 0] lru;
    reg [way*way_width - 1 : 0] actual_lru[set - 1 : 0];

    // lru for access the required way for index
    always @(*) begin
        if(rst) begin
            lru = {way_width{1'b0}};
        end
        else if(valid) begin
            for(i = 0; i < way; i = i + 1) begin
                if(!outdata_cache[i][v]) begin
                    lru = i;
                end
            end
        end
        else begin
            for(i = 0; i < way; i = i + 1) begin
                if(actual_lru[index][i*way_width +: way_width] == (way - 1)) begin
                    lru = i;
                end
            end
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < set; i = i + 1) begin
                for(j = 0; j < way; j = j + 1) begin
                    actual_lru[i][j*way_width +: way_width] <= j;
                end
            end
        end
        else if (ena) begin
            if ((ps == rd_hit) || (ps == wt_hit && dn_cache[target_way])) begin
                for (i = 0; i < way; i = i + 1) begin
                    if (actual_lru[index][i*way_width +: way_width] < actual_lru[index][target_way*way_width +: way_width]) begin
                        actual_lru[index][i*way_width +: way_width] <= actual_lru[index][i*way_width +: way_width] + 1;
                    end
                end
                actual_lru[index][target_way*way_width +: way_width] <= {way_width{1'b0}};
            end
            else if ((ps == rd_miss) || (ps == wt_miss && dn_cache[target_way])) begin
                for (i = 0; i < way; i = i + 1) begin
                    if (actual_lru[index][i*way_width +: way_width] < actual_lru[index][target_way*way_width +: way_width]) begin
                        actual_lru[index][i*way_width +: way_width] <= actual_lru[index][i*way_width +: way_width] + 1;
                    end
                end
                actual_lru[index][target_way*way_width +: way_width] <= {way_width{1'b0}};
            end
        end
    end

    wire ftc_mem;
    // Check valid AND dirty before writeback
    assign ftc_mem = outdata_cache[lru][v] && outdata_cache[lru][d];

    // fsm logic
    always @(*)begin
        case(ps)
        idle : begin
            ns = wrk ? st : idle;
        end
        st : begin
            // Route read misses to rd_temp to fetch data
            ns = hit ? (rd ? rd_hit : wt_hit) : ftc_mem ? mem_wt : (rd ? rd_temp : wt_miss);
        end
        rd_hit : begin
            ns = idle;
        end
        wt_hit : begin
            ns = dn_cache[target_way] ? idle : wt_hit;
        end
        mem_wt : begin
            ns = mem_dn ? (rd ? rd_temp : wt_miss) : mem_wt;
        end
        rd_temp : begin
            ns = mem_dn ? rd_miss : rd_temp;
        end
        rd_miss : begin
            ns = idle;
        end
        wt_miss : begin
            ns = dn_cache[target_way] ? idle : wt_miss;
        end
        endcase
    end

    // state transition
    always @(posedge clk) begin
        if(rst) begin
            ps <= idle;
            target_way <= {way_width{1'b0}};
        end
        else if(ena) begin
            ps <= ns;
            if (ps == st) begin
                // Lock the destination way to prevent race conditions during operations
                target_way <= hit ? hit_way : lru;
            end
        end
    end

    // Combinational signal allocation for cache
    always @(*) begin
        // 1. Default assignments
        dn            = 1'b0;
        load          = {way{1'b0}};
        outdata       = {data_width{1'b0}};
        dirty         = 1'b0;
        indata_cache  = {data_width{1'b0}};
        address_cache = address_st;
        mem_add       = {add_width{1'b0}};
        mem_indata    = {data_width{1'b0}};

        // 2. State-specific overrides
        case(ps)
        rd_hit : begin
            outdata = outdata_cache[target_way][0 +: data_width];
            dn      = 1'b1;
        end
        wt_hit : begin
            load[target_way] = 1'b1;
            dirty            = 1'b1;
            indata_cache     = data_st;
            dn               = dn_cache[target_way];
        end
        mem_wt : begin
            mem_add    = {outdata_cache[target_way][data_width +: (add_width - index_width)], index};
            mem_indata = outdata_cache[target_way][0 +: data_width];
        end
        rd_temp : begin
            mem_add = address_st; // Request specific address from memory
            if (mem_dn) begin
                load[target_way] = 1'b1;
                dirty            = 1'b0;
                indata_cache     = mem_outdata;
            end
        end
        rd_miss : begin
            outdata = outdata_cache[target_way][0 +: data_width];
            dn      = 1'b1;
        end
        wt_miss : begin
            load[target_way] = 1'b1;
            dirty            = 1'b1;
            indata_cache     = data_st;
            dn               = dn_cache[target_way];
        end
        endcase
    end

endmodule
