`timescale 1ns / 1ps

module memory#(
    parameter AW = 16,
    parameter DW = 8
)(
    input                   clk,
    input                   rst,

    input [AW - 1 : 0]      ar_addr, // read address
    input [7 : 0]           ar_len,
    output reg              ar_ready,
    input                   ar_valid,

    output reg [DW - 1 : 0] r_data, // read data
    output reg              r_last,
    input                   r_ready,
    output  reg             r_valid,

    input [AW - 1 : 0]      aw_addr, // write address
    input [7 : 0]           aw_len,
    output reg              aw_ready,
    input                   aw_valid,

    input [DW - 1 : 0]      w_data, // write address
    input                   w_last,
    output reg              w_ready,
    input                   w_valid,

    output reg [1 : 0]      bcode, // write response channel
    output reg              bvalid,
    input                   bready
    );

    localparam mem_size = 1 << AW;
    reg [DW - 1 : 0] mem [mem_size - 1 : 0];

    reg [AW - 1 : 0] read_addr;
    reg [7 : 0] read_len;
    reg [7 : 0] read_cnt;

    reg [1 : 0] r_ps;

    localparam rd_rec = 0;
    localparam rd_ftc = 1;
    localparam rd_snd = 2;

    // Read FSM
    always @(posedge clk) begin
        if(rst) begin
            read_addr <= {AW{1'b0}};
            r_data    <= {DW{1'b0}};
            ar_ready  <= 1'b1;
            r_valid   <= 1'b0;
            r_last    <= 1'b0;
            r_ps      <= rd_rec;
            read_len  <= 8'b0;
            read_cnt  <= 8'b0;
        end
        else begin
            case(r_ps)
            rd_rec : begin
                if(ar_valid && ar_ready) begin
                    read_addr <= ar_addr;
                    read_len  <= ar_len;
                    read_cnt  <= 8'b0;
                    ar_ready  <= 1'b0;
                    r_ps      <= rd_ftc;
                end
            end

            rd_ftc : begin
                r_data  <= mem[read_addr];
                r_valid <= 1'b1;
                r_last  <= (read_cnt == read_len) ? 1'b1 : 1'b0;
                r_ps    <= rd_snd;
            end

            rd_snd : begin
                if(r_ready && r_valid) begin
                    if (r_last) begin
                        r_valid  <= 1'b0;
                        r_last   <= 1'b0;
                        ar_ready <= 1'b1;
                        r_ps     <= rd_rec; 
                    end else begin
                        read_addr <= read_addr + 1;
                        read_cnt  <= read_cnt + 1;
                        r_valid   <= 1'b0; 
                        r_ps      <= rd_ftc; 
                    end
                end
            end

            default : begin
                ar_ready <= 1'b1;
                r_valid  <= 1'b0;
                r_ps     <= rd_rec;
            end
            endcase
        end
    end

/////////////////////////// WRITE /////////////////////////////

    reg [AW - 1 : 0] write_addr;
    reg [2 : 0]      w_ps;

    localparam wt_st    = 0;
    localparam wt_data  = 1;
    localparam wt_resp  = 2;

    // write fsm
    always @(posedge clk) begin
        if(rst) begin
            write_addr <= {AW{1'b0}};
            aw_ready   <= 1'b1;
            w_ready    <= 1'b0;
            bvalid     <= 1'b0;
            bcode      <= 2'b0;
            w_ps       <= wt_st;
        end
        else begin
            case(w_ps)
            wt_st : begin
                if(aw_valid) begin
                    write_addr <= aw_addr;
                    aw_ready   <= 1'b0;
                    w_ready    <= 1'b1;
                    w_ps       <= wt_data;
                end
                else begin
                    aw_ready  <= 1'b1;
                    w_ready   <= 1'b0;
                    w_ps      <= wt_st;
                end
            end

            wt_data : begin
                if(w_valid) begin
                    mem[write_addr] <= w_data;
                    
                    if(w_last) begin
                        w_ready         <= 1'b0;
                        w_ps            <= wt_resp;
                        bvalid          <= 1'b1;
                        bcode           <= 2'b0;
                    end else begin
                        write_addr      <= write_addr + 1;
                    end
                end
                else begin
                    w_ps <= wt_data;
                end
            end

            wt_resp : begin
                if(bready) begin
                    bvalid   <= 1'b0;
                    aw_ready <= 1'b1;
                    w_ps     <= wt_st;
                end
            end

            default : begin
                aw_ready <= 1'b0;
                w_ready  <= 1'b0;
                w_ps     <= wt_st;
            end
            endcase
        end
    end

endmodule