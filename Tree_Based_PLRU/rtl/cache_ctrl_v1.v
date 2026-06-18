`timescale 1ns / 1ps

module cache_ctrl #(
    parameter AW = 16,
    parameter DW = 32,
    parameter B  = 4,
    parameter BW = $clog2(B)
)(
    input  wire          clk,
    input  wire          rst,

    // --- CPU Interface  ---
    // Request Channel
    input  wire [AW-1:0] cpu_addr,
    input  wire [DW-1:0] cpu_data_in,
    input  wire          cpu_valid,
    input  wire          cpu_we,
    output reg           cache_ready,
    output reg           cache_valid,
    
    // Response Channel
    // output reg           cache_resp_valid,  // Cache has read data ready
    // input  wire          cpu_resp_ready,    // CPU is ready to accept read data

    // --- Datapath Interface ---
    input  wire          hit,
    input  wire          dirty,
    input  wire          valid,
    // output reg           miss,

    output reg           c_valid,
    output reg  [AW-1:0] cache_addr,
    output reg  [DW-1:0] cache_data_in, // data that goes into datapath
    
    input  wire [AW-1:0] cache_miss_addr,
    input  wire [DW-1:0] cache_data_out,

    output reg           cache_read_en,
    output reg           cache_write_en,

    // output reg           mem_read_en,
    output reg           mem_write_en,

    // --- AXI4 Master Interface (To Main Memory) ---
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
    
    // input  wire          bvalid,
    output reg           bready
);

    reg [2:0] state;

    // if read  = 1 state = read fetch
    //   if hit = 1 state = read hit
    //   else if check for dirty and valid
        //      if valid = 0 state = mem read 
        //      -> then state = read fetch 
        //      -> then state = read hit
        //      else if dirty = 0 state = mem read
        //      -> then state = read fetch 
        //      -> then state = read hit
        //      else state = mem write 
        //      -> then state = mem read
        //      -> then state = read fetch
        //      -> then state = read hit
    // if write = 1 state = write back
    //   if hit = 1 state = write hit
    //   else if check for dirty and valid
        //      if valid = 0 state = mem read
        //      -> then state = write back
        //      else if dirty = 0 state = mem read
        //      -> then state = write back
        //      else state = mem write
        //      -> then state = mem read
        //      -> then state = write back
    
    localparam st = 0;
    localparam read_fetch = 1;
    localparam read_hit = 2;
    localparam mem_read = 3;
    localparam mem_write = 4;
    localparam write_back = 5;
    localparam write_hit = 6;

    reg [AW-1:0] saved_addr;

    reg [7:0] cnt;

    // fsm
    always @(posedge clk) begin
        if(rst) begin
            state      <= st;
            saved_addr <= {AW{1'b0}};
            cnt        <= 8'b0;
        end
        else begin
            case(state)
                st : begin
                    if(cpu_valid) saved_addr <= cpu_addr;

                    if(cpu_valid) begin
                        if(cpu_we) state <= write_back;
                        else       state <= read_fetch;
                    end
                end
                
                write_back : begin
                    if(hit) begin
                        state <= write_hit;
                    end 
                    else begin
                        if (valid && dirty) state <= aw_ready ? mem_write : write_back;
                        else                state <= ar_ready ? mem_read  : write_back;
                    end
                end
                
                write_hit : begin
                    state <= st;
                end
                
                mem_read : begin
                    if(r_valid && r_last) begin
                        state <= read_fetch;
                        cnt <= 0;
                    end

                    else if(r_valid && r_ready) cnt <= cnt + 1;
                end
                
                mem_write : begin
                    if(w_valid && w_ready) begin
                        if(cnt == B-1) begin
                            state <= mem_read;
                            cnt   <= 0;
                        end else begin
                            cnt <= cnt + 1;
                        end
                    end
                end
                
                read_fetch: begin
                    if (hit) state <= read_hit;
                    else begin
                        if (valid && dirty) state <= aw_ready ? mem_write : read_fetch;
                        else                state <= ar_ready ? mem_read  : read_fetch;
                    end
                end
                
                read_hit: begin
                    state <= st;
                end
            endcase
        end
    end

    always @(*) begin
        cache_ready    = 1'b0;
        cache_valid    = 1'b0;
        c_valid        = 1'b0;
        cache_addr     = saved_addr;
        cache_data_in  = cpu_data_in;
        cache_read_en  = 1'b0;
        cache_write_en = 1'b0;
        // mem_read_en    = 1'b0;
        mem_write_en   = 1'b0;
        // miss           = 1'b0;

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
                if(!hit) begin
                    // miss = 1'b1;
                    if(valid && dirty) begin
                        aw_valid = 1'b1;
                        aw_addr  = cache_miss_addr;
                        aw_len   = B - 1;
                        
                        c_valid       = 1'b1;
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
            
            write_hit : begin
                cache_ready = 1'b1;
                cache_valid = 1'b1;
            end
            
            mem_read : begin
                r_ready = 1'b1;
                if(r_valid) begin
                    c_valid      = 1'b1;
                    cache_addr   = {saved_addr[AW-1:BW],{BW{1'b0}}} + cnt; 
                    cache_data_in= r_data;
                    mem_write_en = 1'b1;
                end
            end
            
            mem_write : begin
                w_valid = 1'b1;
                if (cnt == B-1) w_last = 1'b1;
                
                c_valid       = w_ready; 
                cache_read_en = w_ready;
                cache_addr    = cache_miss_addr + cnt + 1; 
            end
            
            read_fetch : begin
                if(!hit) begin
                    // miss = 1'b1;
                    if(valid && dirty) begin
                        aw_valid = 1'b1;
                        aw_addr  = cache_miss_addr;
                        aw_len   = B - 1;
                        
                        c_valid       = 1'b1;
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
            read_hit : begin
                cache_ready = 1'b1;
                cache_valid = 1'b1;
            end
        endcase
    end

endmodule