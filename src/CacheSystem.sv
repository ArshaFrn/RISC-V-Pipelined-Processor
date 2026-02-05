`timescale 1ns / 1ps
module CacheSystem (
    input wire clk,
    input wire reset,
    
    // Address and Data from Processor
    input wire [31:0] addr,
    input wire [31:0] wdata,
    
    // Control Signals from Processor
    input wire mem_read,
    input wire mem_write,
    input wire [2:0] mask,
    
    // Outputs to Processor
    output reg [31:0] rdata,
    output reg hit
);

    // =========================================================================
    // INTERNAL MEMORY ARRAY (4KB)
    // This replaces the need for an external DataMemory file.
    // =========================================================================
    reg [31:0] memory [0:1023]; // 1024 words
    wire [31:0] word_addr = {2'b0, addr[31:2]}; // Align address to word boundary
    reg [31:0] data_internal;

    // Initialize memory to zero
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            memory[i] = 32'b0;
        end
    end

    // =========================================================================
    // HIT LOGIC
    // =========================================================================
    // For this stage of the project, we assume a "Perfect Cache" (100% Hit Rate)
    // so the pipeline never stalls on memory.
    always @(*) begin
        if (mem_read || mem_write)
            hit = 1'b1;
        else
            hit = 1'b0;
    end

    // =========================================================================
    // READ OPERATION
    // =========================================================================
    always @(*) begin
        if (mem_read) begin
            // Fetch the full word
            data_internal = memory[word_addr];
            
            // Handle Masking (Load Byte, Half, Word)
            case (mask)
                3'b000: begin // lb (Load Byte Signed)
                    case (addr[1:0])
                        2'b00: rdata = {{24{data_internal[7]}},   data_internal[7:0]};
                        2'b01: rdata = {{24{data_internal[15]}},  data_internal[15:8]};
                        2'b10: rdata = {{24{data_internal[23]}},  data_internal[23:16]};
                        2'b11: rdata = {{24{data_internal[31]}},  data_internal[31:24]};
                    endcase
                end
                3'b001: begin // lh (Load Halfword Signed)
                    case (addr[1])
                        1'b0: rdata = {{16{data_internal[15]}},  data_internal[15:0]};
                        1'b1: rdata = {{16{data_internal[31]}},  data_internal[31:16]};
                    endcase
                end
                3'b010: begin // lw (Load Word)
                    rdata = data_internal;
                end
                3'b100: begin // lbu (Load Byte Unsigned)
                    case (addr[1:0])
                        2'b00: rdata = {24'b0, data_internal[7:0]};
                        2'b01: rdata = {24'b0, data_internal[15:8]};
                        2'b10: rdata = {24'b0, data_internal[23:16]};
                        2'b11: rdata = {24'b0, data_internal[31:24]};
                    endcase
                end
                3'b101: begin // lhu (Load Halfword Unsigned)
                    case (addr[1])
                        1'b0: rdata = {16'b0, data_internal[15:0]};
                        1'b1: rdata = {16'b0, data_internal[31:16]};
                    endcase
                end
                default: rdata = 32'b0;
            endcase
        end else begin
            rdata = 32'b0;
        end
    end

    // =========================================================================
    // WRITE OPERATION
    // =========================================================================
    always @(negedge clk) begin
        if (mem_write) begin
            // We must read the current word first to preserve bits we aren't writing to
            logic [31:0] current_word;
            current_word = memory[word_addr];

            case (mask)
                3'b000: begin // sb (Store Byte)
                    case (addr[1:0])
                        2'b00: memory[word_addr] <= {current_word[31:8],  wdata[7:0]};
                        2'b01: memory[word_addr] <= {current_word[31:16], wdata[7:0], current_word[7:0]};
                        2'b10: memory[word_addr] <= {current_word[31:24], wdata[7:0], current_word[15:0]};
                        2'b11: memory[word_addr] <= {wdata[7:0], current_word[23:0]};
                    endcase
                end
                3'b001: begin // sh (Store Halfword)
                    case (addr[1])
                        1'b0: memory[word_addr] <= {current_word[31:16], wdata[15:0]};
                        1'b1: memory[word_addr] <= {wdata[15:0], current_word[15:0]};
                    endcase
                end
                3'b010: begin // sw (Store Word)
                    memory[word_addr] <= wdata;
                end
            endcase
        end
    end

endmodule
