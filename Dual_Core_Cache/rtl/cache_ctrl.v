`timescale 1ns / 1ps

module cache_ctrl#(
    parameter AW = 16,
    parameter DW = 8,
    parameter B = 4,
    parameter S = 8,
    parameter W = 8,
    parameter BW = $clog2(B),
    parameter SW = $clog2(S),
    parameter WW = $clog2(W)
)(
    input wire clk,
    input wire rst,

    // --- cache signals ---
    input wire          cpu_req,
    input wire          cpu_rw,
    input wire [AW-1:0] cpu_addr,
    input wire [DW-1:0] cpu_wdata,
    output reg [DW-1:0] cpu_rdata,
    output reg          cpu_ready, 

    // --- interconnect signals ---
    output reg          ask_snoop,
    input wire          snoop_stall,
    input wire          snoop_data_valid, 
    input wire [DW-1:0] snoop_data_in, 

    // --- datapath signals ---
    input wire [AW-1:0] cache_miss_addr,
    input wire [1:0]    miss_mesi_state,
    input wire          hit,
    input wire          snoop_hit_in, // Updated Port Name!
    

    output reg [AW-1:0] cache_addr,
    output reg [DW-1:0] cache_wdata,
    input wire [DW-1:0] cache_rdata,
    output reg          cache_req,
    output reg          cache_rw,
    output reg          mem_req,
    output reg          mem_rw,

    // --- memory signals ---
    output reg          ar_valid,
    output reg [AW-1:0] ar_addr,
    output reg [7:0]    ar_len,
    input  wire         ar_ready,

    input wire          r_valid,
    input wire [DW-1:0] r_data,
    input wire          r_last,
    output reg          r_ready,

    output reg [AW-1:0] aw_addr,
    output reg          aw_valid,
    input wire          aw_ready,
    output reg [7:0]    aw_len,

    output reg          w_valid,
    output reg [DW-1:0] w_data,
    input wire          w_ready,
    output reg          w_last
);

    localparam st = 0;
    localparam cpu_read = 1;
    localparam cpu_write = 2;
    localparam mem_read = 3;
    localparam mem_write = 4;
    localparam snoop_read = 5;
    localparam snoop_write = 6;
    localparam mem_read_req = 7;
    localparam mem_write_req = 8;
    localparam wt = 9;
    localparam fill_wait = 10;

    localparam m = 2'b11;

    reg [3:0] state;
    reg [3:0] saved_state;

    reg saved_cpu_rw;
    reg saved_cpu_req;
    reg [AW-1:0] saved_addr;
    reg [AW-1:0] saved_miss_addr;
    reg [DW-1:0] saved_cpu_wdata;

    reg [7:0] cnt_mem;
    reg [7:0] cnt_snoop;

    // --- fsm logic ---
    always @(posedge clk) begin
        if(rst) begin
            state <= st;
            saved_state <= st;
            cnt_mem <= 0;
            cnt_snoop <= 0;
        end
        else begin
            // Burst Lock
            if (snoop_stall && state != snoop_write && state != mem_read && state != mem_write && state != mem_read_req && state != mem_write_req) begin
                saved_state <= state;
                state <= snoop_write;
                cnt_snoop <= 0;
            end
            else begin
                case(state)
                    st : begin
                        saved_cpu_rw <= cpu_rw;
                        saved_cpu_req <= cpu_req;
                        saved_addr <= cpu_addr;
                        saved_cpu_wdata <= cpu_wdata;
                        if(cpu_req) begin
                            state <= cpu_rw ? cpu_write : cpu_read;
                        end
                    end
                    cpu_read, cpu_write : begin
                        if(!hit) begin
                            if(miss_mesi_state == m) begin
                                // THE FIX: Latch the victim address before we touch anything!
                                saved_miss_addr <= cache_miss_addr;

                                state <= (aw_ready) ? mem_write : mem_write_req;
                            end
                            else begin
                                if(snoop_hit_in) state <= snoop_read;
                                else             state <= (ar_ready) ? mem_read : mem_read_req;
                            end
                        end
                        else begin
                            state <= st;
                        end
                    end
                    mem_write_req : begin
                        if (aw_ready) state <= mem_write;
                    end
                    mem_read_req : begin
                        if (ar_ready) state <= mem_read;
                    end
                    mem_read : begin
                        if(r_ready && r_valid) begin
                            if(r_last) begin
                                state <= fill_wait;
                                cnt_mem <= 0;
                            end else begin
                                cnt_mem <= cnt_mem + 1;
                            end
                        end
                    end
                    mem_write : begin
                        if(w_ready && w_valid) begin
                            if(w_last) begin
                                cnt_mem <= 0;
                                // Jump directly to snoop read if the snoop triggered this write-back
                                state <= snoop_hit_in ? snoop_read : (mem_read_req);
                            end else begin
                                cnt_mem <= cnt_mem + 1;
                            end
                        end
                    end
                    snoop_read : begin
                        if (snoop_data_valid) begin
                            if (cnt_mem == B-1) begin
                                state <= fill_wait;
                                cnt_mem <= 0;
                            end else begin
                                cnt_mem <= cnt_mem + 1;
                            end
                        end
                    end
                    snoop_write : begin
                        if(cnt_snoop == B-1) begin
                            cnt_snoop <= 0;
                            state <= saved_state;
                        end else begin
                            cnt_snoop <= cnt_snoop + 1;
                        end
                    end
                    wt : begin
                        state <= saved_cpu_rw ? cpu_write : cpu_read;
                    end
                    fill_wait : begin
                        state <= wt;
                    end
                    default : state <= st;
                endcase
            end
        end
    end

    // --- combinational assignments ---
    always @(*) begin
        // DEFAULT ASSIGNMENTS
        cache_addr   = saved_addr;
        cache_wdata  = 0;
        cache_req    = 0;
        cache_rw     = 0;
        mem_req      = 0;
        mem_rw       = 0;
        ar_valid     = 0;
        ar_addr      = 0;
        ar_len       = 0;
        aw_valid     = 0;
        aw_addr      = 0;
        aw_len       = 0;
        w_valid      = 0;
        w_data       = 0;
        w_last       = 0;
        r_ready      = 0;
        ask_snoop    = 0;
        cpu_rdata    = 0;
        cpu_ready    = 0;

        case(state)
            st : begin
                if(cpu_req) begin
                    cache_addr  = cpu_addr;
                    cache_wdata = cpu_wdata;
                    cache_req   = 1'b1;
                    cache_rw    = cpu_rw;
                end
            end
            cpu_read, cpu_write : begin

                // Pipeline Keep-Alive!
                cache_req   = 1'b1;
                cache_rw    = saved_cpu_rw;
                cache_wdata = saved_cpu_wdata;

                if(!hit) begin
                    if(miss_mesi_state == m) begin
                        if(aw_ready) begin
                            aw_valid = 1'b1;
                            aw_addr  = cache_miss_addr;
                            aw_len   = B-1;
                        end
                    end
                    else begin
                        // AXI Request logic. Interconnect handles Snoop logic directly now.
                        if(ar_ready && !snoop_hit_in) begin
                            ar_valid = 1'b1;
                            ar_addr  = saved_addr;
                            ar_len   = B-1;
                        end
                    end
                end

                if (hit) begin
                    cpu_ready = 1'b1;
                    if (state == cpu_read) cpu_rdata = cache_rdata;
                end
            end
            mem_write_req : begin
                aw_valid = 1'b1;
                aw_addr  = {saved_miss_addr[AW-1:BW], {BW{1'b0}}};
                aw_len   = B - 1;

                cache_req  = 1'b1;
                cache_addr = {saved_miss_addr[AW-1:BW], cnt_mem[BW-1:0]};
            end
            mem_write : begin
                w_valid = 1'b1;
                w_last  = (cnt_mem == B - 1);
                w_data  = cache_rdata; // THE FIX: Push the evicted data to the AXI bus!

                cache_req  = 1'b1;
                if (w_ready && w_valid && !w_last) begin
                    cache_addr = {saved_miss_addr[AW-1:BW], (cnt_mem[BW-1:0] + 1'b1)};
                end else begin
                    cache_addr = {saved_miss_addr[AW-1:BW], cnt_mem[BW-1:0]};
                end
            end
            mem_read_req : begin
                ar_valid = 1'b1;
                ar_addr  = {saved_addr[AW-1:BW], {BW{1'b0}}};
                ar_len   = B-1;
            end
            mem_read : begin
                r_ready  = 1'b1;
                if(r_valid) begin
                    cache_addr  = {saved_addr[AW-1:BW], {BW{1'b0}}} + cnt_mem;
                    cache_wdata = r_data;
                    mem_rw      = 1'b1;
                    mem_req     = 1'b1;
                end
            end
            snoop_read : begin
                ask_snoop = 1'b1; // Still asserted purely to keep the interconnect pipeline happy
                if (snoop_data_valid) begin
                    cache_addr  = {saved_addr[AW-1:BW], {BW{1'b0}}} + cnt_mem;
                    cache_wdata = snoop_data_in;
                    mem_rw      = 1'b1;
                    mem_req     = 1'b1;
                end
            end
            snoop_write : begin
                // Datapath provides data natively
            end
            wt : begin
                cache_addr  = saved_addr;
                cache_rw    = saved_cpu_rw;
                cache_req   = saved_cpu_req;
                cache_wdata = saved_cpu_wdata;
            end
            fill_wait : begin
                // Do nothing, just wait for the next cycle to write to cache
            end
        endcase
    end

endmodule
