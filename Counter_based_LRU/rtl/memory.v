`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05/18/2026 03:35:50 PM
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

module memory #(
    parameter data_width = 8,
    parameter add_width = 8
) (
    input clk,
    input rst,
    input ena,
    input read,
    input write,
    input [data_width - 1 : 0] indata,
    input [add_width - 1 : 0] address,
    output [data_width - 1 : 0] outdata,
    output reg dn
);

    localparam mem_size = 1 << add_width;

    reg [data_width - 1 : 0] mem[mem_size - 1 : 0];
    reg [data_width - 1 : 0] out;

    integer i;

    always @(posedge clk) begin
        dn <= 1'b0;

        if (rst) begin
            out <= {data_width{1'b0}};
            for (i = 0;i < mem_size;i = i + 1) begin
                mem[i] = {data_width{1'b0}};
            end
        end

        else if (ena) begin
            if (write) begin
                mem[address] <= indata;
                dn <= 1'b1;
            end

            else if (read) begin
                out <= mem[address];
                dn <= 1'b1;
            end
        end
    end

    assign outdata = out;

endmodule
