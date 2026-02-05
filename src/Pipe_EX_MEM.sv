`timescale 1ns / 1ps
module Pipe_EX_MEM (
    input wire clk,
    input wire reset,
    // Control In
    input wire [1:0] wb_sel_in,
    input wire reg_wr_in,
    input wire mem_read_in,
    input wire mem_write_in,
    input wire [2:0] mask_in,
    // Data In
    input wire [31:0] alu_result_in,
    input wire [31:0] write_data_in,
    input wire [4:0] rd_in,
    input wire [31:0] pc4_in,

    // Outputs
    output reg [1:0] wb_sel_out,
    output reg reg_wr_out,
    output reg mem_read_out,
    output reg mem_write_out,
    output reg [2:0] mask_out,
    output reg [31:0] alu_result_out,
    output reg [31:0] write_data_out,
    output reg [4:0] rd_out,
    output reg [31:0] pc4_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wb_sel_out <= 0; reg_wr_out <= 0; 
            mem_read_out <= 0; mem_write_out <= 0; mask_out <= 0;
            alu_result_out <= 0; write_data_out <= 0; rd_out <= 0; pc4_out <= 0;
        end else begin
            wb_sel_out <= wb_sel_in; reg_wr_out <= reg_wr_in;
            mem_read_out <= mem_read_in; mem_write_out <= mem_write_in; mask_out <= mask_in;
            alu_result_out <= alu_result_in; write_data_out <= write_data_in;
            rd_out <= rd_in; pc4_out <= pc4_in;
        end
    end
endmodule
