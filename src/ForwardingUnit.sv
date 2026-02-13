`timescale 1ns / 1ps
module ForwardingUnit (
    input wire [4:0] EX_Rs1,
    input wire [4:0] EX_Rs2,
    input wire [4:0] MEM_Rd,
    input wire [4:0] WB_Rd,
    input wire MEM_RegWrite,
    input wire WB_RegWrite,
    
    output reg [1:0] ForwardA,
    output reg [1:0] ForwardB
);
    always @(*) begin
        // Forward A Logic
        // 1. EXHazard  , Forward from MEM stage
        if (MEM_RegWrite && (MEM_Rd != 0) && (MEM_Rd == EX_Rs1))
            ForwardA = 2'b10;
        // 2. MEM Hazard . Forward from WB stage
        else if (WB_RegWrite && (WB_Rd != 0) && (WB_Rd == EX_Rs1))
            ForwardA = 2'b01;
        // 3. No Hazard
        else
            ForwardA = 2'b00;

        // Forward B Logic
        // 1. EX Hazard , Forward from MEM stage
        if (MEM_RegWrite && (MEM_Rd != 0) && (MEM_Rd == EX_Rs2))
            ForwardB = 2'b10;
        // 2. MEM Hazard , Forward from WB stage
        else if (WB_RegWrite && (WB_Rd != 0) && (WB_Rd == EX_Rs2))
            ForwardB = 2'b01;
        // 3. No Hazard
        else
            ForwardB = 2'b00;
    end
endmodule
