`timescale 1ns / 1ps

module cache_ctrl#(
    parameter AW = 32,
    parameter DW = 8,
    parameter W = 8,
    parameter S = 8,
    parameter B = 4,
    parameter WW = $clog2(W),
    parameter SW = $clog2(S),
    parameter BW = $clog2(B)
)(
    input wire clk,
    input wire rst,

    // --- cache signals ---
    input wire          cpu_req,
    input wire          cpu_rw,
    input wire [AW-1:0] cpu_addr,
    input wire [DW-1:0] cpu_wdata,
    output reg [DW-1:0] cpu_rdata,
    input wire          snoop_valid,
    output reg          ask_snoop, ////////////////////////////////////////////////////
    input wire          snoop_ask,

    // --- datapath signals ---
    input wire [AW-1:0] cache_miss_addr,
    input wire [1:0]    miss_mesi_state,
    input wire          hit,
    input wire          snoop_hit,
    output reg [AW-1:0] snoop_addr, ////////////////////////////////////////////////////

    output reg [AW-1:0] cache_addr,
    output reg [DW-1:0] cache_wdata,
    input wire [DW-1:0] cache_rdata,
    output reg          cache_req,
    output reg          cache_rw,
    output reg          mem_req,
    output reg          mem_rw,
    output reg          snoop_req,
    output reg          snoop_rw,
    output reg [1:0]    snoop_signal,
    output reg          snoop_stall,

    // --- memory signals ---
    output reg          ar_valid,
    output reg          ar_addr,
    output reg          ar_len,
    output reg          ar_ready,

    input wire          r_valid,
    input wire [DW-1:0] r_data,
    input wire          r_last,
    output reg          r_ready,

    output reg [AW-1:0] aw_addr,
    output reg          aw_valid,
    input wire          aw_ready,
    output reg          aw_len,

    output reg          w_valid,
    output reg [DW-1:0] w_data,
    input wire          w_ready,
    output reg          w_last

    );

    // --- fsm logic ---

    // inital state : st
    // if cpu_rw == 0 && cpu_req == 1 st = cpu_read
        // if  hit : state = st
        // else
            // if miss state == M
                // state : mem_write then
                // if snoop_hit
                    // state = snoop_read
                    // else mem_read
            // else
                // if snoop_hit
                    // state = snoop_read - | then cpu read
                // else state = mem_read -- | then cpu read
    // if cpu_rw == 1 && cpu_req == 1 st = cpu_write
        // if hit : state = st;
        // if miss state == M
                // state : mem_write then
                // if snoop_hit
                    // state = snoop_read
                    // else mem_read
            // else
                // if snoop_hit
                    // state = snoop_read - | then cpu write
                // else state = mem_read -- | then cpu write

    localparam st = 0;
    localparam cpu_read = 1;
    localparam cpu_write = 2;
    localparam mem_read = 3;
    localparam mem_write = 4;
    localparam snoop_read = 5;
    localparam snoop_write = 6;// stall case : where cache needs to give data to other cores
    localparam mem_read_req = 7;
    localparam mem_write_req = 8;
    localparam wt = 9;

    localparam m = 0;
    localparam e = 1;
    localparam s = 2;
    localparam i = 3;

    reg [3:0] state;
    reg [3:0] saved_state;

    reg saved_snoop_hit;
    reg saved_cpu_rw;
    reg saved_cpu_req;
    reg [AW-1:0] saved_addr;
    reg [DW-1:0] saved_cpu_wdata;

    reg [7:0] cnt_mem;
    reg [7:0] cnt_snoop;

    // --- fsm logic ---
    always @(posedge clk) begin
        if(rst) begin
            state <= st;
            cnt_mem <= 0;
            cnt_snoop <= 0;
        end
        else begin
            if (snoop_ask && state != snoop_write && state != mem_read && state != mem_write && state != mem_read_req && state != mem_write_req) begin
                saved_state <= state;
                state <= snoop_write;
                cnt_snoop <= 0;
            end
            else begin
                case(state)
                    st : begin
                        if(cpu_req) begin
                            state <= cpu_rw ? cpu_write : cpu_read;
                            saved_cpu_rw <= cpu_rw;
                            saved_cpu_req <= cpu_req;
                            saved_addr <= cpu_addr;
                            saved_cpu_wdata <= cpu_wdata;
                        end
                    end
                    cpu_read, cpu_write : begin
                        saved_snoop_hit <= snoop_hit;
                        if(hit) begin
                            state <= st;
                        end
                        else begin
                            if(miss_mesi_state == m) begin
                                state <= (aw_ready) ? mem_write : mem_write_req;
                            end
                            else begin
                                if(snoop_hit) state <= snoop_read;
                                else          state <= (ar_ready) ? mem_read : mem_read_req;
                            end
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
                                state <= wt;
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
                                state <= saved_snoop_hit ? snoop_read : (ar_ready ? mem_read : mem_read_req);
                            end else begin
                                cnt_mem <= cnt_mem + 1;
                            end
                        end
                    end
                    snoop_read : begin
                        if(r_last && snoop_valid) begin
                            state <= wt;
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
                    default : state <= st;
                endcase
            end
        end
    end

    // signal assignment
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
        snoop_stall  = 0;
        snoop_addr   = 0;
        snoop_rw     = 0;
        snoop_signal = 0;
        snoop_req    = 0;
        cpu_rdata    = 0;

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
                if(!hit) begin
                    if(miss_mesi_state == m) begin
                        if(aw_ready) begin
                            aw_valid = 1'b1;
                            aw_addr  = cache_miss_addr;
                            aw_len   = B-1;
                        end
                    end
                    else begin
                        if(saved_snoop_hit) begin
                            ask_snoop = 1'b1;
                        end
                        else if(ar_ready) begin
                            ar_valid = 1'b1;
                            ar_addr  = saved_addr;
                            ar_len   = B-1;
                        end
                    end
                end
                // On hit, pass data back to CPU
                if (hit && state == cpu_read) cpu_rdata = cache_rdata;
            end
            mem_write_req : begin
                aw_valid = 1'b1;
                aw_addr  = cache_miss_addr;
                aw_len   = B-1;
            end
            mem_read_req : begin
                ar_valid = 1'b1;
                ar_addr  = saved_addr;
                ar_len   = B-1;
            end
            mem_write : begin
                w_data   = cache_rdata;
                w_valid  = 1'b1;
                w_last   = (cnt_mem == B-1);
                mem_req  = 1'b1;
                mem_rw   = 1'b1;
                cache_addr = cache_miss_addr + cnt_mem;
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
            snoop_write : begin
                snoop_stall  = 1'b1;
                snoop_addr   = {saved_addr[AW-1:BW], {BW{1'b0}}} + cnt_snoop;
                snoop_rw     = 1'b0;
                snoop_signal = 2'b01;
            end
            wt : begin
                cache_addr  = saved_addr;
                cache_rw    = saved_cpu_rw;
                cache_req   = saved_cpu_req;
                cache_wdata = saved_cpu_wdata;
            end
        endcase
    end

endmodule
