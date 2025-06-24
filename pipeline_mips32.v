`timescale 1ns / 1ps

module pipeline_mips32(
    input wire clk1,
    input wire clk2
    );
    reg [31:0] PC; // Program counter
    
    // Pipeline registers
    reg [31:0] IF_ID_IR, IF_ID_NPC;
    reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_IMM;
    reg [31:0] EX_MEM_IR, EX_MEM_NPC, EX_MEM_B, EX_MEM_ALUout;
    reg EX_MEM_cond;
    reg [31:0] MEM_WB_IR, MEM_WB_LMD, MEM_WB_ALUout;
    reg [2:0] ID_EX_TYPE, EX_MEM_TYPE, MEM_WB_TYPE;
    reg [31:0] reg_bank [0:31]; // Register bank
    reg [31:0] memory [0:1023]; // Program memory
    
    // Operation codes
    parameter ADD=6'b000000,
              SUB=6'b000001,
              AND=6'b000010,
              OR=6'b000011,
              SLT=6'b000100,
              MUL=6'b000101,
              HLT=6'b000110,
              LW=6'b000111,
              SW=6'b001000,
              ADDI=6'b001001,
              SUBI=6'b001010,
              SLTI=6'b001011,
              BNEQZ=6'b001100,
              BEQZ=6'b001101;
    
    // ALU control codes
    parameter RR_ALU=3'b000,
              RM_ALU=3'b001,
              LOAD=3'b010,
              STORE=3'b011,
              BRANCH=3'b100,
              HALT=3'b101;
              
    // Control registers
    reg halted, has_taken_branch;
              
    // IF STAGE
    always @(posedge clk1) begin
        if(halted == 0) begin
            if(((EX_MEM_cond==1) && (EX_MEM_IR[31:26]==BEQZ)) || //if it is a braanching instr if =0 and cond=1 if val=0
               ((EX_MEM_cond==0) && (EX_MEM_IR[31:26]==BNEQZ))) begin
                IF_ID_IR <= #2 memory[EX_MEM_ALUout];
                IF_ID_NPC <= EX_MEM_ALUout + 1;
                PC <= EX_MEM_ALUout + 1;
                has_taken_branch <= 1'b1;
            end
            else begin
                IF_ID_IR <= memory[PC];
                IF_ID_NPC <= PC + 1;
                PC <= PC + 1;
            end
        end
    end
    
    // ID STAGE
    always @(posedge clk2) begin
        if(halted == 0) begin
            // Load operands into ID/EX pipeline registers
            if(IF_ID_IR[25:21] == 5'b0) 
                ID_EX_A <= 0;
            else 
                ID_EX_A <= #2 reg_bank[IF_ID_IR[25:21]];
            
            if(IF_ID_IR[20:16] == 5'b0) 
                ID_EX_B <= 0;
            else 
                ID_EX_B <= #2 reg_bank[IF_ID_IR[20:16]];
            
            ID_EX_IMM <= #2 {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};
            ID_EX_IR <= #2 IF_ID_IR;
            ID_EX_NPC <= #2 IF_ID_NPC;
            
            // Decode instruction type
            case(IF_ID_IR[31:26])
                ADD, SUB, AND, MUL, SLT, OR: ID_EX_TYPE <= #2 RR_ALU;
                ADDI, SUBI, SLTI: ID_EX_TYPE <= #2 RM_ALU;
                LW: ID_EX_TYPE <= #2 LOAD;
                SW: ID_EX_TYPE <= #2 STORE;
                HLT: ID_EX_TYPE <= #2 HALT;
                BEQZ, BNEQZ: ID_EX_TYPE <= #2 BRANCH;
                default: ID_EX_TYPE <= #2 HALT;
            endcase
        end
    end
    
    // EX STAGE
    always @(posedge clk1) begin
        if(halted == 0) begin
            EX_MEM_IR <= #2 ID_EX_IR;
            EX_MEM_TYPE <= #2 ID_EX_TYPE;
            EX_MEM_NPC <= #2 ID_EX_NPC; // Added to fix pipeline coherency
            has_taken_branch <= #2 0;
            
            case(ID_EX_TYPE)
                RR_ALU: begin
                    case(ID_EX_IR[31:26])
                        ADD: EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_B;
                        SUB: EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_B;
                        AND: EX_MEM_ALUout <= #2 ID_EX_A & ID_EX_B;
                        OR:  EX_MEM_ALUout <= #2 ID_EX_A | ID_EX_B;
                        SLT: EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_B;
                        MUL: EX_MEM_ALUout <= #2 ID_EX_A * ID_EX_B;
                        default: EX_MEM_ALUout <= #2 32'hxxxxxxxx;
                    endcase
                end
                
                RM_ALU: begin
                    case(ID_EX_IR[31:26])
                        ADDI: EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_IMM;
                        SUBI: EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_IMM;
                        SLTI: EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_IMM;
                        default: EX_MEM_ALUout <= #2 32'hxxxxxxxx;
                    endcase
                end
                
                LOAD, STORE: begin
                    EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_IMM;
                    EX_MEM_B <= #2 ID_EX_B;
                end
                
                BRANCH: begin
                    EX_MEM_ALUout <= #2 ID_EX_NPC + ID_EX_IMM;
                    EX_MEM_cond <= #2 (ID_EX_A == 0);
                end
            endcase
        end
    end
        
    // MEM STAGE
    always @(posedge clk2) begin
        if(halted == 0) begin
            MEM_WB_IR <= #2 EX_MEM_IR;
            MEM_WB_TYPE <= #2 EX_MEM_TYPE;
            MEM_WB_ALUout <= #2 EX_MEM_ALUout; // Always forward ALU result
            
            case(EX_MEM_TYPE) // Fixed: Was using MEM_WB_TYPE incorrectly
                LOAD:
                    MEM_WB_LMD <= #2 memory[EX_MEM_ALUout];
                STORE:
                    if(has_taken_branch == 0) begin
                        memory[EX_MEM_ALUout] <= #2 EX_MEM_B;
                    end
            endcase
        end
    end
        
    // WB STAGE
    always @(posedge clk1) begin
        if(halted == 0 && has_taken_branch == 0) begin // Fixed: added halted condition
            case(MEM_WB_TYPE)
                RR_ALU: 
                    reg_bank[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUout; // rd
                RM_ALU: 
                    reg_bank[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUout; // rt
                LOAD: 
                    reg_bank[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD; // rt 
                HALT: 
                    halted <= #2 1'b1;
            endcase
        end
    end
endmodule