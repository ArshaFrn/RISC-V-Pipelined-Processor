`timescale 1ns / 1ps
module Pipe_ID_EX (
    input wire clk,
    input wire reset,
    input wire flush,
    // Control Signals In
    input wire [3:0] alu_op_in,
    input wire [2:0] mask_in,
    input wire [2:0] br_type_in,
    input wire [1:0] wb_sel_in,
    input wire reg_wr_in,
    input wire mem_read_in,
    input wire mem_write_in,
    input wire sel_a_in,
    input wire sel_b_in,
    // Data Signals In
    input wire [31:0] pc_in,
    input wire [31:0] pc4_in,
    input wire [31:0] rdata1_in,
    input wire [31:0] rdata2_in,
    input wire [31:0] imm_in,
    input wire [4:0] rs1_in,
    input wire [4:0] rs2_in,
    input wire [4:0] rd_in,
    input wire [6:0] opcode_in,

    // Outputs
    output reg [3:0] alu_op_out,
    output reg [2:0] mask_out,
    output reg [2:0] br_type_out,
    output reg [1:0] wb_sel_out,
    output reg reg_wr_out,
    output reg mem_read_out,
    output reg mem_write_out,
    output reg sel_a_out,
    output reg sel_b_out,
    output reg [31:0] pc_out,
    output reg [31:0] pc4_out,
    output reg [31:0] rdata1_out,
    output reg [31:0] rdata2_out,
    output reg [31:0] imm_out,
    output reg [4:0] rs1_out,
    output reg [4:0] rs2_out,
    output reg [4:0] rd_out,
    output reg [6:0] opcode_out
);
    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            // Clear Control Signals
            alu_op_out <= 0; mask_out <= 0; br_type_out <= 0;
            wb_sel_out <= 0; reg_wr_out <= 0; mem_read_out <= 0;
            mem_write_out <= 0; sel_a_out <= 0; sel_b_out <= 0;
            // Clear Data
            pc_out <= 0; pc4_out <= 0;
            rdata1_out <= 0; rdata2_out <= 0; imm_out <= 0;
            rs1_out <= 0; rs2_out <= 0; rd_out <= 0; opcode_out <= 0;
        end else begin
            alu_op_out <= alu_op_in; mask_out <= mask_in; br_type_out <= br_type_in;
            wb_sel_out <= wb_sel_in; reg_wr_out <= reg_wr_in; mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in; sel_a_out <= sel_a_in; sel_b_out <= sel_b_in;
            pc_out <= pc_in; pc4_out <= pc4_in;
            rdata1_out <= rdata1_in; rdata2_out <= rdata2_in; imm_out <= imm_in;
            rs1_out <= rs1_in; rs2_out <= rs2_in; rd_out <= rd_in; opcode_out <= opcode_in;
        end
    end
endmodule
