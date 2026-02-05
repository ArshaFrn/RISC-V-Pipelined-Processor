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

    // Monitor / Debugging
    // This block prints the status of the pipeline every time a signal changes
    initial begin
        $display("------------------------------------------------------------------------------------------------");
        $display("Time | PC (IF) | Instr (ID) | Stall | ForwardA | ForwardB | CacheHit | WB Reg | WB Data");
        $display("------------------------------------------------------------------------------------------------");
        
        // Internal signals can be accessed using "UUT.SignalName"
        $monitor("%4t | %h | %h | %b | %02b | %02b | %b | x%0d | %h",
            $time,
            UUT.IF_PC,        // Current PC
            UUT.ID_Instr,     // Instruction being decoded
            UUT.Stall,        // Hazard Stall Signal
            UUT.ForwardA,     // Forwarding Status A
            UUT.ForwardB,     // Forwarding Status B
            UUT.CacheHit,     // Cache Hit Status
            UUT.WB_Rd,        // Register being written back
            UUT.WB_Result     // Value being written back
        );
    end

endmodule
