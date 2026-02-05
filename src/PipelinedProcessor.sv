`timescale 1ns / 1ps

module PipelinedProcessor (
    input clk,
    input reset,
    // Debugging/Testbench Outputs
    output [31:0] IF_PC,
    output [31:0] ID_Instr,
    output Stall,
    output reg CacheHit,       // Changed to reg because it might be assigned in always
    output [4:0] WB_Rd,
    output reg [31:0] WB_Result // CHANGED FROM wire TO reg
);

    // =========================================================================
    // 1. IF STAGE (Instruction Fetch)
    // =========================================================================
    wire [31:0] IF_Next_PC;
    wire [31:0] IF_PC_Plus_4;
    wire [31:0] IF_Instr;
    wire PCSrc; // From EX stage (Branch taken)
    wire [31:0] EX_Branch_Target; // From EX stage

    // Mux for Next PC (Branch vs Normal)
    assign IF_Next_PC = (PCSrc) ? EX_Branch_Target : IF_PC_Plus_4;

    // PC Module
    wire PC_Write; // Enable signal from Hazard Unit
    // We reuse the PC module but need to handle the Stall (PC_Write)
    // If Stall is active (PC_Write=0), PC keeps old value.
    
    // Internal signal for the actual PC register output
    wire [31:0] PC_Out;
    assign IF_PC = PC_Out;

    // Custom PC logic for Stall support inside Top Level or use modified PC
    // Here we instantiate the provided PC.sv. 
    // NOTE: The provided PC.sv updates on every clock. To support Stall, 
    // we need to control the input.
    wire [31:0] PC_Input_Final;
    assign PC_Input_Final = (PC_Write) ? IF_Next_PC : PC_Out;

    PC pc_module (
        .clk(clk),
        .reset(reset),
        .A(PC_Out),       // Current PC
        .B(PC_Input_Final) // Next PC
    );

    // Adder for PC+4
    Add4 pc_adder (
        .A(PC_Out),
        .B(IF_PC_Plus_4)
    );

    // Instruction Memory
    InstructionMemory im_module (
        .addr(PC_Out),
        .instruction(IF_Instr)
    );


    // =========================================================================
    // IF/ID PIPELINE REGISTER
    // =========================================================================
    wire IF_ID_Write; // From Hazard Unit
    wire IF_Flush;    // From Branch Logic

    wire [31:0] ID_PC;
    wire [31:0] ID_PC_Plus_4;
    
    // Internal wire for Instruction at ID stage
    // If Flush is high, we inject a NOP (0x00000013 is ADDI x0, x0, 0)
    // Or simpler: The Pipe register clears to 0 on flush.
    
    Pipe_IF_ID pipe_if_id (
        .clk(clk),
        .reset(reset),
        .en(IF_ID_Write),
        .flush(IF_Flush),
        .pc_in(PC_Out),
        .pc4_in(IF_PC_Plus_4),
        .instr_in(IF_Instr),
        .pc_out(ID_PC),
        .pc4_out(ID_PC_Plus_4),
        .instr_out(ID_Instr)
    );


    // =========================================================================
    // 2. ID STAGE (Instruction Decode)
    // =========================================================================
    wire [31:0] ID_ReadData1;
    wire [31:0] ID_ReadData2;
    wire [31:0] ID_Imm;
    wire [3:0]  ID_ALU_Op;
    wire [2:0]  ID_Mask;
    wire [2:0]  ID_Br_Type;
    wire [1:0]  ID_WB_Sel;
    wire        ID_Reg_Wr;
    wire        ID_Rd_En; // MemRead
    wire        ID_Wr_En; // MemWrite
    wire        ID_Sel_A;
    wire        ID_Sel_B;
    
    // Control Unit
    Controller controller (
        .instruction(ID_Instr),
        .alu_op(ID_ALU_Op),
        .mask(ID_Mask),
        .br_type(ID_Br_Type),
        .reg_wr(ID_Reg_Wr),
        .sel_A(ID_Sel_A),
        .sel_B(ID_Sel_B),
        .rd_en(ID_Rd_En), // This is MemRead
        .wr_en(ID_Wr_En), // This is MemWrite
        .wb_sel(ID_WB_Sel)
    );

    // Register File
    // Note: WB_Result and WB_Rd come from the WB stage (feedback)
    wire WB_Reg_Wr; // From WB stage
    
    RegisterFile rf (
        .clk(clk),
        .reset(reset),
        .reg_wr(WB_Reg_Wr),
        .raddr1(ID_Instr[19:15]),
        .raddr2(ID_Instr[24:20]),
        .waddr(WB_Rd),      // Feedback from WB
        .wdata(WB_Result),  // Feedback from WB
        .rdata1(ID_ReadData1),
        .rdata2(ID_ReadData2)
    );

    // Immediate Generator
    ImmediateGenerator imm_gen (
        .clk(clk), // Provided module has clk, though strictly comb in many designs
        .instruction(ID_Instr),
        .imm_out(ID_Imm)
    );

    // Hazard Detection Unit
    // Detects Load-Use hazards
    wire ID_EX_MemRead; // Needed from next stage
    wire [4:0] ID_EX_Rd; // Needed from next stage
    
    HazardDetection hazard_unit (
        .ID_Rs1(ID_Instr[19:15]),
        .ID_Rs2(ID_Instr[24:20]),
        .ID_EX_Rd(ID_EX_Rd),
        .ID_EX_MemRead(ID_EX_MemRead),
        .PC_Write(PC_Write),
        .IF_ID_Write(IF_ID_Write),
        .Stall(Stall)
    );


    // =========================================================================
    // ID/EX PIPELINE REGISTER
    // =========================================================================
    wire ID_Flush_Hazard;
    assign ID_Flush_Hazard = Stall || IF_Flush; // Flush if stalling OR branch taken

    // Signals leaving ID/EX Pipe
    wire [31:0] EX_PC;
    wire [31:0] EX_PC_Plus_4;
    wire [31:0] EX_ReadData1;
    wire [31:0] EX_ReadData2;
    wire [31:0] EX_Imm;
    wire [4:0]  EX_Rs1;
    wire [4:0]  EX_Rs2;
    wire [4:0]  EX_Rd;
    wire [3:0]  EX_ALU_Op;
    wire [2:0]  EX_Mask;
    wire [2:0]  EX_Br_Type;
    wire [1:0]  EX_WB_Sel;
    wire        EX_Reg_Wr;
    wire        EX_Mem_Read;
    wire        EX_Mem_Write;
    wire        EX_Sel_A;
    wire        EX_Sel_B;
    wire [6:0]  EX_Opcode; // Needed for BranchCondition

    Pipe_ID_EX pipe_id_ex (
        .clk(clk),
        .reset(reset),
        .flush(ID_Flush_Hazard),
        // Control Signals
        .alu_op_in(ID_ALU_Op), .mask_in(ID_Mask), .br_type_in(ID_Br_Type), 
        .wb_sel_in(ID_WB_Sel), .reg_wr_in(ID_Reg_Wr), .mem_read_in(ID_Rd_En), 
        .mem_write_in(ID_Wr_En), .sel_a_in(ID_Sel_A), .sel_b_in(ID_Sel_B),
        // Data Path
        .pc_in(ID_PC), .pc4_in(ID_PC_Plus_4),
        .rdata1_in(ID_ReadData1), .rdata2_in(ID_ReadData2), .imm_in(ID_Imm),
        .rs1_in(ID_Instr[19:15]), .rs2_in(ID_Instr[24:20]), .rd_in(ID_Instr[11:7]),
        .opcode_in(ID_Instr[6:0]),
        
        // Outputs
        .alu_op_out(EX_ALU_Op), .mask_out(EX_Mask), .br_type_out(EX_Br_Type),
        .wb_sel_out(EX_WB_Sel), .reg_wr_out(EX_Reg_Wr), .mem_read_out(EX_Mem_Read),
        .mem_write_out(EX_Mem_Write), .sel_a_out(EX_Sel_A), .sel_b_out(EX_Sel_B),
        .pc_out(EX_PC), .pc4_out(EX_PC_Plus_4),
        .rdata1_out(EX_ReadData1), .rdata2_out(EX_ReadData2), .imm_out(EX_Imm),
        .rs1_out(EX_Rs1), .rs2_out(EX_Rs2), .rd_out(EX_Rd),
        .opcode_out(EX_Opcode)
    );
    
    // Assign for Hazard Unit feedback
    assign ID_EX_MemRead = EX_Mem_Read;
    assign ID_EX_Rd = EX_Rd;


    // =========================================================================
    // 3. EX STAGE (Execute)
    // =========================================================================
    
    // Forwarding Unit
    wire [1:0] ForwardA;
    wire [1:0] ForwardB;
    wire [4:0] MEM_Rd; // From MEM Stage
    wire       MEM_Reg_Wr; // From MEM Stage
    
    ForwardingUnit fwd_unit (
        .EX_Rs1(EX_Rs1),
        .EX_Rs2(EX_Rs2),
        .MEM_Rd(MEM_Rd),
        .WB_Rd(WB_Rd),
        .MEM_RegWrite(MEM_Reg_Wr),
        .WB_RegWrite(WB_Reg_Wr),
        .ForwardA(ForwardA),
        .ForwardB(ForwardB)
    );

    // ALU Input Muxes (Forwarding Logic)
    wire [31:0] ALU_In1_Tmp;
    wire [31:0] ALU_In2_Tmp;
    wire [31:0] MEM_ALU_Result; // Forwarded from MEM
    // WB_Result is forwarded from WB (defined at output)

    Mux3 mux_fwd_a (
        .in0(EX_ReadData1),
        .in1(WB_Result),    // Forwarding from WB
        .in2(MEM_ALU_Result), // Forwarding from MEM
        .sel(ForwardA),
        .out(ALU_In1_Tmp)
    );

    Mux3 mux_fwd_b (
        .in0(EX_ReadData2),
        .in1(WB_Result),
        .in2(MEM_ALU_Result),
        .sel(ForwardB),
        .out(ALU_In2_Tmp)
    );

    // ALU Source Selection (Immediate vs Register)
    wire [31:0] ALU_A;
    wire [31:0] ALU_B;

    // sel_A: 0 -> RS1, 1 -> PC
    Mux2 mux_alu_a (
        .A(ALU_In1_Tmp),
        .B(EX_PC),
        .sel(EX_Sel_A),
        .C(ALU_A)
    );

    // sel_B: 0 -> RS2, 1 -> Imm
    Mux2 mux_alu_b (
        .A(ALU_In2_Tmp),
        .B(EX_Imm),
        .sel(EX_Sel_B),
        .C(ALU_B)
    );

    // ALU
    wire [31:0] EX_ALU_Result;
    ALU alu_module (
        .A(ALU_A),
        .B(ALU_B),
        .alu_op(EX_ALU_Op),
        .C(EX_ALU_Result)
    );

    // Branch Condition Check
    // Note: Branch check compares Rs1 and Rs2. 
    // WE MUST USE THE FORWARDED VALUES (ALU_In1_Tmp, ALU_In2_Tmp)
    wire Br_Taken;
    BranchCondition br_cond (
        .rs1(ALU_In1_Tmp),
        .rs2(ALU_In2_Tmp),
        .br_type(EX_Br_Type),
        .opcode(EX_Opcode),
        .br_taken(Br_Taken)
    );

    // Branch Target Calculation (PC + Imm)
    // Add4 is just an adder, we can use an adder or reuse Add4 module
    // But Add4 adds 4. We need PC + Imm. Let's use standard + operator for simplicity in V2001
    assign EX_Branch_Target = EX_PC + EX_Imm;
    
    // Logic for taking branch
    // If Br_Taken is true, we Flush IF and ID stages and update PC
    assign PCSrc = Br_Taken;
    assign IF_Flush = Br_Taken; 


    // =========================================================================
    // EX/MEM PIPELINE REGISTER
    // =========================================================================
    wire [31:0] MEM_WriteData;
    wire [31:0] MEM_PC_Plus_4;
    wire [2:0]  MEM_Mask;
    wire [1:0]  MEM_WB_Sel;
    wire        MEM_Mem_Read;
    wire        MEM_Mem_Write;
    
    Pipe_EX_MEM pipe_ex_mem (
        .clk(clk),
        .reset(reset),
        // Control
        .wb_sel_in(EX_WB_Sel), .reg_wr_in(EX_Reg_Wr), 
        .mem_read_in(EX_Mem_Read), .mem_write_in(EX_Mem_Write), .mask_in(EX_Mask),
        // Data
        .alu_result_in(EX_ALU_Result),
        .write_data_in(ALU_In2_Tmp), // Store value (Rs2 forwarded)
        .rd_in(EX_Rd),
        .pc4_in(EX_PC_Plus_4),
        
        // Outputs
        .wb_sel_out(MEM_WB_Sel), .reg_wr_out(MEM_Reg_Wr), 
        .mem_read_out(MEM_Mem_Read), .mem_write_out(MEM_Mem_Write), .mask_out(MEM_Mask),
        .alu_result_out(MEM_ALU_Result),
        .write_data_out(MEM_WriteData),
        .rd_out(MEM_Rd),
        .pc4_out(MEM_PC_Plus_4)
    );


    // =========================================================================
    // 4. MEM STAGE (Memory Access)
    // =========================================================================
    
    wire [31:0] MEM_ReadData;
    wire CacheHit_Wire; // Helper wire to connect to reg output

    CacheSystem cache_system (
        .clk(clk),
        .reset(reset),
        .addr(MEM_ALU_Result),
        .wdata(MEM_WriteData),
        .mem_read(MEM_Mem_Read),
        .mem_write(MEM_Mem_Write),
        .mask(MEM_Mask),
        .rdata(MEM_ReadData),
        .hit(CacheHit_Wire)
    );

    // Update the output reg
    always @(*) CacheHit = CacheHit_Wire;

    // =========================================================================
    // MEM/WB PIPELINE REGISTER
    // =========================================================================
    wire [31:0] WB_ALU_Result;
    wire [31:0] WB_ReadData;
    wire [31:0] WB_PC_Plus_4;
    wire [1:0]  WB_WB_Sel;
    
    Pipe_MEM_WB pipe_mem_wb (
        .clk(clk),
        .reset(reset),
        // Control
        .wb_sel_in(MEM_WB_Sel),
        .reg_wr_in(MEM_Reg_Wr),
        // Data
        .alu_result_in(MEM_ALU_Result),
        .read_data_in(MEM_ReadData),
        .rd_in(MEM_Rd),
        .pc4_in(MEM_PC_Plus_4),
        
        // Outputs
        .wb_sel_out(WB_WB_Sel),
        .reg_wr_out(WB_Reg_Wr),
        .alu_result_out(WB_ALU_Result),
        .read_data_out(WB_ReadData),
        .rd_out(WB_Rd),
        .pc4_out(WB_PC_Plus_4)
    );


    // =========================================================================
    // 5. WB STAGE (Write Back)
    // =========================================================================
    
    // Mux for Write Back Data
    // 0: ALU Result
    // 1: Memory Read Data
    // 2: PC + 4 (for JAL/JALR)
    
    always @(*) begin
        case (WB_WB_Sel)
            2'b00: WB_Result = WB_ALU_Result;
            2'b01: WB_Result = WB_ReadData;
            2'b10: WB_Result = WB_PC_Plus_4;
            default: WB_Result = 32'b0;
        endcase
    end

endmodule
