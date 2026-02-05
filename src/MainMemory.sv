module MainMemory(
    input clk,
    input [31:0] addr,
    input [31:0] wdata,
    input MemWrite,
    input MemRead,
    output reg [31:0] rdata
);
    // 1024 words (4KB)
    reg [31:0] mem [0:1023];

    // Initialize memory with data if needed
    integer i;
    initial begin
        for(i=0; i<1024; i=i+1) mem[i] = 32'b0;
    end

    always @(posedge clk) begin
        if (MemWrite) begin
            mem[addr[11:2]] <= wdata;
        end
    end

    // Asynchronous read for simplicity in this design
    always @(*) begin
        if (MemRead) 
            rdata = mem[addr[11:2]];
        else
            rdata = 32'b0;
    end
endmodule
