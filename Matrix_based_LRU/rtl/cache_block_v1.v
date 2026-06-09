`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/06/2026 03:02:32 PM
// Design Name: 
// Module Name: cache_block_v1
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


module cache_block_v1 #(
    parameter AW = 16,
    parameter DW = 8,
    parameter B = 4, // block size = B*DW
    parameter W = 4, // no. of ways
    parameter S = 8, // no. of blocks
    parameter WW = $clog2(W),
    parameter SW = $clog2(S),
    parameter BW = $clog2(B)
)(
    input clk,
    input rst,

    input cpu_read_en,
    input cpu_write_en,
    input mem_read_en,
    input mem_write_en,
    input [AW-1 : 0]addr,
    input [DW-1 : 0] data_in,
    output reg [DW-1 : 0] data_out,
    output reg hit,
    output reg v,
    output reg d,
    input miss,
    output reg [AW-1 : 0]cache_miss_addr
    );

    localparam BS = DW*B;
    localparam LW = AW + BS - SW - BW;

    reg [LW-1 : 0] cache [S-1 : 0][W-1 : 0];
    reg [W-1 : 0]  valid [S-1 : 0];
    reg [W-1 : 0]  dirty [S-1 : 0];

    wire read_en = cpu_read_en || mem_read_en;
    wire write_en = cpu_write_en || mem_write_en;

    wire [AW-SW-BW-1 : 0]tag;
    assign tag = addr[AW-1 : SW+BW];

    wire [SW-1 : 0]index;
    assign index = addr[BW +: SW];

    integer i,j,k;
    
    reg [W-1:0] lru [S-1:0][W-1:0];
    reg [WW-1:0] lru_way;

/////////////////////////// Combinatorial Read & Hit Logic ///////////////////////////
    reg [W-1 : 0] hit_w;
    reg [WW-1 : 0] hit_way;
    
    always @(*) begin
        hit_w = {W{1'b0}};
        hit_way = 0;
        data_out = {DW{1'b0}};
        hit = 1'b0;
        
        for(i = 0; i < W; i = i + 1) begin
            if(valid[index][i] && (cache[index][i][LW-1:BS] == tag)) begin
                hit_w[i] = 1'b1;
                hit_way = i;
                hit = 1'b1;
                data_out = cache[index][i][DW*addr[BW-1:0] +: DW];
            end
        end
        if(miss) begin
            data_out = cache[index][lru_way][DW*addr[BW-1:0] +: DW];
        end
    end


/////////////////////////// Synchronous Write Logic ///////////////////////////
    always @(posedge clk) begin
        if(rst) begin
            // Reset logic here
            for (k = 0; k < S; k = k + 1) begin
                for(i = 0;i < W;i = i + 1)begin
                    cache[k][i] <= {LW{1'b0}};
                end
                valid[k] <= {W{1'b0}};
                dirty[k] <= {W{1'b0}};
            end
        end
        else if(write_en) begin
            if (hit) begin
                cache[index][hit_way][DW*addr[BW-1:0] +: DW] <= data_in;
                dirty[index][hit_way] <= cpu_write_en; 
            end
            else if(miss) begin
                cache[index][lru_way][LW-1 : BS] <= tag;
                cache[index][lru_way][DW*addr[BW-1:0] +: DW] <= data_in;
                dirty[index][lru_way] <= cpu_write_en;
                valid[index][lru_way] <= 1'b1;
            end
            else begin
            end
        end
    end

/////////////////////////// Lru Implementation ///////////////////////////

    always @(posedge clk) begin
        if(rst) begin
            for (k = 0; k < S; k = k + 1) begin   
                for(i = 0;i < W;i = i + 1)begin
                    for (j = 0; j < W; j = j + 1) begin
                        lru[k][i][j] <= (i < j);
                    end
                end
            end
        end
        else if(hit) begin
            lru[index][hit_way] <= {W{1'b1}};
            for(i = 0;i < W;i = i+1)begin
                lru[index][i][hit_way] <= 1'b0;
            end
        end
        else if(miss) begin
            lru[index][lru_way] <= {W{1'b1}};
            for(i = 0;i < W;i = i+1)begin
                lru[index][i][lru_way] <= 1'b0;
            end
        end
    end


    always @(*) begin
        lru_way = 0;
        cache_miss_addr = 0;
        v = 0;
        d = 0;
        for(i = 0; i < W ; i = i + 1)begin
            if(~|lru[index][i]) begin
                lru_way = i;
                cache_miss_addr = {cache[index][i][LW-1 : BS],index,{BW{1'b0}}};
                v = valid[index][i];
                d = dirty[index][i];
            end     
        end
    end

endmodule
