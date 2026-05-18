`timescale 1ns / 1ps

module tb_cache_full;

    parameter way = 4;
    parameter data_width = 8;
    parameter add_width = 8;
    parameter set = 8;

    reg clk;
    reg rst;
    reg ena;
    reg read;
    reg write;
    reg [data_width - 1 : 0] indata;
    reg [add_width - 1 : 0] address;

    wire [data_width - 1 : 0] outdata;
    wire hit;
    wire dn;

    // Instantiate the Device Under Test (DUT)
    cache #(
        .way(way),
        .data_width(data_width),
        .add_width(add_width),
        .set(set)
    ) dut (
        .clk(clk),
        .rst(rst),
        .ena(ena),
        .read(read),
        .write(write),
        .indata(indata),
        .address(address),
        .outdata(outdata),
        .hit(hit),
        .dn(dn)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Standardized Write Task
    task write_op(input [add_width-1:0] t_addr, input [data_width-1:0] t_data, input integer test_num);
        begin
            @(posedge clk);
            ena     <= 1'b1;
            write   <= 1'b1;
            read    <= 1'b0;
            address <= t_addr;
            indata  <= t_data;

            wait (dn == 1'b1);
            @(posedge clk);
            $display("Test %0d: WRITE Addr 0x%0h | Data 0x%0h | Hit: %b", test_num, t_addr, t_data, hit);
            ena     <= 1'b0;
            write   <= 1'b0;
            #10;
        end
    endtask

    // Standardized Read Task with Self-Checking
    task read_op(input [add_width-1:0] t_addr, input [data_width-1:0] expected_data, input integer test_num);
        begin
            @(posedge clk);
            ena     <= 1'b1;
            write   <= 1'b0;
            read    <= 1'b1;
            address <= t_addr;

            wait (dn == 1'b1);
            @(posedge clk);
            
            if (outdata === expected_data) begin
                $display("Test %0d: READ  Addr 0x%0h | Data 0x%0h (PASS) | Hit: %b", test_num, t_addr, outdata, hit);
            end else begin
                $display("Test %0d: [ERROR] READ Addr 0x%0h | Expected: 0x%0h | Got: 0x%0h", test_num, t_addr, expected_data, outdata);
            end
            
            ena     <= 1'b0;
            read    <= 1'b0;
            #10;
        end
    endtask

    initial begin
        
        rst     = 1'b1;
        ena     = 1'b0;
        read    = 1'b0;
        write   = 1'b0;
        indata  = 8'h00;
        address = 8'h00;

        #20;
        rst = 1'b0;
        #20;

        $display("--- PHASE 1: FILLING SET 0 (Index 3'b000) ---");
        write_op(8'h00, 8'hAA, 1); // Way 3
        write_op(8'h08, 8'hBB, 2); // Way 2
        write_op(8'h10, 8'hCC, 3); // Way 1
        write_op(8'h18, 8'hDD, 4); // Way 0

        $display("\n--- PHASE 2: READ HITS & LRU REORDERING ---");
        // Reading in reverse order to make 0x00 the LRU block.
        read_op(8'h18, 8'hDD, 5);
        read_op(8'h10, 8'hCC, 6);
        read_op(8'h08, 8'hBB, 7);
        read_op(8'h00, 8'hAA, 8);

        $display("\n--- PHASE 3: DIRTY EVICTION (WRITEBACK) ---");
        // 0x20 maps to Set 0. It must evict 0x18 (LRU), write 0xDD to memory, and write 0xEE to Way 3.
        write_op(8'h20, 8'hEE, 9);
        read_op(8'h20, 8'hEE, 10);
        
        // 0x18 was evicted. Reading it should cause a Miss, fetching 0xDD back from memory, evicting 0x10.
        read_op(8'h18, 8'hDD, 11); 

        $display("\n--- PHASE 4: WRITE HIT ---");
        // Updating an existing block (0x00 is in Way 0). Should hit and update dirty bit.
        write_op(8'h00, 8'hA1, 12);
        read_op(8'h00, 8'hA1, 13);

        $display("\n--- PHASE 5: FILLING SET 1 (Index 3'b001) ---");
        write_op(8'h01, 8'h11, 14); 
        write_op(8'h09, 8'h22, 15); 
        write_op(8'h11, 8'h33, 16); 
        write_op(8'h19, 8'h44, 17); 
        
        $display("\n--- PHASE 6: CROSS-SET ISOLATION ---");
        // Reading Set 0 to ensure Set 1 operations didn't corrupt it.
        read_op(8'h08, 8'hBB, 18); 
        read_op(8'h00, 8'hA1, 19); 

        $display("\n--- PHASE 7: CLEAN EVICTION ---");
        read_op(8'h29, 8'h00, 20); // Expect 0x00 because memory at 0x29 is uninitialized.
        
        // This tests the FSM transition for a Miss where ftc_mem == 0.
        read_op(8'h31, 8'h00, 21); // Expect 0x00

        $display("\n--- PHASE 8: EXTREME EDGE CASE (Highest Addr) ---");
        write_op(8'hFF, 8'h99, 22); // Set 7
        read_op(8'hFF, 8'h99, 23);  // Verify Set 7

        $display("\n--- SIMULATION COMPLETE ---");
        #50;
        $finish;
    end

endmodule
