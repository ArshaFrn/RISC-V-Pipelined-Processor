`timescale 1ns / 1ps

module PipelinedProcessor_TB;

    // Inputs to Processor
    reg clk;
    reg reset;

    // Instantiate the Pipelined Processor (UUT)
    PipelinedProcessor UUT (
        .clk(clk),
        .reset(reset)
    );

    // Clock Generation (10ns period -> 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test Sequence
    initial begin
        // 1. Initialize
        reset = 1;
        
        // 2. Hold Reset for a few cycles
        #10;
        
        // 3. Release Reset
        reset = 0;

        // 4. Run Simulation
        // 500ns is enough for the 19 instructions in your code.mem
        #500; 
        
        $display("Simulation Finished.");
        $stop;
    end

    // Function to decode RISC-V instruction to name
    function automatic string decode_instruction(input [31:0] instr);
        logic [6:0] opcode;
        logic [2:0] funct3;
        logic [6:0] funct7;
        logic [4:0] rs1, rs2, rd;
        
        opcode = instr[6:0];
        funct3 = instr[14:12];
        funct7 = instr[31:25];
        rs1 = instr[19:15];
        rs2 = instr[24:20];
        rd = instr[11:7];
        
        case (opcode)
            7'b0010011: begin  // I-type (addi, ori, etc.)
                case (funct3)
                    3'b000: return $sformatf("addi x%0d, x%0d, %0d", rd, rs1, $signed(instr[31:20]));
                    3'b010: return $sformatf("slti x%0d, x%0d, %0d", rd, rs1, $signed(instr[31:20]));
                    3'b011: return $sformatf("sltiu x%0d, x%0d, %0d", rd, rs1, instr[31:20]);
                    3'b100: return $sformatf("xori x%0d, x%0d, %0d", rd, rs1, $signed(instr[31:20]));
                    3'b110: return $sformatf("ori x%0d, x%0d, %0d", rd, rs1, $signed(instr[31:20]));
                    3'b111: return $sformatf("andi x%0d, x%0d, %0d", rd, rs1, $signed(instr[31:20]));
                    3'b001: return $sformatf("slli x%0d, x%0d, %0d", rd, rs1, instr[24:20]);
                    3'b101: return (funct7[5]) ? $sformatf("srai x%0d, x%0d, %0d", rd, rs1, instr[24:20]) 
                                               : $sformatf("srli x%0d, x%0d, %0d", rd, rs1, instr[24:20]);
                    default: return "unknown";
                endcase
            end
            
            7'b0110011: begin  // R-type (add, sub, etc.)
                case ({funct7[5], funct3})
                    4'b0000: return $sformatf("add x%0d, x%0d, x%0d", rd, rs1, rs2);
                    4'b1000: return $sformatf("sub x%0d, x%0d, x%0d", rd, rs1, rs2);
                    4'b0001: return $sformatf("mul x%0d, x%0d, x%0d", rd, rs1, rs2);
                    4'b0010: return $sformatf("sll x%0d, x%0d, x%0d", rd, rs1, rs2);
                    4'b0011: return $sformatf("mulh x%0d, x%0d, x%0d", rd, rs1, rs2);
                    4'b0100: return $sformatf("xor x%0d, x%0d, x%0d", rd, rs1, rs2);
                    4'b0101: return $sformatf("srl x%0d, x%0d, x%0d", rd, rs1, rs2);
                    4'b1101: return $sformatf("sra x%0d, x%0d, x%0d", rd, rs1, rs2);
                    4'b0110: return $sformatf("or x%0d, x%0d, x%0d", rd, rs1, rs2);
                    4'b0111: return $sformatf("and x%0d, x%0d, x%0d", rd, rs1, rs2);
                    default: return "unknown";
                endcase
            end
            
            7'b0000011: begin  // Load (lw, lh, lb)
                case (funct3)
                    3'b000: return $sformatf("lb x%0d, %0d(x%0d)", rd, $signed(instr[31:20]), rs1);
                    3'b001: return $sformatf("lh x%0d, %0d(x%0d)", rd, $signed(instr[31:20]), rs1);
                    3'b010: return $sformatf("lw x%0d, %0d(x%0d)", rd, $signed(instr[31:20]), rs1);
                    3'b100: return $sformatf("lbu x%0d, %0d(x%0d)", rd, $signed(instr[31:20]), rs1);
                    3'b101: return $sformatf("lhu x%0d, %0d(x%0d)", rd, $signed(instr[31:20]), rs1);
                    default: return "unknown";
                endcase
            end
            
            7'b0100011: begin  // Store (sw, sh, sb)
                case (funct3)
                    3'b000: return $sformatf("sb x%0d, %0d(x%0d)", rs2, {{20{instr[31]}}, instr[31:25], instr[11:7]}, rs1);
                    3'b001: return $sformatf("sh x%0d, %0d(x%0d)", rs2, {{20{instr[31]}}, instr[31:25], instr[11:7]}, rs1);
                    3'b010: return $sformatf("sw x%0d, %0d(x%0d)", rs2, {{20{instr[31]}}, instr[31:25], instr[11:7]}, rs1);
                    default: return "unknown";
                endcase
            end
            
            7'b1100011: begin  // Branch (beq, bne, etc.)
                case (funct3)
                    3'b000: return $sformatf("beq x%0d, x%0d, %0d", rs1, rs2, $signed({instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}));
                    3'b001: return $sformatf("bne x%0d, x%0d, %0d", rs1, rs2, $signed({instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}));
                    3'b100: return $sformatf("blt x%0d, x%0d, %0d", rs1, rs2, $signed({instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}));
                    3'b101: return $sformatf("bge x%0d, x%0d, %0d", rs1, rs2, $signed({instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}));
                    3'b110: return $sformatf("bltu x%0d, x%0d, %0d", rs1, rs2, $signed({instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}));
                    3'b111: return $sformatf("bgeu x%0d, x%0d, %0d", rs1, rs2, $signed({instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}));
                    default: return "unknown";
                endcase
            end
            
            7'b1101111: return $sformatf("jal x%0d, %0d", rd, $signed({instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}));
            7'b1100111: return $sformatf("jalr x%0d, x%0d, %0d", rd, rs1, $signed(instr[31:20]));
            
            default: return $sformatf("unknown (0x%h)", instr);
        endcase
    endfunction

    // Monitor / Debugging
    // This block prints the status of the pipeline every time a signal changes
    initial begin
        $display("----------------------------------------------------------------------------------------------------------------");
        $display("Time  | PC (IF)   | Instruction         | Stall | ForwardA | ForwardB | CacheHit | WB Reg | WB Data");
        $display("----------------------------------------------------------------------------------------------------------------");
        
        // Internal signals can be accessed using "UUT.SignalName"
        $monitor("%5t | %h | %-20s | %b | %02b | %02b | %b | x%0d | %h",
            $time,
            UUT.IF_PC,        // Current PC
            decode_instruction(UUT.ID_Instr),  // Decoded instruction name
            UUT.Stall,        // Hazard Stall Signal
            UUT.ForwardA,     // Forwarding Status A
            UUT.ForwardB,     // Forwarding Status B
            UUT.CacheHit,     // Cache Hit Status
            UUT.WB_Rd,        // Register being written back
            UUT.WB_Result     // Value being written back
        );
    end

endmodule
