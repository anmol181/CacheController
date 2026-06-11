`timescale 1ns / 1ps

module cache_ctrl #(
    parameter AW = 16,
    parameter DW = 8,
    parameter B = 4, // block size = B*DW
    parameter W = 4, // no. of ways
    parameter S = 8,  // no. of blocks
    parameter WW = $clog2(W),
    parameter SW = $clog2(S),
    parameter BW = $clog2(B)
)(
    input                   clk,
    input                   rst,
    
    // cpu signals
    input [AW - 1 : 0]      cpu_addr,
    input                   cpu_read_en,
    input                   cpu_write_en,
    input [DW - 1 : 0]      cpu_data_in,

    // cache signals
    output reg              mem_read_en,
    output reg              mem_write_en,
    output reg              cache_read_en,
    output reg              cache_write_en,
    input  [DW - 1 : 0]     cache_read_data,
    output reg [DW - 1 : 0] cache_write_data,
    output reg [AW - 1 : 0] cache_address,
    input [AW - 1 : 0  ]    cache_miss_addr,
    input                   hit,
    input                   valid,
    input                   dirty,

    // axi signals for memory
    output reg [AW - 1 : 0]  ar_addr, 
    output reg [7 : 0]       ar_len,
    input                    ar_ready,
    output reg               ar_valid,

    input      [DW - 1 : 0]  r_data, 
    input                    r_last,
    output reg               r_ready,
    input                    r_valid,

    output reg [AW - 1 : 0]  aw_addr, 
    output reg [7 : 0]       aw_len,
    input                    aw_ready,
    output reg               aw_valid,

    output reg [DW - 1 : 0]  w_data, 
    output reg               w_last,
    input                    w_ready,
    output reg               w_valid,

    output reg miss
);

    localparam st = 0;
    localparam cpu_check = 1;
    localparam mem_write_st = 2;
    localparam mem_write_data = 3;
    localparam mem_read_st = 4;
    localparam cache_write_st = 6;
    localparam cache_read_st = 7;
    localparam mem_read_addr_wait = 8;

    reg [3:0] ps;
    reg [7:0] cnt;
    reg [AW-1:0] burst_addr;

    always @(posedge clk) begin
        if(rst) begin
            ps <= st;
            burst_addr <= 0;
            cnt <= 0;
        end
        else begin
            case (ps)
                st: begin
                    if(cpu_write_en || cpu_read_en) begin
                        ps <= cpu_check;
                    end
                end
                
                cpu_check : begin
                    if(hit) begin
                        ps <= st;
                    end
                    else begin
                        cnt <= 0;
                        if (!valid || !dirty) begin
                            burst_addr <= {cpu_addr[AW-1 : BW], {BW{1'b0}}};
                            ps <= ar_ready ? mem_read_st : cpu_check;
                        end
                        else begin
                            burst_addr <= cache_miss_addr;
                            ps <= aw_ready ? mem_write_data : mem_write_st;
                        end
                    end    
                end
                
                mem_write_st : begin
                    if(aw_ready) ps <= mem_write_data;
                end
                
                mem_write_data : begin
                    if(w_ready) begin
                        if(cnt == B - 1) begin
                            burst_addr <= {cpu_addr[AW-1 : BW], {BW{1'b0}}};
                            ps <= mem_read_addr_wait;
                        end else begin
                            cnt <= cnt + 1'b1;
                            burst_addr <= burst_addr + 1'b1;
                        end
                    end
                end

                mem_read_addr_wait : begin
                    if(ar_ready) ps <= mem_read_st;
                end
                
                mem_read_st : begin
                    if(r_valid) begin
                        burst_addr <= burst_addr + 1'b1;
                        if(r_last) begin
                            ps <= cpu_read_en ? cache_read_st : cache_write_st;
                        end
                    end
                end
                
                cache_write_st: begin
                    ps <= st;
                end
                cache_read_st: begin
                    ps <= st;
                end
                default: begin
                    ps <= st;
                end
            endcase 
        end
    end

    always @(*) begin
        // Default clearances
        ar_valid       = 1'b0;
        aw_valid       = 1'b0;
        w_valid        = 1'b0;
        cache_write_en = 1'b0;
        cache_read_en  = 1'b0;
        mem_write_en   = 1'b0;
        miss           = 1'b1;
        w_last         = 1'b0;
        r_ready        = 1'b1; 

        // Static parameters
        ar_addr = {cpu_addr[AW-1 : BW], {BW{1'b0}}};
        ar_len  = B - 1;
        aw_addr = cache_miss_addr;
        aw_len  = B - 1;
        
        // Datapath routing defaults
        cache_address    = cpu_addr;
        cache_write_data = cpu_data_in;
        w_data           = cache_read_data;

        case(ps) 
            st : begin
                miss = 1'b0;
                if(cpu_write_en) cache_write_en = 1'b1;
                else if(cpu_read_en) cache_read_en = 1'b1;
            end
            
            cpu_check : begin
                if(hit) begin
                    miss = 1'b0;
                end else begin
                    if(!valid || !dirty) ar_valid = 1'b1;
                    else aw_valid = 1'b1;
                end
            end
            
            mem_write_st : begin
                aw_valid = 1'b1;
            end
            
            mem_write_data : begin
                w_valid = 1'b1;
                cache_address = burst_addr;
                if(cnt == B - 1) w_last = 1'b1;
            end

            mem_read_addr_wait : begin
                ar_valid = 1'b1;
            end
            
            mem_read_st : begin
                cache_address = burst_addr;
                if(r_valid) begin
                    mem_write_en = 1'b1;
                    cache_write_data = r_data;
                end
            end
            
            cache_write_st : begin
                miss = 1'b0;
                cache_write_en = 1'b1;
            end
            
            cache_read_st : begin
                miss = 1'b0;
                cache_read_en = 1'b1;
            end
        endcase     
    end

endmodule