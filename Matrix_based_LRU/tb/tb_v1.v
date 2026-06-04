`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 06/04/2026 04:21:30 PM
// Design Name:
// Module Name: tb_v1
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


module tb_v1();

    // Parameters
    parameter AW = 16;
    parameter DW = 8;

    // Clock and Reset
    reg clk;
    reg rst;

    // AXI Read Address Channel
    reg [AW - 1 : 0] ar_addr;
    reg              ar_valid;
    wire             ar_ready;

    // AXI Read Data Channel
    wire [DW - 1 : 0] r_data;
    reg               r_ready;
    wire              r_valid;

    // AXI Write Address Channel
    reg [AW - 1 : 0] aw_addr;
    reg              aw_valid;
    wire             aw_ready;

    // AXI Write Data Channel
    reg [DW - 1 : 0] w_data;
    reg              w_valid;
    wire             w_ready;

    // AXI Write Response Channel
    wire [1 : 0] bcode;
    wire         bvalid;
    reg          bready;

    // Instantiate the Unit Under Test (UUT)
    memory #(
        .AW(AW),
        .DW(DW)
    ) uut (
        .clk(clk),
        .rst(rst),
        .ar_addr(ar_addr),
        .ar_ready(ar_ready),
        .ar_valid(ar_valid),
        .r_data(r_data),
        .r_ready(r_ready),
        .r_valid(r_valid),
        .aw_addr(aw_addr),
        .aw_ready(aw_ready),
        .aw_valid(aw_valid),
        .w_data(w_data),
        .w_ready(w_ready),
        .w_valid(w_valid),
        .bcode(bcode),
        .bvalid(bvalid),
        .bready(bready)
    );

    // Clock Generation (10ns period -> 100MHz)
    always #5 clk = ~clk;

    // AXI Write Task
    task axi_write(input [AW - 1 : 0] addr, input [DW - 1 : 0] data);
        begin
            @(posedge clk);
            aw_addr  <= addr;
            aw_valid <= 1'b1;
            w_data   <= data;
            w_valid  <= 1'b1;
            bready   <= 1'b1;

            // Wait until the slave accepts both address and data
            wait(aw_ready && w_ready);
            @(posedge clk);
            aw_valid <= 1'b0;
            w_valid  <= 1'b0;

            // Wait for B-Channel response
            wait(bvalid);
            @(posedge clk);
            bready <= 1'b0;
            $display("[%0t] WRITE SUCCESS: Addr = 0x%h, Data = 0x%h, Response = %b", $time, addr, data, bcode);
        end
    endtask

    // AXI Read Task
    task axi_read(input [AW - 1 : 0] addr);
        begin
            @(posedge clk);
            ar_addr  <= addr;
            ar_valid <= 1'b1;
            r_ready  <= 1'b1;

            // Wait until the slave accepts the address
            wait(ar_ready);
            @(posedge clk);
            ar_valid <= 1'b0;

            // Wait for R-Channel data
            wait(r_valid);
            $display("[%0t] READ SUCCESS: Addr = 0x%h, Data = 0x%h", $time, addr, r_data);
            @(posedge clk);
            r_ready <= 1'b0;
        end
    endtask

    // Main Test Sequence
    initial begin
        // Initialize Inputs
        clk      = 0;
        rst      = 1;
        ar_addr  = 0;
        ar_valid = 0;
        r_ready  = 0;
        aw_addr  = 0;
        aw_valid = 0;
        w_data   = 0;
        w_valid  = 0;
        bready   = 0;

        // Apply Reset
        #20;
        @(posedge clk);
        rst = 0;
        $display("[%0t] Reset De-asserted. Starting transactions...", $time);

        // Let the FSM settle into IDLE
        #20;

        // Execute Writes
        axi_write(16'h0010, 8'hAA);
        #20;
        axi_write(16'h0011, 8'hBB);
        #20;

        // Execute Reads to verify memory storage
        axi_read(16'h0010);
        #20;
        axi_read(16'h0011);
        #20;

        $display("[%0t] Simulation Complete.", $time);
        $finish;
    end

endmodule
