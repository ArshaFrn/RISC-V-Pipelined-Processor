`timescale 1ns / 1ps
module Pipe_IF_ID (
    input wire clk,
    input wire reset,
    input wire en,          // Enable (for Stalling)
    input wire flush,       // Flush (for Branching)
    input wire [31:0] pc_in,
    input wire [31:0] pc4_in,
    input wire [31:0] instr_in,
    output reg [31:0] pc_out,
    output reg [31:0] pc4_out,
    output reg [31:0] instr_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out <= 0;
            pc4_out <= 0;
            instr_out <= 0;
        end else if (flush) begin
            pc_out <= 0;
            pc4_out <= 0;
            instr_out <= 32'h00000013; // NOP (ADDI x0, x0, 0)
        end else if (en) begin
            pc_out <= pc_in;
            pc4_out <= pc4_in;
            instr_out <= instr_in;
        end
        // If en == 0 (Stall), hold value
    end
endmodule
