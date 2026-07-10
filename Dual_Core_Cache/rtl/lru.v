`timescale 1ns / 1ps

module lru#(
    parameter W = 8,
    parameter S = 8,
    parameter SW = $clog2(S),
    parameter WW = $clog2(W)
)(
    input               clk,
    input               rst,

    input wire          hit,
    input wire [SW-1:0]  s1_index,
    output reg [WW-1:0] lru_way,
    input wire [WW-1:0] hit_way
    );

    reg [W-2:0] plru [0:S-1];
    reg [7:0] cnt;
    integer i_rst;
    integer i_upd;
    integer i_dcd;

    always @(posedge clk) begin
        if(rst) begin
            for(i_rst = 0;i_rst < S;i_rst = i_rst + 1) begin
                plru[i_rst] <= {W-1{1'b0}};
            end
        end
        else if (hit) begin
            cnt = 0;
            for (i_upd = WW-1; i_upd >= 0; i_upd = i_upd - 1) begin
                plru[s1_index][cnt] <= !hit_way[i_upd];
                cnt = 2*cnt + 1'b1 + hit_way[i_upd];
            end
        end
    end

    reg [7:0] way_cnt;
    always @(*) begin
        way_cnt = 0;
        for (i_dcd = WW-1; i_dcd >= 0; i_dcd = i_dcd - 1) begin
            lru_way[i_dcd] = plru[s1_index][way_cnt];
            way_cnt = 2*way_cnt + 1'b1 + plru[s1_index][way_cnt];
        end
    end
endmodule
