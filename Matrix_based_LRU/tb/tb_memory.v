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

module tb_memory();

    // Parameters matching your memory module
    localparam AW = 16;
    localparam DW = 8;

    // Standard Signals
    reg clk;
    reg rst;

    // AR Channel (Read Address)
    reg [AW - 1 : 0] ar_addr;
    reg [7 : 0]      ar_len;
    wire             ar_ready;
    reg              ar_valid;

    // R Channel (Read Data)
    wire [DW - 1 : 0] r_data;
    wire              r_last;
    reg               r_ready;
    wire              r_valid;

    // AW Channel (Write Address)
    reg [AW - 1 : 0] aw_addr;
    reg [7 : 0]      aw_len;
    wire             aw_ready;
    reg              aw_valid;

    // W Channel (Write Data)
    reg [DW - 1 : 0] w_data;
    reg              w_last;
    wire             w_ready;
    reg              w_valid;

    // B Channel (Write Response)
    wire [1 : 0]     bcode;
    wire             bvalid;
    reg              bready;

    integer i, k;

    memory #(
        .AW(AW),
        .DW(DW)
    ) dut (
        .clk(clk),
        .rst(rst),
        .ar_addr(ar_addr),
        .ar_len(ar_len),
        .ar_ready(ar_ready),
        .ar_valid(ar_valid),
        .r_data(r_data),
        .r_last(r_last),
        .r_ready(r_ready),
        .r_valid(r_valid),
        .aw_addr(aw_addr),
        .aw_len(aw_len),
        .aw_ready(aw_ready),
        .aw_valid(aw_valid),
        .w_data(w_data),
        .w_last(w_last),
        .w_ready(w_ready),
        .w_valid(w_valid),
        .bcode(bcode),
        .bvalid(bvalid),
        .bready(bready)
    );

    always #5 clk = ~clk;

    initial begin

        // applying initial reset
        clk = 0;
        rst = 1;
        
        ar_addr <= 0; ar_len <= 0; ar_valid <= 0; r_ready <= 0;
        aw_addr <= 0; aw_len <= 0; aw_valid <= 0;
        w_data <= 0; w_last <= 0; w_valid <= 0; bready <= 0;

        #25 rst <= 0; 
        #10;

        // Testcase 1 : 4 Beat Burst Write
        
        $display("[%0t] --- Starting Base 4-Beat Burst Write ---", $time);
        
        @(posedge clk);
        aw_addr  <= 16'h0020;
        aw_len   <= 8'd3;       
        aw_valid <= 1'b1;
        wait(aw_ready);        
        @(posedge clk);
        aw_valid <= 1'b0;          

        w_valid <= 1'b1;
        w_data <= 8'hAA; wait(w_ready); @(posedge clk);
        w_data <= 8'hBB; wait(w_ready); @(posedge clk);
        w_data <= 8'hCC; wait(w_ready); @(posedge clk);
        w_data <= 8'hDD; w_last <= 1'b1; wait(w_ready); @(posedge clk);
        
        w_valid <= 1'b0;
        w_last  <= 1'b0;

        bready <= 1'b1;
        wait(bvalid);
        @(posedge clk);
        bready <= 1'b0;
        $display("[%0t] --- Base Burst Write Complete ---", $time);

        // Testcase 2 : 4 Beat Burst Read
        $display("[%0t] --- Starting Base 4-Beat Burst Read ---", $time);
        
        @(posedge clk);
        ar_addr  <= 16'h0020;
        ar_len   <= 8'd3;       
        ar_valid <= 1'b1;
        wait(ar_ready);
        @(posedge clk);
        ar_valid <= 1'b0;

        r_ready <= 1'b1; 
        
        for (i = 0; i < 4; ) begin 
            @(posedge clk); 
            if (r_valid) begin 
                $display("[%0t] Read Beat Received: Data=%h, Last=%b", $time, r_data, r_last);
                i = i + 1; 
            end
        end
        
        r_ready <= 1'b0; 
        $display("[%0t] --- Base Burst Read Complete ---", $time);

        #30;

        // Testcase 3 : Single-Beat Transfer
        $display("[%0t] --- Test: Single-Beat Transfer ---", $time);
        
        // Write Phase
        @(posedge clk);
        aw_addr <= 16'h0030; aw_len <= 8'd0; aw_valid <= 1'b1;
        wait(aw_ready); @(posedge clk); aw_valid <= 1'b0;

        w_data <= 8'hFF; w_valid <= 1'b1; w_last <= 1'b1;
        wait(w_ready); @(posedge clk);
        w_valid <= 1'b0; w_last <= 1'b0;

        bready <= 1'b1; wait(bvalid); @(posedge clk); bready <= 1'b0;

        // Read Phase
        @(posedge clk);
        ar_addr <= 16'h0030; ar_len <= 8'd0; ar_valid <= 1'b1;
        wait(ar_ready); @(posedge clk); ar_valid <= 1'b0;

        r_ready <= 1'b1;
        for (i = 0; i < 1; ) begin
            @(posedge clk);
            if (r_valid) begin
                $display("[%0t] Single Read Beat: Data=%h, Last=%b", $time, r_data, r_last);
                i = i + 1;
            end
        end
        r_ready <= 1'b0;
        $display("[%0t] --- Single-Beat Transfer Complete ---", $time);

        #30;

        // Testcase 6 : Master Write Stall
        $display("[%0t] --- Test: Master Write Stall ---", $time);
        
        @(posedge clk);
        aw_addr <= 16'h0040; aw_len <= 8'd1; aw_valid <= 1'b1;
        wait(aw_ready); @(posedge clk); aw_valid <= 1'b0;

        w_valid <= 1'b1; w_data <= 8'h11;
        wait(w_ready); @(posedge clk);

        // Stall : Master isn't ready with the next beat
        w_valid <= 1'b0;
        $display("[%0t] Master stalling write channel...", $time);
        repeat(3) @(posedge clk); 

        // Resume
        w_valid <= 1'b1; w_data <= 8'h22; w_last <= 1'b1;
        wait(w_ready); @(posedge clk);
        w_valid <= 1'b0; w_last <= 1'b0;

        bready <= 1'b1; wait(bvalid); @(posedge clk); bready <= 1'b0;
        $display("[%0t] --- Write Stall Handled ---", $time);

        #30;

        // Testcase 5 : Master Read Stall
        $display("[%0t] --- Test: Master Read Stall ---", $time);
        
        @(posedge clk);
        ar_addr <= 16'h0040; ar_len <= 8'd1; ar_valid <= 1'b1;
        wait(ar_ready); @(posedge clk); ar_valid <= 1'b0;

        // Read First Beat
        r_ready <= 1'b1;
        for (i = 0; i < 1; ) begin
            @(posedge clk);
            if (r_valid) begin
                $display("[%0t] Stall Read 1: Data=%h", $time, r_data);
                i = i + 1;
            end
        end

        // Stall : Master cannot accept next beat yet
        r_ready <= 1'b0;
        $display("[%0t] Master stalling read channel...", $time);
        repeat(3) @(posedge clk);

        // Resume Read
        r_ready <= 1'b1;
        for (i = 0; i < 1; ) begin
            @(posedge clk);
            if (r_valid) begin
                $display("[%0t] Stall Read 2: Data=%h, Last=%b", $time, r_data, r_last);
                i = i + 1;
            end
        end
        r_ready <= 1'b0;
        $display("[%0t] --- Read Stall Handled ---", $time);

        #30;

        // Testcase 6 : 8-Beat test
        $display("[%0t] --- Test: 8-Beat Stress Test ---", $time);
        
        @(posedge clk);
        aw_addr <= 16'h0050; aw_len <= 8'd7; aw_valid <= 1'b1;
        wait(aw_ready); @(posedge clk); aw_valid <= 1'b0;

        w_valid <= 1'b1;
        for (k = 0; k < 8; k = k + 1) begin
            w_data <= 8'hA0 + k;
            if (k == 7) w_last <= 1'b1;
            else w_last <= 1'b0;
            wait(w_ready); @(posedge clk);
        end
        w_valid <= 1'b0; w_last <= 1'b0;

        bready <= 1'b1; wait(bvalid); @(posedge clk); bready <= 1'b0;

        // Read 8 beats back
        @(posedge clk);
        ar_addr <= 16'h0050; ar_len <= 8'd7; ar_valid <= 1'b1;
        wait(ar_ready); @(posedge clk); ar_valid <= 1'b0;

        r_ready <= 1'b1;
        for (i = 0; i < 8; ) begin
            @(posedge clk);
            if (r_valid) begin
                $display("[%0t] 8-Beat Read: Data=%h, Last=%b", $time, r_data, r_last);
                i = i + 1;
            end
        end
        r_ready <= 1'b0;
        $display("[%0t] --- 8-Beat Stress Test Complete ---", $time);

        #50;
        $display("[%0t] === ALL SIMULATIONS FINISHED SUCCESSFULLY ===", $time);
        $finish;
    end

endmodule