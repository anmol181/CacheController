`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 22.03.2026 21:56:47
// Design Name:
// Module Name: cache_block
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


module cache_block#(
    parameter data_width = 8,
    parameter add_width = 8,
    parameter set = 4, // no. of sets
    parameter line_width = add_width + data_width - $clog2(set) + 2,
    parameter index_width = $clog2(set)
)(
    input clk,
    input rst,
    input ena,
    input load,
    input dirty,
    input [data_width - 1 : 0] indata,
    input [add_width - 1 : 0] address,
    output wire [line_width - 1 : 0] out_cache_bl, // Changed from reg to wire
    output reg dn
);

wire [index_width - 1 : 0] index;
wire [add_width - index_width - 1 : 0] tag;
assign {tag, index} = address;

integer i;

reg [line_width - 1 : 0] cache[set - 1 : 0];

always @(posedge clk) begin
    dn <= 1'b0;
    if(rst) begin
        // Note: Resetting a full array forces Flip-Flop implementation instead of BRAM
        for(i = 0; i < set; i = i + 1) begin
            cache[i] <= {line_width{1'b0}};
        end
    end
    else if(ena && load) begin
        cache[index] <= {1'b1, dirty, tag, indata};
        dn <= 1'b1;
    end

    // Removed synchronous assignment of out_cache_bl
end

// Combinational read assignment to satisfy the controller's hit logic
assign out_cache_bl = ena ? cache[index] : {line_width{1'b0}};

endmodule


