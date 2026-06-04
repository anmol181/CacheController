`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05/22/2026 06:59:40 AM
// Design Name:
// Module Name: memory
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


module memory#(
    parameter AW = 16,
    parameter DW = 8
)(
    input                   clk,
    input                   rst,

    input [AW - 1 : 0]      ar_addr, // read address
    output reg              ar_ready,
    input                   ar_valid,

    output reg [DW - 1 : 0] r_data, // read data
    input                   r_ready,
    output  reg             r_valid,

    input [AW - 1 : 0]      aw_addr, // write address
    output reg              aw_ready,
    input                   aw_valid,

    input [DW - 1 : 0]      w_data, // write address
    output reg              w_ready,
    input                   w_valid,

    output reg [1 : 0]      bcode, // write response channel
    output reg              bvalid,
    input                   bready
    );

    localparam mem_size = 1 << AW;
    reg [DW - 1 : 0] mem [mem_size - 1 : 0];

    reg [AW - 1 : 0] read_addr;

    reg [1 : 0] r_ps;

    localparam rd_rec = 0;
    localparam rd_ftc = 1;
    localparam rd_snd = 2;

    // read fsm
    always @(posedge clk) begin
        if(rst) begin
            read_addr <= {AW{1'b0}};
            r_data    <= {DW{1'b0}};
            ar_ready  <= 1'b1;
            r_valid   <= 1'b0;
            r_ps      <= rd_rec;
        end
        else begin
            case(r_ps)
            rd_rec : begin
                if(ar_valid) begin
                    read_addr <= ar_addr;
                    ar_ready  <= 1'b0;
                    r_ps      <= rd_ftc;
                end
            end

            rd_ftc : begin
                r_data    <= mem[read_addr];
                r_valid   <= 1'b1;
                r_ps      <= rd_snd;
            end

            rd_snd : begin
                if(r_ready) begin
                    ar_ready <= 1'b1;
                    r_valid  <= 1'b0;
                    r_ps     <= rd_rec;
                end
            end

            default : begin
                ar_ready <= 1'b1;
                r_valid  <= 1'b0;
                r_ps     <= rd_rec;
            end
            endcase
        end
    end

    /////////////////////////// WRITE /////////////////////////////

    reg [AW - 1 : 0] write_addr;
    reg [DW - 1 : 0] write_data;

    reg [2 : 0] w_ps;

    localparam wt_st    = 0;
    localparam wt_add   = 1;
    localparam wt_data  = 2;
    localparam wt_final = 3;
    localparam wt_resp  = 4;

    // write fsm
    always @(posedge clk) begin
        if(rst) begin
            write_addr <= {AW{1'b0}};
            write_data <= {DW{1'b0}};
            aw_ready   <= 1'b1;
            w_ready    <= 1'b1;
            bvalid     <= 1'b0;
            bcode      <= 2'b0;
            w_ps       <= wt_st;
        end
        else begin
            case(w_ps)
            wt_st : begin
                if(w_valid && aw_valid) begin
                    write_addr <= aw_addr;
                    write_data <= w_data;
                    aw_ready   <= 1'b0;
                    w_ready    <= 1'b0;
                    w_ps       <= wt_final;
                end
                else if(aw_valid) begin
                    write_addr <= aw_addr;
                    aw_ready   <= 1'b0;
                    w_ready    <= 1'b1;
                    w_ps       <= wt_data;
                end
                else if(w_valid) begin
                    write_data <= w_data;
                    aw_ready   <= 1'b1;
                    w_ready    <= 1'b0;
                    w_ps       <= wt_add;
                end
                else begin
                    aw_ready  <= 1'b1;
                    w_ready   <= 1'b1;
                    w_ps      <= wt_st;
                end
            end

            wt_add : begin
                if(aw_valid) begin
                    write_addr <= aw_addr;
                    aw_ready   <= 1'b0;
                    w_ps       <= wt_final;
                end
                else begin
                    w_ps <= wt_add;
                end
            end

            wt_data : begin
                if(w_valid) begin
                    write_data <= w_data;
                    w_ready    <= 1'b0;
                    w_ps       <= wt_final;
                end
                else begin
                    w_ps <= wt_data;
                end
            end

            wt_final : begin
                mem[write_addr] <= write_data;
                w_ps            <= wt_resp;
                bvalid          <= 1'b1;
                bcode           <= 2'b0;
            end

            wt_resp : begin
                if(bready) begin
                    bvalid   <= 1'b0;
                    w_ready  <= 1'b1;
                    aw_ready <= 1'b1;
                    w_ps     <= wt_st;
                end
            end

            default : begin
                aw_ready <= 1'b0;
                w_ready  <= 1'b0;
                w_ps     <= wt_st;
            end
            endcase
        end
    end

endmodule
