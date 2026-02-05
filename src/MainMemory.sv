`timescale 1ns / 1ps

module MainMemory (
    input wire clk,
    input wire [31:0] addr,    // آدرس کامل
    input wire [31:0] wdata,   // داده برای نوشتن
    input wire mem_write,      // سیگنال نوشتن
    input wire mem_read,       // سیگنال خواندن
    output reg [31:0] rdata    // داده خوانده شده
);

    // حافظه اصلی: 4KB (1024 کلمه 32 بیتی)
    reg [31:0] RAM [0:1023];

    // آدرس را بر 4 تقسیم می‌کنیم تا به ایندکس آرایه برسیم
    wire [31:0] word_addr = {2'b0, addr[31:2]};

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            RAM[i] = 32'b0;
    end

    // خواندن (غیر همزمان یا همزمان - برای سادگی اینجا ترکیبی است)
    always @(*) begin
        if (mem_read)
            rdata = RAM[word_addr];
        else
            rdata = 32'b0;
    end

    // نوشتن (همگام با کلاک)
    always @(negedge clk) begin
        if (mem_write) begin
            RAM[word_addr] <= wdata;
        end
    end

endmodule
