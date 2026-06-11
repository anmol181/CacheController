`timescale 1ns / 1ps

module tb_cache_system();

    // Architectural Parameters
    parameter AW = 16;
    parameter DW = 8;
    parameter B  = 4;
    parameter W  = 4;
    parameter S  = 8;

    // Clock and Reset
    reg clk;
    reg rst;

    // CPU Frontend Interface
    reg [AW-1:0]  cpu_addr;
    reg           cpu_read_en;
    reg           cpu_write_en;
    reg [DW-1:0]  cpu_data_in;
    wire [DW-1:0] cpu_data_out;

    // AXI4 Backend Interface (Interconnect wires)
    wire [AW-1:0] ar_addr;
    wire [7:0]    ar_len;
    wire          ar_ready;
    wire          ar_valid;

    wire [DW-1:0] r_data;
    wire          r_last;
    wire          r_ready;
    wire          r_valid;

    wire [AW-1:0] aw_addr;
    wire [7:0]    aw_len;
    wire          aw_ready;
    wire          aw_valid;

    wire [DW-1:0] w_data;
    wire          w_last;
    wire          w_ready;
    wire          w_valid;

    // Memory specific B-Channel handling
    wire [1:0]    bcode;
    wire          bvalid;
    reg           bready; 

    // Automated Verification Tracking
    integer errors = 0;

    // DUT: L1 Cache Controller Top 
    cache_top #(
        .AW(AW), .DW(DW), .B(B), .W(W), .S(S)
    ) u_cache (
        .clk(clk),
        .rst(rst),
        .cpu_addr(cpu_addr),
        .cpu_read_en(cpu_read_en),
        .cpu_write_en(cpu_write_en),
        .cpu_data_in(cpu_data_in),
        .cpu_data_out(cpu_data_out),
        
        .ar_addr(ar_addr), .ar_len(ar_len), .ar_ready(ar_ready), .ar_valid(ar_valid),
        .r_data(r_data), .r_last(r_last), .r_ready(r_ready), .r_valid(r_valid),
        .aw_addr(aw_addr), .aw_len(aw_len), .aw_ready(aw_ready), .aw_valid(aw_valid),
        .w_data(w_data), .w_last(w_last), .w_ready(w_ready), .w_valid(w_valid)
    );

    // AXI4 Main Memory
    memory #(
        .AW(AW), .DW(DW)
    ) u_memory (
        .clk(clk),
        .rst(rst),
        .ar_addr(ar_addr), .ar_len(ar_len), .ar_ready(ar_ready), .ar_valid(ar_valid),
        .r_data(r_data), .r_last(r_last), .r_ready(r_ready), .r_valid(r_valid),
        .aw_addr(aw_addr), .aw_len(aw_len), .aw_ready(aw_ready), .aw_valid(aw_valid),
        .w_data(w_data), .w_last(w_last), .w_ready(w_ready), .w_valid(w_valid),
        .bcode(bcode), .bvalid(bvalid), .bready(bready)
    );

    // Clock Generation
    always #5 clk = ~clk;

    
    task check_result;
        input [DW-1:0] expected;
        input [DW-1:0] actual;
        input [256:0]  test_name;
        begin
            if (expected === actual) begin
                $display("[PASS] %0t | %s | Got: %h", $time, test_name, actual);
            end else begin
                $display("[FAIL] %0t | %s | Expected: %h, Got: %h", $time, test_name, expected, actual);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        u_memory.mem[16'h1000] = 8'hAA;
        u_memory.mem[16'h1001] = 8'hBB;
        u_memory.mem[16'h1002] = 8'hCC;
        u_memory.mem[16'h1003] = 8'hDD;

        u_memory.mem[16'h2000] = 8'h11;
        u_memory.mem[16'h2001] = 8'h22;
        u_memory.mem[16'h2002] = 8'h33;
        u_memory.mem[16'h2003] = 8'h44;

        u_memory.mem[16'h3000] = 8'h55;
        
        u_memory.mem[16'h4000] = 8'h66;

        u_memory.mem[16'h5000] = 8'h77;

        u_memory.mem[16'h1004] = 8'hEA;

        u_memory.mem[16'h6000] = 8'h88;
        u_memory.mem[16'h6001] = 8'h88;
        u_memory.mem[16'h6002] = 8'h89;

        // --- System Initialization ---
        clk = 0;
        rst = 1;
        bready = 1; 
        cpu_addr = 0;
        cpu_read_en = 0;
        cpu_write_en = 0;
        cpu_data_in = 0;

        #20;
        @(posedge clk); #1; 
        rst = 0;

        $display("\n   L1 CACHE AUTOMATED VERIFICATION START\n");

        // Testcase 1: Cold Read Miss
        @(posedge clk); #1; 
        cpu_read_en = 1;
        cpu_addr = 16'h1000;

        wait(r_valid && r_last);

        @(posedge clk);
        @(posedge clk); #1;
        cpu_read_en = 0;
        check_result(8'hAA, cpu_data_out, "Testcase 1: Cold Read Miss        ");

        // Testcase 2: 0-Latency Read Hit
        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h1001;

        @(posedge clk); #1;
        cpu_read_en = 0;
        check_result(8'hBB, cpu_data_out, "Testcase 2: 0-Latency Read Hit    ");

        // Testcase 3: Write Miss & Write-Allocate
        @(posedge clk); #1;
        cpu_write_en = 1; cpu_addr = 16'h2000;
        cpu_data_in = 8'hFF;

        wait(r_valid && r_last);
        @(posedge clk);
        @(posedge clk); #1;
        cpu_write_en = 0;
        
        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h2000;

        @(posedge clk); #1;
        cpu_read_en = 0;
        check_result(8'hFF, cpu_data_out, "Testcase 3: Write-Allocate Check  ");

        // Testcase 4: Matrix LRU Set Conflict & Dirty Eviction
        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h3000;

        wait(r_valid && r_last);

        @(posedge clk);
        @(posedge clk); #1;
        cpu_read_en = 0;

        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h4000;

        wait(r_valid && r_last);

        @(posedge clk);
        @(posedge clk); #1;
        cpu_read_en = 0;

        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h1000;

        @(posedge clk); #1;
        cpu_read_en = 0;

        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h5000;

        wait(w_valid && w_last);
        wait(r_valid && r_last);

        @(posedge clk);
        @(posedge clk); #1;
        cpu_read_en = 0;
        check_result(8'hFF, u_memory.mem[16'h2000], "Testcase 4: Dirty Line Eviction   ");

        // Testcase 5: 0-Latency Write Hit 
        @(posedge clk); #1;
        cpu_write_en = 1;
        cpu_addr = 16'h1000;
        cpu_data_in = 8'h99;

        @(posedge clk); #1;
        cpu_write_en = 0;

        // Testcase 6: Read Hit of Dirty Data
        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h1000;

        @(posedge clk); #1;
        cpu_read_en = 0;
        check_result(8'h99, cpu_data_out, "Testcase 6: Write Hit Saved Data  ");

        // Testcase 7: Different Index Allocation 
        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h1004;

        wait(r_valid && r_last);
        
        @(posedge clk);
        @(posedge clk); #1;
        cpu_read_en = 0;
        check_result(8'hEA, cpu_data_out, "Testcase 7: Index 1 Routing       ");

        // Testcase 8: Clean Line Eviction 
        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h1000;

        @(posedge clk); #1;
        cpu_read_en = 0;

        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h4000;

        @(posedge clk); #1;
        cpu_read_en = 0;

        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h5000;

        @(posedge clk); #1;
        cpu_read_en = 0;

        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h6000;
    

        wait(r_valid && r_last);
        @(posedge clk);
        @(posedge clk); #1;
        cpu_read_en = 0;
        check_result(8'h88, cpu_data_out, "Testcase 8: Clean Evict (No Write)");

        // Testcase 9: Byte Offset Hit
        @(posedge clk); #1;
        cpu_read_en = 1;
        cpu_addr = 16'h6002;
        @(posedge clk); #1;
        cpu_read_en = 0;
        check_result(8'h89, cpu_data_out, "Testcase 9: Byte Offset Select    ");

        $display("\n   -----------------------------------------");
        if (errors == 0)
            $display("   [SUCCESS] ALL TESTS PASSED! 0 ERRORS!");
        else
            $display("   [FAILED] %0d ERRORS FOUND.", errors);
        $display("   -----------------------------------------\n");

        $finish;
    end

endmodule