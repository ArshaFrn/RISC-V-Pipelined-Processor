`timescale 1ns / 1ps

module CacheSystem (
    input wire clk,
    input wire reset,

    // Processor Interface
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire mem_read,
    input wire mem_write,
    input wire [2:0] mask,
    output reg [31:0] rdata,
    output reg hit
);

    // =========================================================
    // Cache Configuration
    // =========================================================
    reg [31:0] cache_data  [0:63];
    reg [23:0] cache_tag   [0:63];
    reg        cache_valid [0:63];

    wire [5:0]  index = addr[7:2];    
    wire [23:0] tag   = addr[31:8];   

    // =========================================================
    // Main Memory Interface
    // =========================================================
    wire [31:0] mem_rdata;

    MainMemory main_mem (
        .clk(clk),
        .addr(addr),
        .wdata(wdata),
        .mem_write(mem_write), 
        .mem_read(mem_read),   
        .rdata(mem_rdata)
    );

    // =========================================================
    // HIT / MISS LOGIC
    // =========================================================
    wire valid_bit = cache_valid[index];
    wire [23:0] stored_tag = cache_tag[index];
    wire tag_match = (stored_tag == tag);

    always @(*) begin
        if (!mem_write && mem_read && valid_bit && tag_match)
            hit = 1'b1;
        else
            hit = 1'b0; 
    end

    // =========================================================
    // Read Logic
    // =========================================================
    reg [31:0] raw_data;

    always @(*) begin
        if (mem_read) begin
            if (hit) begin
                raw_data = cache_data[index]; 
            end else begin
                raw_data = mem_rdata;         
            end

            case (mask)
                3'b000: begin // lb
                    case (addr[1:0])
                        2'b00: rdata = {{24{raw_data[7]}},   raw_data[7:0]};
                        2'b01: rdata = {{24{raw_data[15]}},  raw_data[15:8]};
                        2'b10: rdata = {{24{raw_data[23]}},  raw_data[23:16]};
                        2'b11: rdata = {{24{raw_data[31]}},  raw_data[31:24]};
                    endcase
                end
                3'b001: begin // lh
                    case (addr[1])
                        1'b0: rdata = {{16{raw_data[15]}},  raw_data[15:0]};
                        1'b1: rdata = {{16{raw_data[31]}},  raw_data[31:16]};
                    endcase
                end
                3'b010: rdata = raw_data; // lw
                3'b100: begin // lbu
                    case (addr[1:0])
                        2'b00: rdata = {24'b0, raw_data[7:0]};
                        2'b01: rdata = {24'b0, raw_data[15:8]};
                        2'b10: rdata = {24'b0, raw_data[23:16]};
                        2'b11: rdata = {24'b0, raw_data[31:24]};
                    endcase
                end
                default: rdata = 32'b0;
            endcase
        end else begin
            rdata = 32'b0;
        end
    end

    // =========================================================
    // Write & Update Logic
    // =========================================================
    integer i;
    always @(negedge clk or posedge reset) begin
        if (reset) begin
            for (i=0; i<64; i=i+1) cache_valid[i] <= 1'b0;
        end
        else begin
            if (mem_read && !hit) begin
                cache_valid[index] <= 1'b1;
                cache_tag[index]   <= tag;
                cache_data[index]  <= mem_rdata; 
            end

            if (mem_write) begin
                cache_valid[index] <= 1'b1;
                cache_tag[index]   <= tag;

                if (mask == 3'b010) begin // SW
                     cache_data[index] <= wdata;
                end
                else begin
                     cache_valid[index] <= 1'b0; 
                end
            end
        end
    end

endmodule
