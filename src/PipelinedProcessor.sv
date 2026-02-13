`timescale 1ns / 1ps

module PipelinedProcessor (
    input clk,
    input reset,
    output [31:0] IF_PC,
    output [31:0] ID_Instr,
    output Stall,
    output reg CacheHit,
    output [4:0] WB_Rd,
    output reg [31:0] WB_Result
);

    // 1. IF STAGE
    wire [31:0] IF_Next_PC;
    wire [31:0] IF_PC_Plus_4;
    wire [31:0] IF_Instr;
    wire PCSrc; 
    wire [31:0] EX_Branch_Target;

    // Branch vs Normal
    assign IF_Next_PC = (PCSrc) ? EX_Branch_Target : IF_PC_Plus_4;

    // If Stall is active (PC_Write=0), PC keeps old value.
    wire PC_Write;
    
    wire [31:0] PC_Out;
    assign IF_PC = PC_Out;


    // For Stall
    wire [31:0] PC_Input_Final;
    assign PC_Input_Final = (PC_Write) ? IF_Next_PC : PC_Out;

    PC pc_module (
        .clk(clk),
        .reset(reset),
        .A(PC_Out),       // Current PC
        .B(PC_Input_Final) // Next PC
    );

    Add4 pc_adder (
        .A(PC_Out),
        .B(IF_PC_Plus_4)
    );

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
    
    Pipe_IF_ID pipe_if_id (
        .clk(clk),
        .reset(reset),
        .en(IF_ID_Write), //Stall
        .flush(IF_Flush),
        .pc_in(PC_Out),
        .pc4_in(IF_PC_Plus_4),
        .instr_in(IF_Instr),
        .pc_out(ID_PC),
        .pc4_out(ID_PC_Plus_4),
        .instr_out(ID_Instr)
    );


    // =========================================================================
    // 2. ID STAGE
    // =========================================================================
    wire [31:0] ID_ReadData1;
    wire [31:0] ID_ReadData2;
    wire [31:0] ID_Imm;
    wire [3:0]  ID_ALU_Op;
    wire [2:0]  ID_Mask;
    wire [2:0]  ID_Br_Type;
    wire [1:0]  ID_WB_Sel;
    wire        ID_Reg_Wr;
    wire        ID_Rd_En;
    wire        ID_Wr_En;
    wire        ID_Sel_A;
    wire        ID_Sel_B;
    
    Controller controller (
        .instruction(ID_Instr),
        .alu_op(ID_ALU_Op),
        .mask(ID_Mask),
        .br_type(ID_Br_Type),
        .reg_wr(ID_Reg_Wr),
        .sel_A(ID_Sel_A),
        .sel_B(ID_Sel_B),
        .rd_en(ID_Rd_En), 
        .wr_en(ID_Wr_En),
        .wb_sel(ID_WB_Sel)
    );

    wire WB_Reg_Wr; // From WB stage
    
    RegisterFile rf (
        .clk(clk),
        .reset(reset),
        .reg_wr(WB_Reg_Wr),
        .raddr1(ID_Instr[19:15]),
        .raddr2(ID_Instr[24:20]),
        .waddr(WB_Rd),      // from WB
        .wdata(WB_Result),  // from WB
        .rdata1(ID_ReadData1),
        .rdata2(ID_ReadData2)
    );

    ImmediateGenerator imm_gen (
        .clk(clk), 
        .instruction(ID_Instr),
        .imm_out(ID_Imm)
    );

    // Detects Load-Use hazards
    wire ID_EX_MemRead;
    wire [4:0] ID_EX_Rd;
    
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
    assign ID_Flush_Hazard = Stall || IF_Flush; // Stalling OR branch taken

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
    wire [6:0]  EX_Opcode;

    Pipe_ID_EX pipe_id_ex (
        .clk(clk),
        .reset(reset),
        .flush(ID_Flush_Hazard),
        // Control 
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
    
    // for Hazard Unit feedback
    assign ID_EX_MemRead = EX_Mem_Read;
    assign ID_EX_Rd = EX_Rd;


    // =========================================================================
    // 3. EX STAGE
    // =========================================================================
    
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

    wire [31:0] ALU_In1_Tmp;
    wire [31:0] ALU_In2_Tmp;
    wire [31:0] MEM_ALU_Result; // Forwarded from MEM

    Mux3 mux_fwd_a (
        .in0(EX_ReadData1),
        .in1(WB_Result),   
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

    wire [31:0] EX_ALU_Result;
    ALU alu_module (
        .A(ALU_A),
        .B(ALU_B),
        .alu_op(EX_ALU_Op),
        .C(EX_ALU_Result)
    );

    // Branch Condition Check
    wire Br_Taken;
    BranchCondition br_cond (
        .rs1(ALU_In1_Tmp),
        .rs2(ALU_In2_Tmp),
        .br_type(EX_Br_Type),
        .opcode(EX_Opcode),
        .br_taken(Br_Taken)
    );

    assign EX_Branch_Target = EX_PC + EX_Imm;
    
    // Logic for Taken branch
    // If Br_Taken is 1, we Flush IF and ID stages and update PC
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
        .write_data_in(ALU_In2_Tmp),
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
    // 4. MEM STAGE
    // =========================================================================
    
    wire [31:0] MEM_ReadData;
    wire CacheHit_Wire;

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
    // 5. WB STAGE
    // =========================================================================
    
    // Mux (for Write Back Data)
    // 0: ALU Result
    // 1: Memory Read Data
    // 2: PC + 4 (for JAL)
    
    always @(*) begin
        case (WB_WB_Sel)
            2'b00: WB_Result = WB_ALU_Result;
            2'b01: WB_Result = WB_ReadData;
            2'b10: WB_Result = WB_PC_Plus_4;
            default: WB_Result = 32'b0;
        endcase
    end

endmodule
