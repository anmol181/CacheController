`timescale 1ns / 1ps

module tb_main();
    parameter AW = 16, DW = 8, B = 4, W = 4, S = 8;

    reg clk; reg rst;
    integer error_count = 0;

    reg           cpu_valid, cpu_ready, cpu_we;
    wire          cache_ready, cache_valid;
    reg  [AW-1:0] cpu_addr;
    reg  [DW-1:0] cpu_data_in;
    wire [DW-1:0] cpu_data_out;

    wire [AW-1:0] ar_addr, aw_addr;
    wire [7:0]    ar_len, aw_len;
    wire          ar_valid, ar_ready, aw_valid, aw_ready;
    wire [DW-1:0] r_data, w_data;
    wire          r_valid, r_last, r_ready, w_valid, w_last, w_ready;
    wire [1:0]    bcode;
    wire          bvalid, bready;

    always #5 clk = ~clk;

    cache_top #(.AW(AW),
    .DW(DW),
    .B(B),
    .W(W),
    .S(S)) 
    DUT_CACHE (
        .clk(clk),
        .rst(rst),
        .cpu_valid(cpu_valid),
        .cpu_ready(cpu_ready), 

        .cache_ready(cache_ready),
        .cache_valid(cache_valid), 

        .cpu_we(cpu_we),
        .cpu_addr(cpu_addr),

        .cpu_data_in(cpu_data_in),
        .cpu_data_out(cpu_data_out),

        .ar_addr(ar_addr),
        .ar_len(ar_len),
        .ar_valid(ar_valid),
        .ar_ready(ar_ready),

        .r_data(r_data),
        .r_valid(r_valid),
        .r_last(r_last),
        .r_ready(r_ready),

        .aw_addr(aw_addr),
        .aw_len(aw_len),
        .aw_valid(aw_valid),
        .aw_ready(aw_ready),

        .w_data(w_data),
        .w_valid(w_valid),
        .w_last(w_last),
        .w_ready(w_ready),
        .bready(bready)
    );

    memory #(
    .AW(AW),
    .DW(DW)) 
    DUT_MEM (

        .clk(clk),
        .rst(rst),

        .ar_addr(ar_addr),
        .ar_len(ar_len),
        .ar_valid(ar_valid),
        .ar_ready(ar_ready),

        .r_data(r_data),
        .r_valid(r_valid),
        .r_last(r_last),
        .r_ready(r_ready),

        .aw_addr(aw_addr),
        .aw_len(aw_len),
        .aw_valid(aw_valid),
        .aw_ready(aw_ready),

        .w_data(w_data),
        .w_valid(w_valid),
        .w_last(w_last),
        .w_ready(w_ready),

        .bvalid(bvalid),
        .bready(bready)
    );

    integer i_init;
    initial begin
        for (i_init = 0; i_init < (1 << AW); i_init = i_init + 1) begin
            DUT_MEM.mem[i_init] = i_init; 
        end
    end

    task cpu_write(input [AW-1:0] addr, input [DW-1:0] data);
        begin
            wait(cache_ready);      
            @(posedge clk);
            cpu_valid <= 1'b1; cpu_we <= 1'b1; cpu_addr <= addr; cpu_data_in <= data;
            @(posedge clk);         
            cpu_valid <= 1'b0; cpu_we <= 1'b0;
            wait(cache_valid);      
            $display("[%0t] CPU WRITE: Addr=0x%0h, Data=0x%0h", $time, addr, data);
        end
    endtask

    task cpu_read(input [AW-1:0] addr, input [DW-1:0] expected_data);
        begin
            wait(cache_ready);      
            @(posedge clk);
            cpu_valid <= 1'b1; cpu_we <= 1'b0; cpu_addr <= addr;
            @(posedge clk);         
            cpu_valid <= 1'b0;      
            wait(cache_valid);      
            @(posedge clk);
            if (cpu_data_out === expected_data) begin
                $display("[%0t] [PASS] CPU READ : Addr=0x%0h, Data=0x%0h", $time, addr, cpu_data_out);
            end else begin
                $display("[%0t] [FAIL] CPU READ : Addr=0x%0h | Expected=0x%0h, Got=0x%0h", $time, addr, expected_data, cpu_data_out);
                error_count = error_count + 1;
            end
        end
    endtask

    task check_main_memory(input [AW-1:0] mem_addr, input [DW-1:0] expected_data);
        begin
            if (DUT_MEM.mem[mem_addr] === expected_data) begin
                $display("[%0t] [PASS] MEM CHECK: Addr=0x%0h holds Data=0x%0h", $time, mem_addr, expected_data);
            end else begin
                $display("[%0t] [FAIL] MEM CHECK: Addr=0x%0h | Expected=0x%0h, Got=0x%0h", 
                $time, mem_addr, expected_data, DUT_MEM.mem[mem_addr]);
                error_count = error_count + 1;
            end
        end
    endtask

    task cpu_write_and_verify(input [AW-1:0] addr, input [DW-1:0] data);
        begin
            cpu_write(addr, data);
            cpu_read(addr, data); 
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        cpu_valid = 0;
        cpu_ready = 1;
        cpu_we = 0;
        cpu_addr = 0;
        cpu_data_in = 0;

        #100; @(posedge clk);
        rst = 0; #20;

        $display("\n--- TEST 1: Cold Miss & Write Allocation ---");
        cpu_write(16'h0000, 8'hBB);

        $display("\n--- TEST 2: Cache Hit Verification ---");
        cpu_read(16'h0000, 8'hBB);

        $display("\n--- TEST 3: Filling the Set (PLRU Updates) ---");
        cpu_write(16'h0020, 8'h11); 
        cpu_write(16'h0040, 8'h22); 
        cpu_write(16'h0060, 8'h33); 

        $display("\n--- TEST 4: The PLRU Eviction (Write-Back) ---");
        cpu_write_and_verify(16'h0080, 8'h99); 
        #20;
        check_main_memory(16'h0000, 8'hBB); // Proves the dirty block was evicted via AXI

        $display("\n--- TEST 5: Verify Post-Eviction Cache State ---");
        cpu_read(16'h0020, 8'h11); 
        cpu_read(16'h0040, 8'h22); 
        cpu_read(16'h0060, 8'h33); 
        cpu_read(16'h0100, 8'h00);

        $display("\n---------------------------------------------------");
        $display("--- TEST 6: Block Offset & Word Boundary Test   ---");
        $display("---------------------------------------------------");
        // Goal: Verify that reading/writing to different word offsets 
        // within the SAME block results in instantaneous hits (no AXI traffic).
        
        // Write to offset 0 (Miss, Allocates Block)
        cpu_write_and_verify(16'h0200, 8'hAA); 
        
        // Write to offset 1, 2, and 3 (Should all be 1-cycle hits)
        cpu_write_and_verify(16'h0201, 8'hBB);
        cpu_write_and_verify(16'h0202, 8'hCC);
        cpu_write_and_verify(16'h0203, 8'hDD);

        // Verify the entire block remained intact
        cpu_read(16'h0200, 8'hAA);
        cpu_read(16'h0203, 8'hDD);

        $display("\n---------------------------------------------------");
        $display("--- TEST 7: The 'Thrashing' Sequence            ---");
        $display("---------------------------------------------------");
        // Goal: Continuously access 5 different blocks mapping to the same set.
        // This forces the PLRU tree to rapidly shift and ensures it does not 
        // get stuck in a locked loop.
        
        cpu_write_and_verify(16'h1000, 8'h10); // Fills Set 0
        cpu_write_and_verify(16'h1020, 8'h20);
        cpu_write_and_verify(16'h1040, 8'h30);
        cpu_write_and_verify(16'h1060, 8'h40);
        
        cpu_write_and_verify(16'h1080, 8'h50); // Evicts 0x1000
        cpu_write_and_verify(16'h1000, 8'h10); // Evicts 0x1020
        cpu_write_and_verify(16'h1020, 8'h20); // Evicts 0x1040

        // Verify the AXI Memory caught all the evicted data correctly
        #20;
        check_main_memory(16'h1000, 8'h10);
        check_main_memory(16'h1020, 8'h20);

        #50;
        $display("\n---------------------------------------------------");
        $display("--- TEST 8: Dirty Read-Miss Hazard              ---");
        $display("---------------------------------------------------");
        // Goal: Issue a Read command that forces a Dirty Eviction.
        // The FSM must write the dirty data to memory via AW/W channels,
        // then immediately transition to AR/R channels to fulfill the CPU Read.
        
        // 1. Prime a block and make it dirty
        cpu_write_and_verify(16'h2000, 8'hFF);
        cpu_write_and_verify(16'h2020, 8'hFF);
        cpu_write_and_verify(16'h2040, 8'hFF);
        cpu_write_and_verify(16'h2060, 8'hFF);
        
        // 2. CPU requests a READ to a 5th block. 
        // This forces an eviction of 0x2000 BEFORE the read can complete.
        // (Expected data is 0x00002080 because of our memory init loop)
        cpu_read(16'h2080, 16'h2080); 

        // 3. Verify the dirty data was safely evacuated
        #20;
        check_main_memory(16'h2000, 8'hFF);

        #50;
        $display("\n---------------------------------------------------");
        $display("--- TEST 9: Rapid Read/Write Alternation        ---");
        $display("---------------------------------------------------");
        // Goal: Ensure the 1-cycle pipeline does not drop tracking bits 
        // when switching instantly between read and write logic.
        
        cpu_write(16'h3000, 8'hA1);
        cpu_read(16'h3000, 8'hA1);
        cpu_write(16'h3000, 8'hA2);
        cpu_read(16'h3000, 8'hA2);
        cpu_write(16'h3000, 8'hA3);
        cpu_read(16'h3000, 8'hA3);

        #100;
        $display("\n===================================================");
        if (error_count == 0) $display("=== SIMULATION PASSED (0 ERRORS)                ===");
        else                  $display("=== SIMULATION FAILED (%0d ERRORS)                ===", error_count);
        $display("===================================================\n");
        $finish;
    end
endmodule