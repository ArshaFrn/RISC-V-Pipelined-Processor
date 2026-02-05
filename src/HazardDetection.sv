`timescale 1ns / 1ps
module HazardDetection (
    input wire [4:0] ID_Rs1,
    input wire [4:0] ID_Rs2,
    input wire [4:0] ID_EX_Rd,
    input wire ID_EX_MemRead,
    
    output reg PC_Write,
    output reg IF_ID_Write,
    output reg Stall
);
    always @(*) begin
        // Load-Use Hazard Detection
        // If instruction in EX stage is a Load (MemRead=1) AND
        // destination register (Rd) matches Source Rs1 or Rs2 of ID stage...
        if (ID_EX_MemRead && (ID_EX_Rd != 0) && 
           ((ID_EX_Rd == ID_Rs1) || (ID_EX_Rd == ID_Rs2))) begin
            
            // Stall Condition
            Stall = 1'b1;       // Insert Bubble in ID/EX
            PC_Write = 1'b0;    // Prevent PC update
            IF_ID_Write = 1'b0; // Prevent IF/ID update
        end else begin
            // Normal Operation
            Stall = 1'b0;
            PC_Write = 1'b1;
            IF_ID_Write = 1'b1;
        end
    end
endmodule
