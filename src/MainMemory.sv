`timescale 1ns / 1ps

module MainMemory (
    input wire clk,
    input wire [31:0] addr,   
    input wire [31:0] wdata, 
    input wire mem_write,  
    input wire mem_read, 
    output reg [31:0] rdata
);

    reg [31:0] RAM [0:1023];

    wire [31:0] word_addr = {2'b0, addr[31:2]};

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            RAM[i] = 32'b0;
    end

    always @(*) begin
        if (mem_read)
            rdata = RAM[word_addr];
        else
            rdata = 32'b0;
    end

    always @(negedge clk) begin
        if (mem_write) begin
            RAM[word_addr] <= wdata;
        end
    end

endmodule
