`timescale 1ns / 1ps

module datapath #(
    parameter AW = 16,
    parameter DW = 8,
    parameter B  = 4,
    parameter W  = 4,
    parameter S  = 8,
    parameter WW = $clog2(W),
    parameter SW = $clog2(S),
    parameter BW = $clog2(B)
)(
    // --- Inputs ---
    input  wire          clk,
    input  wire          rst,

    input  wire          c_valid,
    input  wire [AW-1:0] addr,

    input  wire [DW-1:0] data_in,
    input  wire          cache_read_en,
    input  wire          cache_write_en,
    input  wire          mem_write_en,
    input  wire          mem_read_en,

    // --- Outputs ---
    output reg           hit,
    output wire          dirty,
    output wire          valid,
    output reg  [DW-1:0] data_out,
    output wire [AW-1:0] cache_miss_addr
);

    localparam BS = B * DW;
    localparam v  = AW - BW - SW + BS + 1;
    localparam d  = v - 1;

    reg          s1_c_valid;
    reg [AW-1:0] s1_addr;
    reg          s1_cache_read_en;
    reg          s1_cache_write_en;
    reg          s1_mem_write_en;
    reg          s1_mem_read_en;
    reg [DW-1:0] s1_data_in;

    reg [AW-BW-SW+BS+1:0] bram_data_out [0:W-1];

    wire [AW-BW-SW-1:0] s1_tag;
    assign s1_tag = s1_addr[AW-1:BW+SW];

    wire [SW-1:0] index, s1_index;
    assign index    = addr[BW +: SW];
    assign s1_index = s1_addr[BW +: SW];

    reg [W-1:0] bram_we_temp;


    wire s1_re = s1_cache_read_en;

    reg [WW-1:0] hit_way;

    always @(posedge clk) begin
        if(rst) begin
            s1_c_valid <= 1'b0;
            s1_addr           <= {AW{1'b0}};
            s1_cache_read_en  <= 1'b0;
            s1_cache_write_en <= 1'b0;
            s1_mem_write_en   <= 1'b0;
            s1_mem_read_en    <= 1'b0;
            s1_data_in        <= {DW{1'b0}};
        end
        else begin
            s1_c_valid    <= c_valid;
            if(c_valid) begin
                s1_addr           <= addr;
                s1_cache_read_en  <= cache_read_en;
                s1_cache_write_en <= cache_write_en;
                s1_mem_write_en   <= mem_write_en;
                s1_mem_read_en    <= mem_read_en;
                s1_data_in        <= data_in;
            end
        end
    end

    // bram
    genvar i, j;
    generate
        for (i = 0; i < W; i = i + 1) begin : memory_ways

            reg [AW-BW-SW-1:0] tag_ram   [0:S-1];
            reg                valid_ram [0:S-1];
            reg                dirty_ram [0:S-1];

            for(j = 0; j < B; j = j + 1) begin : data_arrays
                reg [DW-1:0] cache [0:S-1];
            end

            wire [DW*B-1:0] data_block;
            for(j = 0; j < B; j = j + 1) begin : read_data_assign
                assign data_block[j*DW +: DW] = data_arrays[j].cache[index];
            end

            // Synchronous Read and Write
            always @(posedge clk) begin
                if(bram_we_temp[i]) begin
                    tag_ram[s1_index]   <= s1_addr[AW-1:BW+SW];
                    valid_ram[s1_index] <= 1'b1;
                    dirty_ram[s1_index] <= s1_cache_write_en;
                end
                if(c_valid) begin
                    bram_data_out[i] <= {valid_ram[index], dirty_ram[index], tag_ram[index], data_block};
                end
            end

            for (j = 0; j < B; j = j + 1) begin : data_writes
                always @(posedge clk) begin
                    if (bram_we_temp[i] && (s1_addr[0 +: BW] == j)) begin
                        data_arrays[j].cache[s1_index] <= s1_data_in;
                    end
                end
            end
            
        end
    endgenerate

    reg [WW-1:0] lru_way;

    integer i_hit;
    integer i_rst;
    integer i_upd;
    integer i_dcd;

    always @(*) begin
        bram_we_temp = {W{1'b0}};
        hit          = 1'b0;
        hit_way      = {WW{1'b0}};
        
        for(i_hit = 0; i_hit < W; i_hit = i_hit + 1) begin
            if(s1_c_valid && !s1_mem_write_en && !s1_mem_read_en && s1_tag == bram_data_out[i_hit][BS +: AW-BW-SW] && bram_data_out[i_hit][v]) begin
                hit     = 1'b1;
                hit_way = i_hit;
                if(s1_cache_write_en) begin
                    bram_we_temp[i_hit] = 1'b1;
                end
            end
        end
        if(s1_c_valid && s1_mem_write_en) begin
            bram_we_temp[lru_way] = 1'b1;
        end
    end


    assign valid = bram_data_out[lru_way][v];
    assign dirty = bram_data_out[lru_way][d];
    assign cache_miss_addr = {bram_data_out[lru_way][BS +: AW-BW-SW], s1_index, {BW{1'b0}}};

    always @(*) begin
        if(hit) data_out = bram_data_out[hit_way][s1_addr[0+:BW]*DW +: DW];
        else    data_out = bram_data_out[lru_way][s1_addr[0+:BW]*DW +: DW];
    end

    // pseudo lru implementation

    reg [W-2:0] plru [0:S-1];
    integer cnt;

    always @(posedge clk) begin
        if(rst) begin
            for(i_rst = 0;i_rst < S;i_rst = i_rst + 1) begin
                plru[i_rst] <= {W-1{1'b0}};
            end
        end
        else if (hit) begin
            cnt = 0;
            for (i_upd = WW-1; i_upd >= 0; i_upd = i_upd - 1) begin
                plru[s1_index][cnt] <= !hit_way[i_upd];
                cnt = 2*cnt + 1'b1 + hit_way[i_upd];
            end
        end
    end

    integer way_cnt;
    always @(*) begin
        way_cnt = 0;
        for (i_dcd = WW-1; i_dcd >= 0; i_dcd = i_dcd - 1) begin
            lru_way[i_dcd] = plru[s1_index][way_cnt];
            way_cnt = 2*way_cnt + 1'b1 + plru[s1_index][way_cnt];
        end
    end

endmodule