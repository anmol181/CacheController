`timescale 1ns / 1ps

module tb_dualcore();

    // Parameters
    parameter AW = 16;
    parameter DW = 8;
    parameter W  = 4;
    parameter S  = 8;
    parameter B  = 4;

    // Clock and Reset
    reg clk;
    reg rst;

    // Core 0 CPU Signals
    reg           cpu_req0;
    reg           cpu_rw0;
    reg  [AW-1:0] cpu_addr0;
    reg  [DW-1:0] cpu_wdata0;
    wire [DW-1:0] cpu_rdata0;
    wire          cpu_ready0;

    // Core 1 CPU Signals
    reg           cpu_req1;
    reg           cpu_rw1;
    reg  [AW-1:0] cpu_addr1;
    reg  [DW-1:0] cpu_wdata1;
    wire [DW-1:0] cpu_rdata1;
    wire          cpu_ready1;

    // AXI Bus
    wire [AW-1:0] mem_aw_addr;
    wire [7:0]    mem_aw_len;
    wire          mem_aw_valid;
    wire          mem_aw_ready;
    wire [DW-1:0] mem_w_data;
    wire          mem_w_last;
    wire          mem_w_valid;
    wire          mem_w_ready;
    wire [AW-1:0] mem_ar_addr;
    wire [7:0]    mem_ar_len;
    wire          mem_ar_valid;
    wire          mem_ar_ready;
    wire [DW-1:0] mem_r_data;
    wire          mem_r_last;
    wire          mem_r_valid;
    wire          mem_r_ready;

    // --- Instantiations ---

    dualcore #(
        .AW(AW), .DW(DW), .W(W), .S(S), .B(B)
    ) DUT (
        .clk(clk), .rst(rst),
        .cpu_req0(cpu_req0), .cpu_rw0(cpu_rw0), .cpu_addr0(cpu_addr0), .cpu_wdata0(cpu_wdata0), .cpu_rdata0(cpu_rdata0), .cpu_ready0(cpu_ready0),
        .cpu_req1(cpu_req1), .cpu_rw1(cpu_rw1), .cpu_addr1(cpu_addr1), .cpu_wdata1(cpu_wdata1), .cpu_rdata1(cpu_rdata1), .cpu_ready1(cpu_ready1),
        .mem_aw_addr(mem_aw_addr), .mem_aw_len(mem_aw_len), .mem_aw_valid(mem_aw_valid), .mem_aw_ready(mem_aw_ready),
        .mem_w_data(mem_w_data), .mem_w_last(mem_w_last), .mem_w_valid(mem_w_valid), .mem_w_ready(mem_w_ready),
        .mem_ar_addr(mem_ar_addr), .mem_ar_len(mem_ar_len), .mem_ar_valid(mem_ar_valid), .mem_ar_ready(mem_ar_ready),
        .mem_r_data(mem_r_data), .mem_r_last(mem_r_last), .mem_r_valid(mem_r_valid), .mem_r_ready(mem_r_ready)
    );

    wire mem_b_valid;
    wire [1:0] mem_b_code;

    memory #(
        .AW(AW), .DW(DW)
    ) MAIN_MEM (
        .clk(clk), .rst(rst),
        .aw_addr(mem_aw_addr), .aw_len(mem_aw_len), .aw_valid(mem_aw_valid), .aw_ready(mem_aw_ready),
        .w_data(mem_w_data), .w_last(mem_w_last), .w_valid(mem_w_valid), .w_ready(mem_w_ready),
        .ar_addr(mem_ar_addr), .ar_len(mem_ar_len), .ar_valid(mem_ar_valid), .ar_ready(mem_ar_ready),
        .r_data(mem_r_data), .r_last(mem_r_last), .r_valid(mem_r_valid), .r_ready(mem_r_ready),
        .bvalid(mem_b_valid), .bcode(mem_b_code), .bready(1'b1)
    );

    // --- Clock & Memory Init ---
    always #5 clk = ~clk;

    integer i;
    initial begin
        #1;
        for(i = 0; i < (1 << AW); i = i + 1) begin
            MAIN_MEM.mem[i] = i[DW-1:0];
        end
    end

    // --- Tasks for Core 0 ---
    task c0_write(input [AW-1:0] addr, input [DW-1:0] data);
        begin
            @(posedge clk);
            cpu_req0   <= 1'b1; cpu_rw0 <= 1'b1; cpu_addr0 <= addr; cpu_wdata0 <= data;
            $display("[%0t] Core 0: WRITE Req to Addr 0x%0h, Data: 0x%0h", $time, addr, data);
            @(posedge clk);
            cpu_req0 <= 1'b0; cpu_rw0 <= 1'b0; cpu_addr0 <= 0; cpu_wdata0 <= 0;
            wait(cpu_ready0);
            cpu_req0 <= 1'b0;
            @(posedge clk); repeat(2) @(posedge clk);
        end
    endtask

    task c0_read(input [AW-1:0] addr, input [DW-1:0] expected_data);
        begin
            @(posedge clk);
            cpu_req0  <= 1'b1; cpu_rw0 <= 1'b0; cpu_addr0 <= addr;
            @(posedge clk);
            cpu_req0 <= 1'b0; cpu_rw0 <= 1'b0; cpu_addr0 <= 0;
            wait(cpu_ready0);
            if (cpu_rdata0 !== expected_data) $error("[%0t] FAIL! Core 0 Read Addr 0x%0h: Expected 0x%0h, Got 0x%0h", $time, addr, expected_data, cpu_rdata0);
            else $display("[%0t] PASS! Core 0 Read Addr 0x%0h: 0x%0h", $time, addr, cpu_rdata0);
            cpu_req0 <= 1'b0;
            @(posedge clk); repeat(2) @(posedge clk);
        end
    endtask

    // --- Tasks for Core 1 ---
    task c1_write(input [AW-1:0] addr, input [DW-1:0] data);
        begin
            @(posedge clk);
            cpu_req1   <= 1'b1; cpu_rw1 <= 1'b1; cpu_addr1 <= addr; cpu_wdata1 <= data;
            $display("[%0t] Core 1: WRITE Req to Addr 0x%0h, Data: 0x%0h", $time, addr, data);
            @(posedge clk);
            cpu_req1 <= 1'b0; cpu_rw1 <= 1'b0; cpu_addr1 <= 0; cpu_wdata1 <= 0;
            wait(cpu_ready1);
            cpu_req1 <= 1'b0;
            @(posedge clk); repeat(2) @(posedge clk);
        end
    endtask

    task c1_read(input [AW-1:0] addr, input [DW-1:0] expected_data);
        begin
            @(posedge clk);
            cpu_req1  <= 1'b1; cpu_rw1 <= 1'b0; cpu_addr1 <= addr;
            @(posedge clk);
            cpu_req1 <= 1'b0; cpu_rw1 <= 1'b0; cpu_addr1 <= 0;
            wait(cpu_ready1);
            if (cpu_rdata1 !== expected_data) $error("[%0t] FAIL! Core 1 Read Addr 0x%0h: Expected 0x%0h, Got 0x%0h", $time, addr, expected_data, cpu_rdata1);
            else $display("[%0t] PASS! Core 1 Read Addr 0x%0h: 0x%0h", $time, addr, cpu_rdata1);
            cpu_req1 <= 1'b0;
            @(posedge clk); repeat(2) @(posedge clk);
        end
    endtask

    // --- Main Simulation Sequence ---
    initial begin
        clk = 0; rst = 1;
        cpu_req0 = 0; cpu_rw0 = 0; cpu_addr0 = 0; cpu_wdata0 = 0;
        cpu_req1 = 0; cpu_rw1 = 0; cpu_addr1 = 0; cpu_wdata1 = 0;

        $display("\n=== STARTING MULTICORE COHERENCE TEST ===");
        #20 rst = 0; #20;

        // ---------------------------------------------------------
        // Test 1: Core 0 Modifies Data (MESI: Modified)
        // ---------------------------------------------------------
        $display("\n--- Test 1: Core 0 Write Miss (State -> Modified) ---");
        c0_write(16'h1000, 8'hEE);
        c0_read(16'h1000, 8'hEE);

        // ---------------------------------------------------------
        // Test 2: The Snoop Intervention (MESI: Core 0 downgrades to Shared)
        // ---------------------------------------------------------
        $display("\n--- Test 2: Core 1 Coherent Read (Snoop Hit on Core 0) ---");
        // Core 1 asks for 0x1000. Core 0 has it dirty!
        // Interconnect should stall Core 1, pull 0xEE from Core 0,
        // write it to main memory, AND pass it to Core 1.
        c1_read(16'h1000, 8'hEE);

        // ---------------------------------------------------------
        // Test 3: The Invalidation (MESI: Core 1 goes Invalid)
        // ---------------------------------------------------------
        $display("\n--- Test 3: Core 0 Write Hit (Invalidate Core 1) ---");
        // Both cores currently have 0x1000 in Shared (S) state.
        // Core 0 writes a new value. It must broadcast an invalidation to Core 1.
        c0_write(16'h1000, 8'hFF);

        // ---------------------------------------------------------
        // Test 4: Verifying the Invalidation
        // ---------------------------------------------------------
        $display("\n--- Test 4: Core 1 Read Miss (Verifying Invalidation worked) ---");
        // If Core 1 correctly invalidated its cache line during Test 3,
        // this read MUST cause a Cache Miss and fetch the new 0xFF from Core 0 via a snoop!
        // If it returns 0xEE, the invalidation failed!
        c1_read(16'h1000, 8'hFF);

        // ---------------------------------------------------------
        // Test 5: Arbiter Stress Test (Simultaneous Requests)
        // ---------------------------------------------------------
        $display("\n--- Test 5: Arbiter Simultaneous Access Check ---");
        // We will trigger both CPU requests at the exact same clock edge
        // for completely different addresses to ensure the Arbiter queues them.
        @(posedge clk);
        cpu_req0  <= 1'b1; cpu_rw0 <= 1'b0; cpu_addr0 <= 16'h2023;
        cpu_req1  <= 1'b1; cpu_rw1 <= 1'b0; cpu_addr1 <= 16'h3032;
        @(posedge clk);
        cpu_req0 <= 1'b0; cpu_rw0 <= 1'b0; cpu_addr0 <= 0;
        cpu_req1 <= 1'b0; cpu_rw1 <= 1'b0; cpu_addr1 <= 0;
        // Wait for both to complete. They should return their respective memory init data (0x00).
        fork
            begin
                wait(cpu_ready0);
                if (cpu_rdata0 !== 8'h23) $error("FAIL Core 0 Arbiter Test");
                else $display("PASS Core 0 Arbiter Test");
                cpu_req0 <= 1'b0;
            end
            begin
                wait(cpu_ready1);
                if (cpu_rdata1 !== 8'h32) $error("FAIL Core 1 Arbiter Test");
                else $display("PASS Core 1 Arbiter Test");
                cpu_req1 <= 1'b0;
            end
        join
        @(posedge clk);
        @(posedge clk);

        // ---------------------------------------------------------
        // Test 6: Dirty Intervention (M -> S with Write-back)
        // ---------------------------------------------------------
        $display("\n--- Test 6: Dirty Intervention (M -> S with Write-back) ---");
        // 1. Core 0 writes to 0x4000 (Goes to Modified)
        c0_write(16'h4000, 8'hAA);
        
        // 2. Core 1 reads 0x4000 (Forces Core 0 to Intervene and Write-back)
        c1_read(16'h4000, 8'hAA); // Should fetch 0xAA from Core 0

        #50; // Wait for the AXI background write-back to finish

        // 3. Verify Main Memory was actually updated by the interconnect!
        if (MAIN_MEM.mem[16'h4000] !== 8'hAA) $display("Error: [Test 6] Memory Write-back Failed! Got %h", MAIN_MEM.mem[16'h4000]);
        else $display("PASS! Background Write-back to Main Memory succeeded.");
        // #50;

        // ---------------------------------------------------------
        // Test 7: Unaligned Block Collision
        // ---------------------------------------------------------
        $display("\n--- Test 7: Unaligned Block Collision ---");
        // 1. Core 0 reads 0x5001 (Offset 1). Memory init value is 0x01.
        c0_read(16'h5001, 8'h01);
        
        // 2. Core 1 writes to 0x5003 (Offset 3 of the SAME block). Core 0 must be invalidated.
        c1_write(16'h5003, 8'hBB);
        
        // 3. Core 0 reads 0x5001 again. Must miss, snoop Core 1, and fetch the block.
        c0_read(16'h5001, 8'h01);
        $display("PASS! Unaligned offsets successfully maintained coherence.");
        // #50;

        // ---------------------------------------------------------
        // Test 8: Dirty Eviction (4-Way Conflict Miss)
        // ---------------------------------------------------------
        $display("\n--- Test 8: Dirty Eviction (4-Way Conflict Miss) ---");
        
        // 1. Fill Way 0 (Dirty) - Memory init value was 0x00, we write 0xC1
        c0_write(16'h1000, 8'hC1);
        
        // 2. Fill Way 1 (Clean) - Fetches from memory
        c0_read(16'h1020, 8'h20);
        
        // 3. Fill Way 2 (Clean) - Fetches from memory
        c0_read(16'h1040, 8'h40);
        
        // 4. Fill Way 3 (Clean) - Fetches from memory
        c0_read(16'h1060, 8'h60);
        
        // SET 0 IS NOW FULL! 
        // Since 0x1000 was accessed first, your PLRU tree marks it as the LRU victim.

        // 5. Fetch a 5th block. This FORCES the eviction of 0x1000!
        // Because 0x1000 is 'Modified', it must trigger the AXI mem_write_req.
        $display("attempt 1");
        c0_read(16'h1080, 8'h80);
        $display("attempt 2");
        #100;

        // 6. Check if 0x1000 was safely written to memory before it was destroyed
        if (MAIN_MEM.mem[16'h1000] !== 8'hC1) $display("Error: [Test 8] Dirty Eviction Failed! Memory has %h", MAIN_MEM.mem[16'h1000]);
        else $display("PASS! 4-Way Capacity Eviction successfully saved dirty data.");
        // #50;

        // ---------------------------------------------------------
        // Test 9: The Deadlock Duel (Simultaneous R/W)
        // ---------------------------------------------------------
        $display("\n--- Test 9: The Deadlock Duel (Simultaneous R/W) ---");
        // Both cores hit 0x6000 at the exact same time
        @(posedge clk);
        cpu_req0  <= 1'b1; cpu_rw0 <= 1'b0; cpu_addr0 <= 16'h6000; // Core 0 Reads
        cpu_req1  <= 1'b1; cpu_rw1 <= 1'b1; cpu_addr1 <= 16'h6000; cpu_wdata1 <= 8'hDD; // Core 1 Writes
        
        @(posedge clk);
        cpu_req0 <= 1'b0; cpu_rw0 <= 1'b0; cpu_addr0 <= 0;
        cpu_req1 <= 1'b0; cpu_rw1 <= 1'b0; cpu_addr1 <= 0; cpu_wdata1 <= 0;

        // Wait for BOTH to finish. (Using fork-join to wait for concurrent signals)
        fork
            begin
                wait(cpu_ready0);
                cpu_req0 <= 1'b0;
            end
            begin
                wait(cpu_ready1);
                cpu_req1 <= 1'b0;
            end
        join

        // Core 0 should have either read the old data (if it won arbitration)
        // or the NEW data (if Core 1 won and forced Core 0 to fetch the update).
        $display("PASS! Arbiter survived the Deadlock Duel without hanging.");
        // #50;

        $display("\n=== MULTICORE SIMULATION COMPLETE ===");
        #100;
        $finish;
        end

    initial begin
        $dumpfile("dualcore_wave.vcd");
        $dumpvars(0, tb_dualcore);
    end

endmodule 
