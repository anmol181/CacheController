`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/07/2026 01:35:31 PM
// Design Name: 
// Module Name: cache_ctrl
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


module cache_ctrl #(
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

    // cache signals
    output                  mem_read_en,
    output                  mem_write_en,
    output                  cache_read_en,
    output                  cache_write_en,
    input  [DW - 1 : 0]     cache_read_data,
    output [DW - 1 : 0]     cache_write_data,
    output [AW - 1 : 0]     cache_address,
    input                   hit,

    // axi signals for memory
    output [AW - 1 : 0]      ar_addr, // read address
    output [7 : 0]           ar_len,
    input                    ar_ready,
    output                   ar_valid,

    input       [DW - 1 : 0] r_data, // read data
    input                    r_last,
    output                   r_ready,
    input                    r_valid,

    output [AW - 1 : 0]      aw_addr, // write address
    output [7 : 0]           aw_len,
    input                    aw_ready,
    output                   aw_valid,

    output [DW - 1 : 0]      w_data, // write address
    output                   w_last,
    input                    w_ready,
    output                   w_valid

    // input [1 : 0]            bcode, // write response channel
    // input                    bvalid,
    // output                   bready

    );


    // localparam BS = DW*B; // block size
    // localparam LW = AW + BS - SW;

    // reg [LW-1 : 0] cache [S-1 : 0][W-1 : 0];
    // reg [W-1 : 0] valid [S-1 : 0];
    // reg [W-1 : 0] dirty [S-1 : 0];

    // reg [AW-1 : 0] read_addr; 
    // reg [AW-1 : 0] write_addr;

    // reg [7 : 0] read_len;
    // reg [7 : 0] write_len;

    // reg [7 : 0] read_cnt;
    // reg [7 : 0] write_cnt;

    // wire [AW-SW-BW-1 : 0]tag;
    // // assign tag = aw_valid ? write_addr[AW-1 : SW+BW] : read_addr[AW-1 : SW+BW];
    // assign tag = addr[AW-1 : SW+BW];

    // wire [SW-1 : 0]index;
    // // assign index = aw_valid ? write_addr[BW +: SW] : read_addr[BW +: SW];
    // assign index = addr[BW +: SW];

    // localparam st     = 0;
    // localparam rd_wt  = 1;
    // localparam rd_src = 2;
    // localparam rd_ftc = 3;
    // localparam rd_shw = 4;
    // // localparam rd_mem = 5;

    // // ps = st
    // // ps = ar_valid ? rd_src : st;
    // // 
    // // ps = rd_src(data will be searched, if found then to rd_ftc else to st)
    // // ps = hit ? rd_ftc : st
    // // 
    // // ps = rd_ftc
    // // ps = rd_shw;
    
    // // reg [3 : 0] ps;

    // // wire hit;
    // reg [W-1 : 0]hit_w;
    // reg [WW-1 : 0] hit_way;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         ps <= st;
    //         ar_ready <= 1'b1;
    //         r_valid <= 1'b0;
    //         aw_ready <= 1'b1;
    //         w_ready <= 1'b1;
    //     end
    //     else begin
    //         case(ps)
    //         st : begin
    //             if(aw_valid) begin

    //             end
    //             else if(ar_valid) begin
    //                 read_addr <= ar_addr;
    //                 read_len <= ar_len;
    //                 read_cnt <= 8'b0;
    //                 ps <= rd_src;
    //                 ar_ready <= 1'b0;
    //             end
    //             else begin
    //                 ps <= st;
    //             end
    //         end
    //         rd_src : begin
    //             if(hit) begin
    //                 ps <= rd_shw;
    //             end
    //             else begin
    //                 ps <= st;
    //             end
    //         end
    //         rd_shw : begin
    //             if(read_cnt == read_len) begin
    //                 ps <= st;
    //             end
    //             else ps <= rd_shw;
    //         end
    //         endcase
    //     end
    // end

    // integer i;

    // assign hit = |hit_w;

    // always @(posedge clk) begin
    //     if(rst) begin

    //     end
    //     else begin
    //         case(ps)
    //         st : begin
    //             if(aw_valid) begin

    //             end
    //             else if(ar_valid) begin
    //                 for(i = 0;i < W;i = i + 1)begin
    //                     if(valid[index][i] && tag == cache[index][i][LW-1 : LW-BS])begin
    //                         hit_w[i] <= 1'b1;
    //                         hit_way <= i;
    //                     end
    //                 end
    //             end
    //         end
    //         rd_src : begin
    //             case(read_addr)
    //             0 : begin
    //                 r_data <= cache[index][hit_way][0 +: DW];
    //             end
    //             1 : begin
    //                 r_data <= cache[index][hit_way][DW +: DW];
    //             end
    //             2 : begin
    //                 r_data <= cache[index][hit_way][2*DW +: DW];
    //             end
    //             3 : begin
    //                 r_data <= cache[index][hit_way][3*DW +: DW];
    //             end
    //             endcase
    //             r_valid <= 1'b1;
    //         end
    //         rd_shw : begin
    //             if(read_cnt == read_len)begin
    //                 r_last <= 1'b1;
    //                 r_valid <= 1'b0;
    //                 ar_ready <= 1'b1;
    //             end
    //         end
    //         endcase
    //     end
    // end


endmodule
