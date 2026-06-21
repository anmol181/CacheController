`timescale 1ns / 1ps

module cache_ctrl #(
    parameter AW = 16,
    parameter DW = 8,
    parameter B  = 4,
    parameter BW = $clog2(B)
)(
    input  wire          clk,
    input  wire          rst,

    input  wire [AW-1:0] cpu_addr,
    input  wire [DW-1:0] cpu_data_in,
    input  wire          cpu_valid,
    input  wire          cpu_we,
    output reg           cache_ready,
    output reg           cache_valid,

    input  wire          hit,
    input  wire          dirty,
    input  wire          valid,

    output reg           c_valid,
    output reg  [AW-1:0] cache_addr,
    output reg  [DW-1:0] cache_data_in,

    input  wire [AW-1:0] cache_miss_addr,
    input  wire [DW-1:0] cache_data_out,

    output reg           cache_read_en,
    output reg           cache_write_en,

    output reg           mem_write_en,
    output reg           mem_read_en,

    output reg  [AW-1:0] ar_addr,
    output reg  [7:0]    ar_len,
    output reg           ar_valid,
    input  wire          ar_ready,

    input  wire [DW-1:0] r_data,
    input  wire          r_valid,
    input  wire          r_last,
    output reg           r_ready,

    output reg  [AW-1:0] aw_addr,
    output reg  [7:0]    aw_len,
    output reg           aw_valid,
    input  wire          aw_ready,

    output reg  [DW-1:0] w_data,
    output reg           w_valid,
    output reg           w_last,
    input  wire          w_ready,

    output reg           bready
);

    reg [3:0] state;

    localparam st           = 0;
    localparam read_fetch   = 1;
    localparam mem_read     = 2;
    localparam mem_write    = 3;
    localparam write_back   = 4;
    localparam wait_state   = 5;
    localparam mem_read_req = 6;
    localparam wait_state_2 = 7;

    reg [AW-1:0] saved_addr;
    reg [DW-1:0] saved_data;
    reg          saved_we;

    reg [7:0] cnt;

    // fsm
    always @(posedge clk) begin
        if(rst) begin
            state      <= st;
            saved_addr <= {AW{1'b0}};
            saved_data <= {DW{1'b0}};
            saved_we   <= 1'b0;
            cnt        <= 8'b0;
        end
        else begin
            case(state)
                st : begin
                    if(cpu_valid) begin
                        saved_addr <= cpu_addr;
                        saved_data <= cpu_data_in;
                        saved_we   <= cpu_we;

                        if(cpu_we) state <= write_back;
                        else       state <= read_fetch;
                    end
                end

                write_back : begin
                    if(hit) begin
                        state <= st;
                    end
                    else begin
                        if (valid && dirty) state <= aw_ready ? mem_write : write_back;
                        else                state <= ar_ready ? mem_read  : write_back;
                    end
                end

                mem_read_req : begin
                    if(ar_ready) state <= mem_read;
                end

                mem_read : begin
                    if(r_valid && r_last) begin
                        state <= wait_state;
                        cnt <= 0;
                    end
                    else if(r_valid && r_ready) begin
                        cnt <= cnt + 1;
                    end
                end

                mem_write : begin
                    if(w_valid && w_ready) begin
                        if(cnt == B-1) begin
                            state <= mem_read_req;
                            cnt   <= 0;
                        end else begin
                            cnt <= cnt + 1;
                        end
                    end
                end

                read_fetch: begin
                    if (hit) begin
                        state <= st;
                    end
                    else begin
                        if (valid && dirty) state <= aw_ready ? mem_write : read_fetch;
                        else                state <= ar_ready ? mem_read  : read_fetch;
                    end
                end

                wait_state: begin
                    state <= wait_state_2;
                end

                wait_state_2: begin
                    state <= saved_we ? write_back : read_fetch;
                end

                default: state <= st;
            endcase
        end
    end

    // signal assignment
    always @(*) begin
        cache_ready    = 1'b0;
        cache_valid    = 1'b0;
        c_valid        = 1'b0;
        cache_addr     = saved_addr;
        cache_data_in  = cpu_data_in;
        cache_read_en  = 1'b0;
        cache_write_en = 1'b0;
        mem_write_en   = 1'b0;
        mem_read_en    = 1'b0;

        ar_addr  = {AW{1'b0}};
        ar_len   = 8'b0;
        ar_valid = 1'b0;
        r_ready  = 1'b0;

        aw_addr  = {AW{1'b0}};
        aw_len   = 8'b0;
        aw_valid = 1'b0;
        w_data   = cache_data_out;
        w_valid  = 1'b0;
        w_last   = 1'b0;
        bready   = 1'b1;

        case(state)
            st : begin
                if(cpu_valid) begin
                    c_valid        = 1'b1;
                    cache_addr     = cpu_addr;
                    cache_write_en = cpu_we;
                    cache_read_en  = !cpu_we;
                end else begin
                    cache_ready = 1'b1;
                end
            end

            write_back : begin
                if(hit) begin
                    cache_ready = 1'b1;
                    cache_valid = 1'b1;
                end
                else begin
                    if(valid && dirty) begin
                        aw_valid = 1'b1;
                        aw_addr  = cache_miss_addr;
                        aw_len   = B - 1;
                        mem_read_en   = 1'b1;
                        cache_read_en = 1'b1;

                        c_valid       = 1'b1;
                        cache_addr    = cache_miss_addr;
                    end
                    else begin
                        ar_valid = 1'b1;
                        ar_addr  = {saved_addr[AW-1:BW],{BW{1'b0}}};
                        ar_len   = B - 1;

                        c_valid    = 1'b1;
                        cache_addr = {saved_addr[AW-1:BW],{BW{1'b0}}};
                    end
                end
            end

            mem_read_req : begin
                ar_valid = 1'b1;
                ar_addr  = {saved_addr[AW-1:BW], {BW{1'b0}}};
                ar_len   = B - 1;

                c_valid    = 1'b1;
                cache_addr = {saved_addr[AW-1:BW], {BW{1'b0}}};
            end

            mem_read : begin
                r_ready = 1'b1;
                if(r_valid) begin
                    c_valid       = 1'b1;
                    cache_addr    = {saved_addr[AW-1:BW],{BW{1'b0}}} + cnt;
                    cache_data_in = r_data;
                    mem_write_en  = 1'b1;
                end
            end

            mem_write : begin
                w_valid = 1'b1;
                if (cnt == B-1) w_last = 1'b1;

                c_valid       = w_ready;
                mem_read_en   = w_ready;
                cache_read_en = w_ready;
                cache_addr    = cache_miss_addr + cnt + 1;
            end

            read_fetch : begin
                if(hit) begin
                    cache_ready = 1'b1;
                    cache_valid = 1'b1;
                end
                else begin
                    if(valid && dirty) begin
                        aw_valid = 1'b1;
                        aw_addr  = cache_miss_addr;
                        aw_len   = B - 1;

                        c_valid       = 1'b1;
                        mem_read_en   = 1'b1;
                        cache_read_en = 1'b1;
                        cache_addr    = cache_miss_addr;
                    end
                    else begin
                        ar_valid = 1'b1;
                        ar_addr  = {saved_addr[AW-1:BW],{BW{1'b0}}};
                        ar_len   = B - 1;

                        c_valid    = 1'b1;
                        cache_addr = {saved_addr[AW-1:BW],{BW{1'b0}}};
                    end
                end
            end

            wait_state_2 : begin
                c_valid        = 1'b1;
                cache_addr     = saved_addr;
                cache_data_in  = saved_data;
                cache_write_en = saved_we;
                cache_read_en  = !saved_we;
            end
        endcase
    end

endmodule