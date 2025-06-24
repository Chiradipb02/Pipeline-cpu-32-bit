`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.05.2025 19:29:49
// Design Name: 
// Module Name: processor_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module processor_tb;
    reg clk1, clk2;
    integer k;
    pipeline_mips32 mips(.clk1(clk1), .clk2(clk2));
    
    // Clock generation - properly alternating clocks
    initial begin
        clk1 = 0; clk2 = 0;
        repeat(50) begin
            #5 clk1 = 1; #5 clk1 = 0;
            #5 clk2 = 1; #5 clk2 = 0;
        end
    end
    
    initial begin
        // Initialize reg bank
        for (k = 0; k <= 31; k = k + 1)
            mips.reg_bank[k] = k;
            
        // Load instructions into instruction memory
        mips.memory[0] = 32'h2401000A; // ADDI R1, R0, 10
        mips.memory[1] = 32'h24020014; // ADDI R2, R0, 20
        mips.memory[2] = 32'h24030019; // ADDI R3, R0, 25
        mips.memory[3] = 32'h0CE73800; // OR R7, R7, R7
        mips.memory[4] = 32'h0CE73800; // OR R7, R7, R7
        mips.memory[5] = 32'h00222000; // ADD R4, R1, R2
        mips.memory[6] = 32'h0CE73800; // OR R7, R7, R7
        mips.memory[7] = 32'h0CE73800; // OR R7, R7, R7
        mips.memory[8] = 32'h00832800; // ADD R5, R4, R3
        mips.memory[9] = 32'h18000000; // HLT
        
        // Init processor
        mips.halted = 0;
        mips.PC = 0;
        mips.has_taken_branch = 0;
 
        // Add debugging display statements
        $display("Starting simulation...");
        
        // Monitor key signals
        $monitor("Time=%0d, PC=%0d, halted=%0d, R1=%0d, R2=%0d, R3=%0d, R4=%0d, R5=%0d",
                $time, mips.PC, mips.halted, 
                mips.reg_bank[1], mips.reg_bank[2], mips.reg_bank[3],
                mips.reg_bank[4], mips.reg_bank[5]);
        
        // Wait for halt or timeout
        wait(mips.halted == 1);
        
        // Display final results
        $display("\n=== SIMULATION COMPLETED ===");
        $display("Final Register Values:");
        for (k = 0; k <= 7; k = k + 1)
            $display("R%0d = %0d", k, mips.reg_bank[k]);
        $finish;
    end
    
    // Debug waveforms - add pipeline stage monitoring
    initial begin
        $dumpfile("pipeline_mips.vcd");
        $dumpvars(0, processor_tb);
    end
endmodule