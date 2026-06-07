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
    output reg hit
    );

    localparam BS = DW*B; // block size
    localparam LW = AW + BS - SW - BW;

    reg [LW-1 : 0] cache [S-1 : 0][W-1 : 0];
    reg [W-1 : 0] valid [S-1 : 0];
    reg [W-1 : 0] dirty [S-1 : 0];

    // reg [AW-1 : 0] read_addr; 
    // reg [AW-1 : 0] write_addr;

    // reg [7 : 0] read_len;
    // reg [7 : 0] write_len;

    // reg [7 : 0] read_cnt;
    // reg [7 : 0] write_cnt;

    wire read_en = cpu_read_en || mem_read_en;
    wire write_en = cpu_write_en || mem_write_en;

    wire [AW-SW-BW-1 : 0]tag;
    assign tag = addr[AW-1 : SW+BW];

    wire [SW-1 : 0]index;
    assign index = addr[BW +: SW];

    integer i,j;

    // --- Combinatorial Read & Hit Logic ---
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
    end

    // --- Synchronous Write Logic ---
    always @(posedge clk) begin
        if(rst) begin
            // Reset logic here
            for(i = 0;i < S;i = i + 1)begin
                for(j = 0;j < W;j = j + 1)begin
                    cache[i][j] <= {LW{1'b0}};
                end
                valid[i] <= {W{1'b0}};
                dirty[i] <= {W{1'b0}};
            end
        end
        else if(write_en) begin
            if (hit) begin
                cache[index][hit_way][DW*addr[BW-1:0] +: DW] <= data_in;
                dirty[index][hit_way] <= cpu_write_en; 
            end
            else begin

            end
        end
    end

endmodule
