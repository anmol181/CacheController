`timescale 1ns / 1ps

module snoop#(
    parameter AW = 16,            // Address Width
    parameter DW = 8,             // Data Width (8-bit bytes)
    parameter B = 4,              // Number of Words in a Block
    parameter BW = $clog2(B)      // Block Offset Width
)(
    input wire                  clk,
    input wire                  rst,

    // --- core 0 signals ---
    input wire                  cpu_req0,
    output reg                  snoop_req0,
    input wire                  cpu_rw0,
    input wire                  cpu_hit0,
    input wire                  snoop_hit_out0,
    input wire [AW-1:0]         cpu_addr0,
    output reg [AW-1:0]         snoop_addr0,
    output reg [1:0]            snoop_signal0,
    output reg                  snoop_stall0,
    output reg [DW-1:0]         snoop_rdata0,
    input wire [DW-1:0]         snoop_wdata0,
    input wire                  snoop_ask0,
    input wire                  snoop_dirty0,
    input wire                  snoop_valid0,
    output reg                  snoop_data_valid0, // Added: Tells core 0 when snoop_rdata is valid
    output wire                 snoop_hit_in0,
    // --- core 1 signals ---
    input wire                  cpu_req1,
    output reg                  snoop_req1,
    input wire                  cpu_rw1,
    input wire                  cpu_hit1,
    input wire                  snoop_hit_out1,
    input wire [AW-1:0]         cpu_addr1,
    output reg [AW-1:0]         snoop_addr1,
    output reg [1:0]            snoop_signal1,
    output reg                  snoop_stall1,
    output reg [DW-1:0]         snoop_rdata1,
    input wire [DW-1:0]         snoop_wdata1,
    input wire                  snoop_ask1,
    input wire                  snoop_dirty1,
    input wire                  snoop_valid1,
    output reg                  snoop_data_valid1, // Added: Tells core 1 when snoop_rdata is valid
    output wire                 snoop_hit_in1,

    // --- core 0 memory interface ---
    input wire [AW-1:0]         mem_aw_addr0,
    input wire [7:0]            mem_aw_len0,
    input wire                  mem_aw_valid0,
    output reg                  mem_aw_ready0,

    input wire [DW-1:0]         mem_w_data0,
    input wire                  mem_w_last0,
    input wire                  mem_w_valid0,
    output reg                  mem_w_ready0,

    // Read Channels
    input wire [AW-1:0]         mem_ar_addr0,
    input wire [7:0]            mem_ar_len0,
    input wire                  mem_ar_valid0,
    output reg                  mem_ar_ready0,

    output reg  [DW-1:0]        mem_r_data0,
    output reg                  mem_r_last0,
    output reg                  mem_r_valid0,
    input wire                  mem_r_ready0,

    // --- core 1 memory interface ---
    input wire [AW-1:0]         mem_aw_addr1,
    input wire [7:0]            mem_aw_len1,
    input wire                  mem_aw_valid1,
    output reg                  mem_aw_ready1,

    input wire [DW-1:0]         mem_w_data1,
    input wire                  mem_w_last1,
    input wire                  mem_w_valid1,
    output reg                  mem_w_ready1,

    // Read Channels
    input wire [AW-1:0]         mem_ar_addr1,
    input wire [7:0]            mem_ar_len1,
    input wire                  mem_ar_valid1,
    output reg                  mem_ar_ready1,

    output reg  [DW-1:0]        mem_r_data1,
    output reg                  mem_r_last1,
    output reg                  mem_r_valid1,
    input wire                  mem_r_ready1,

    // --- memory interface signals ---
    // Write Channels
    output reg [AW-1:0]         mem_aw_addr,
    output reg [7:0]            mem_aw_len,
    output reg                  mem_aw_valid,
    input wire                  mem_aw_ready,

    output reg [DW-1:0]         mem_w_data,
    output reg                  mem_w_last,
    output reg                  mem_w_valid,
    input wire                  mem_w_ready,

    // Read Channels
    output reg [AW-1:0]         mem_ar_addr,
    output reg [7:0]            mem_ar_len,
    output reg                  mem_ar_valid,
    input wire                  mem_ar_ready,

    input wire  [DW-1:0]        mem_r_data,
    input wire                  mem_r_last,
    input wire                  mem_r_valid,
    output reg                  mem_r_ready
);

    reg toggle; // toggles between 0 and 1 to select core on the basis of most recent used
    // if core 0 uses memory -> toggle will be set to 1
    // if core 1 uses memory -> toggle will be set to 0
    // if both requests memory at same time -> toggle will toggle from 0 to 1 or 1 to 0 depending on the current state0

    wire core0_mem_req = mem_aw_valid0 || mem_ar_valid0;
    wire core1_mem_req = mem_aw_valid1 || mem_ar_valid1;
    assign snoop_hit_in0 = snoop_hit_out1;
    assign snoop_hit_in1 = snoop_hit_out0;

    always @(posedge clk) begin
        if (rst) begin
            toggle <= 1'b0;
        end else begin
            toggle <= ~toggle;
        end
    end

    // reg [3:0] state0;
    // reg [3:0] state1;

    reg [AW-1:0] saved_cpu_addr0;
    reg [AW-1:0] saved_cpu_addr1;

    // reg saved_snoop_hit_out0;
    // reg saved_snoop_hit_out1;

    reg [7:0] cnt0;
    reg [7:0] cnt1;

    // fsm

    // handling core 0
    localparam st     = 4'd0;
    localparam check0 = 4'd1;
    localparam wt0    = 4'd3;
    localparam data0  = 4'd5;
    localparam check1 = 4'd2;
    localparam wt1    = 4'd4;
    localparam data1  = 4'd6;

    reg [3:0] snoop_state;
    reg [7:0] snoop_cnt;
    // --- Background Write-Back Buffer ---
    reg [DW-1:0] wb_buffer [0:B-1];
    reg          wb_req;
    reg          wb_ack;
    reg [AW-1:0] wb_addr;
    reg [7:0]    wb_cnt;
    reg          wb_aw_sent;
    reg          saved_snoop_dirty0;
    reg          saved_snoop_dirty1;
    reg          saved_cpu_rw0;
    reg          saved_cpu_rw1;

    // --- snoop fsm (Sequential) ---
    always @(posedge clk) begin
        if (wb_ack) wb_req <= 1'b0;
        
        if (rst) begin
            snoop_state <= st;
            snoop_cnt <= 0;
        end else begin
            case(snoop_state)
                st: begin
                    // State Transitions RESTORED!
                    if (cpu_req0 && cpu_req1) begin
                        snoop_state <= toggle ? check1 : check0;
                        snoop_cnt <= 0;
                    end else if (cpu_req0) begin
                        snoop_state <= check0;
                        snoop_cnt <= 0;
                    end else if (cpu_req1) begin
                        snoop_state <= check1;
                        snoop_cnt <= 0;
                    end
                    saved_cpu_addr0 <= cpu_addr0;
                    saved_cpu_addr1 <= cpu_addr1;
                    saved_cpu_rw0 <= cpu_rw0;
                    saved_cpu_rw1 <= cpu_rw1;
                end

                check0: begin
                    if (snoop_hit_out1) begin
                        if (cpu_hit0) snoop_state <= st;
                        else          snoop_state <= data0;
                    end else begin
                        snoop_state <= st;
                    end
                    saved_snoop_dirty0 <= snoop_dirty0;
                    saved_snoop_dirty1 <= snoop_dirty1;
                end

                wt0: begin
                    if (snoop_ask0) snoop_state <= data0;
                end

                check1: begin
                    if (snoop_hit_out0) begin
                        if (cpu_hit1) snoop_state <= st;
                        else          snoop_state <= data1;
                    end else begin
                        snoop_state <= st;
                    end
                    saved_snoop_dirty0 <= snoop_dirty0;
                    saved_snoop_dirty1 <= snoop_dirty1;
                end

                wt1: begin
                    if (snoop_ask1) snoop_state <= data1;
                end

                data0: begin
                    // Valid condition decoupled!
                    if (snoop_cnt > 0 && saved_snoop_dirty1) begin
                        wb_buffer[snoop_cnt - 1] <= snoop_wdata1;
                    end

                    if (snoop_cnt == B) begin
                        snoop_state <= st;
                        if (saved_snoop_dirty1) begin
                            wb_req  <= 1'b1;
                            wb_addr <= {saved_cpu_addr0[AW-1:BW], {BW{1'b0}}};
                        end
                    end else begin
                        snoop_cnt <= snoop_cnt + 1;
                    end
                end

                data1: begin
                    // Valid condition decoupled!
                    if (snoop_cnt > 0 && saved_snoop_dirty0) begin
                        wb_buffer[snoop_cnt - 1] <= snoop_wdata0;
                    end

                    if (snoop_cnt == B) begin
                        snoop_state <= st;
                        if (saved_snoop_dirty0) begin
                            wb_req  <= 1'b1;
                            wb_addr <= {saved_cpu_addr1[AW-1:BW], {BW{1'b0}}};
                        end
                    end else begin
                        snoop_cnt <= snoop_cnt + 1;
                    end
                end
                default: snoop_state <= st;
            endcase
        end
    end

    // --- signal assignments (Combinational) ---
    always @(*) begin
        // Defaults
        snoop_req0    = 0;
        snoop_addr0   = 0;
        snoop_signal0 = 0;
        snoop_stall0  = 0;
        snoop_rdata0  = 0;
        snoop_data_valid0 = 0;

        snoop_req1    = 0;
        snoop_addr1   = 0;
        snoop_signal1 = 0;
        snoop_stall1  = 0;
        snoop_rdata1  = 0;
        snoop_data_valid1 = 0;

        case(snoop_state)
            st: begin
                if (cpu_req0 && cpu_req1) begin
                    if (toggle) begin 
                        snoop_req0    = 1'b1;
                        snoop_addr0   = cpu_addr1;
                        snoop_signal0 = (cpu_rw1 && cpu_hit1) ? 2'b11 : 2'b01; 
                    end else begin 
                        snoop_req1    = 1'b1;
                        snoop_addr1   = cpu_addr0;
                        snoop_signal1 = (cpu_rw0 && cpu_hit0) ? 2'b11 : 2'b01;
                    end
                end
                else if (cpu_req0) begin
                    snoop_req1    = 1'b1;
                    snoop_addr1   = cpu_addr0;
                    snoop_signal1 = (cpu_rw0 && cpu_hit0) ? 2'b11 : 2'b01;
                end
                else if (cpu_req1) begin
                    snoop_req0    = 1'b1;
                    snoop_addr0   = cpu_addr1;
                    snoop_signal0 = (cpu_rw1 && cpu_hit1) ? 2'b11 : 2'b01;
                end
            end

            check0: begin
                snoop_req1    = 1'b1;
                snoop_addr1   = saved_cpu_addr0;
                snoop_signal1 = (saved_cpu_rw0 && cpu_hit0) ? 2'b11 : 2'b01; 
            end

            check1: begin
                snoop_req0    = 1'b1;
                snoop_addr0   = saved_cpu_addr1;
                snoop_signal0 = (saved_cpu_rw1 && cpu_hit1) ? 2'b11 : 2'b01;
            end

            wt0, wt1: begin
                // No snoop signals asserted while waiting.
            end

            data0: begin
                snoop_stall1  = 1'b1;
                snoop_rdata0  = snoop_wdata1;
                snoop_data_valid0 = (snoop_cnt > 0); 
                
                if(snoop_cnt < B) begin
                    snoop_addr1   = {saved_cpu_addr0[AW-1:BW], {BW{1'b0}}} + snoop_cnt;
                    // THE SNIPER SHOT 
                    snoop_signal1 = (saved_cpu_rw0 && (snoop_cnt == B - 1)) ? 2'b11 : 2'b01;
                    snoop_req1    = 1'b1;
                end
            end

            data1: begin
                snoop_stall0  = 1'b1;
                snoop_rdata1  = snoop_wdata0;
                snoop_data_valid1 = (snoop_cnt > 0); 
                
                if(snoop_cnt < B) begin
                    snoop_addr0   = {saved_cpu_addr1[AW-1:BW], {BW{1'b0}}} + snoop_cnt;
                    // THE SNIPER SHOT 
                    snoop_signal0 = (saved_cpu_rw1 && (snoop_cnt == B - 1)) ? 2'b11 : 2'b01;
                    snoop_req0    = 1'b1;
                end
            end
        endcase
    end

    localparam mem_st = 0;
    localparam mem_core0 = 1;
    localparam mem_core1 = 2;
    localparam mem_bg_wb = 3;

    reg [3:0] mem_state;

    always @(posedge clk) begin
        if (rst) begin
            mem_state <= mem_st;
            wb_ack <= 1'b0;
            wb_aw_sent <= 1'b0;
            wb_cnt <= 0;
        end else begin
        case(mem_state)
            mem_st : begin
                wb_ack <= 1'b0;
                wb_aw_sent <= 1'b0;

                if (wb_req) begin
                    mem_state <= mem_bg_wb;
                    wb_ack <= 1'b1;
                    wb_cnt <= 0;
                end
                else if ( (mem_aw_valid0 || mem_ar_valid0) && (mem_aw_valid1 || mem_ar_valid1) ) begin
                    if (toggle) mem_state <= mem_core1;
                    else        mem_state <= mem_core0;
                end
                else if (mem_aw_valid0 || mem_ar_valid0) begin
                    mem_state <= mem_core0;
                end
                else if (mem_aw_valid1 || mem_ar_valid1) begin
                    mem_state <= mem_core1;
                end
            end
            mem_core0 : begin
                if((mem_r_valid && mem_r_ready && mem_r_last) || (mem_w_valid0 && mem_w_ready0 && mem_w_last0)) begin
                    mem_state <= mem_st;
                end
            end
            mem_core1 : begin
                if((mem_r_valid && mem_r_ready && mem_r_last) || (mem_w_valid1 && mem_w_ready1 && mem_w_last1)) begin
                    mem_state <= mem_st;
                end
            end
            mem_bg_wb: begin
                wb_ack <= 1'b0; // Lower the ack

                // Track AXI Address Handshake
                if (mem_aw_valid && mem_aw_ready) wb_aw_sent <= 1'b1;

                // Track AXI Data Handshake (Slow AXI Speed)
                if (mem_w_valid && mem_w_ready) begin
                    if (mem_w_last) begin
                        mem_state <= mem_st;
                    end else begin
                        wb_cnt <= wb_cnt + 1;
                    end
                end
            end
        endcase
        end
    end

    always @(*) begin
        mem_aw_addr = 0;
        mem_aw_len = 0;
        mem_aw_valid = 0;

        mem_w_data = 0;
        mem_w_last = 0;
        mem_w_valid = 0;

        mem_ar_addr = 0;
        mem_ar_len = 0;
        mem_ar_valid = 0;

        mem_r_ready = 0;

        mem_aw_ready0 = 0;
        mem_w_ready0 = 0;
        mem_ar_ready0 = 0;
        mem_r_data0 = 0;
        mem_r_last0 = 0;
        mem_r_valid0 = 0;

        mem_aw_ready1 = 0;
        mem_w_ready1 = 0;
        mem_ar_ready1 = 0;
        mem_r_data1 = 0;
        mem_r_last1 = 0;
        mem_r_valid1 = 0;
        case(mem_state)
            mem_core0 : begin
                mem_aw_addr = mem_aw_addr0;
                mem_aw_len = mem_aw_len0;
                mem_aw_valid = mem_aw_valid0;
                mem_aw_ready0 = mem_aw_ready;

                mem_w_data = mem_w_data0;
                mem_w_last = mem_w_last0;
                mem_w_valid = mem_w_valid0;
                mem_w_ready0 = mem_w_ready;

                mem_ar_addr = mem_ar_addr0;
                mem_ar_len = mem_ar_len0;
                mem_ar_valid = mem_ar_valid0;
                mem_ar_ready0 = mem_ar_ready;

                mem_r_data0 = mem_r_data;
                mem_r_last0 = mem_r_last;
                mem_r_valid0 = mem_r_valid;
                mem_r_ready = mem_r_ready0;
            end
            mem_core1 : begin
                mem_aw_addr = mem_aw_addr1;
                mem_aw_len = mem_aw_len1;
                mem_aw_valid = mem_aw_valid1;
                mem_aw_ready1 = mem_aw_ready;

                mem_w_data = mem_w_data1;
                mem_w_last = mem_w_last1;
                mem_w_valid = mem_w_valid1;
                mem_w_ready1 = mem_w_ready;

                mem_ar_addr = mem_ar_addr1;
                mem_ar_len = mem_ar_len1;
                mem_ar_valid = mem_ar_valid1;
                mem_ar_ready1 = mem_ar_ready;

                mem_r_data1 = mem_r_data;
                mem_r_last1 = mem_r_last;
                mem_r_valid1 = mem_r_valid;
                mem_r_ready = mem_r_ready1;
            end
            mem_bg_wb: begin
                // We are acting as the AXI Master, writing the buffer to Main Memory
                mem_aw_valid = !wb_aw_sent;
                mem_aw_addr  = wb_addr;
                mem_aw_len   = B - 1;

                // Only assert Data Valid AFTER the Address has been accepted!
                mem_w_valid  = wb_aw_sent;  

                mem_w_data   = wb_buffer[wb_cnt];
                mem_w_last   = (wb_cnt == B - 1);
            end
        endcase
    end

endmodule
