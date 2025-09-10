//////////////////////////////////////////////////////////////////////////////////
// Module: control_unit
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Control unit for RISC-V RV32I instruction set
//              Generates control signals based on opcode, funct3, and funct7 fields
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module control_unit (
    input  logic [6:0]  opcode,             // Instruction opcode
    input  logic [2:0]  funct3,             // Function code field 3
    input  logic [6:0]  funct7,             // Function code field 7
    
    // Control signals
    output logic        alu_src,            // ALU source: 0=register, 1=immediate
    output logic [3:0]  alu_op,             // ALU operation code
    output logic        mem_read,           // Memory read enable
    output logic        mem_write,          // Memory write enable
    output logic        reg_write,          // Register write enable
    output logic        branch,             // Branch instruction
    output logic        jump,               // Jump instruction
    output logic        mem_to_reg          // Write back source: 0=ALU, 1=memory
);

    // Instruction opcodes for RV32I
    localparam OPCODE_R_TYPE    = 7'b0110011;  // R-type arithmetic
    localparam OPCODE_I_TYPE    = 7'b0010011;  // I-type arithmetic
    localparam OPCODE_LOAD      = 7'b0000011;  // Load instructions
    localparam OPCODE_STORE     = 7'b0100011;  // Store instructions
    localparam OPCODE_BRANCH    = 7'b1100011;  // Branch instructions
    localparam OPCODE_JAL       = 7'b1101111;  // Jump and link
    localparam OPCODE_JALR      = 7'b1100111;  // Jump and link register
    localparam OPCODE_LUI       = 7'b0110111;  // Load upper immediate
    localparam OPCODE_AUIPC     = 7'b0010111;  // Add upper immediate to PC
    
    // ALU operation codes
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLL  = 4'b0010;
    localparam ALU_SLT  = 4'b0011;
    localparam ALU_SLTU = 4'b0100;
    localparam ALU_XOR  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_OR   = 4'b1000;
    localparam ALU_AND  = 4'b1001;
    localparam ALU_BEQ  = 4'b1010;
    localparam ALU_BNE  = 4'b1011;
    localparam ALU_BLT  = 4'b1100;
    localparam ALU_BGE  = 4'b1101;
    localparam ALU_BLTU = 4'b1110;
    localparam ALU_BGEU = 4'b1111;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Control Signal Generation
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Default control signals
        alu_src     = 1'b0;
        alu_op      = ALU_ADD;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        reg_write   = 1'b0;
        branch      = 1'b0;
        jump        = 1'b0;
        mem_to_reg  = 1'b0;
        
        case (opcode)
            // R-type instructions
            OPCODE_R_TYPE: begin
                reg_write   = 1'b1;
                alu_src     = 1'b0;  // Use register value
                mem_to_reg  = 1'b0;  // Use ALU result
                
                // Determine ALU operation based on funct3 and funct7
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;   // SUB : ADD
                    3'b001: alu_op = ALU_SLL;   // SLL
                    3'b010: alu_op = ALU_SLT;   // SLT
                    3'b011: alu_op = ALU_SLTU;  // SLTU
                    3'b100: alu_op = ALU_XOR;   // XOR
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;   // SRA : SRL
                    3'b110: alu_op = ALU_OR;    // OR
                    3'b111: alu_op = ALU_AND;   // AND
                    default: alu_op = ALU_ADD;
                endcase
            end
            
            // I-type arithmetic instructions
            OPCODE_I_TYPE: begin
                reg_write   = 1'b1;
                alu_src     = 1'b1;  // Use immediate
                mem_to_reg  = 1'b0;  // Use ALU result
                
                case (funct3)
                    3'b000: alu_op = ALU_ADD;   // ADDI
                    3'b010: alu_op = ALU_SLT;   // SLTI
                    3'b011: alu_op = ALU_SLTU;  // SLTIU
                    3'b100: alu_op = ALU_XOR;   // XORI
                    3'b110: alu_op = ALU_OR;    // ORI
                    3'b111: alu_op = ALU_AND;   // ANDI
                    3'b001: alu_op = ALU_SLL;   // SLLI
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;  // SRAI : SRLI
                    default: alu_op = ALU_ADD;
                endcase
            end
            
            // Load instructions
            OPCODE_LOAD: begin
                reg_write   = 1'b1;
                mem_read    = 1'b1;
                alu_src     = 1'b1;  // Use immediate for address calculation
                alu_op      = ALU_ADD;  // ADD for address calculation
                mem_to_reg  = 1'b1;  // Use memory data
            end
            
            // Store instructions
            OPCODE_STORE: begin
                mem_write   = 1'b1;
                alu_src     = 1'b1;  // Use immediate for address calculation
                alu_op      = ALU_ADD;  // ADD for address calculation
            end
            
            // Branch instructions
            OPCODE_BRANCH: begin
                branch      = 1'b1;
                alu_src     = 1'b0;  // Compare registers
                
                case (funct3)
                    3'b000: alu_op = ALU_BEQ;   // BEQ
                    3'b001: alu_op = ALU_BNE;   // BNE
                    3'b100: alu_op = ALU_BLT;   // BLT
                    3'b101: alu_op = ALU_BGE;   // BGE
                    3'b110: alu_op = ALU_BLTU;  // BLTU
                    3'b111: alu_op = ALU_BGEU;  // BGEU
                    default: alu_op = ALU_BEQ;
                endcase
            end
            
            // JAL instruction
            OPCODE_JAL: begin
                reg_write   = 1'b1;
                jump        = 1'b1;
                alu_op      = ALU_ADD;  // PC + 4 calculation
                mem_to_reg  = 1'b0;     // Use ALU result (PC + 4)
            end
            
            // JALR instruction
            OPCODE_JALR: begin
                reg_write   = 1'b1;
                jump        = 1'b1;
                alu_src     = 1'b1;     // Use immediate
                alu_op      = ALU_ADD;  // ADD for target calculation
                mem_to_reg  = 1'b0;     // Use ALU result (PC + 4)
            end
            
            // LUI instruction
            OPCODE_LUI: begin
                reg_write   = 1'b1;
                alu_src     = 1'b1;     // Use immediate
                alu_op      = ALU_ADD;  // Pass immediate through (add with 0)
                mem_to_reg  = 1'b0;     // Use ALU result
            end
            
            // AUIPC instruction
            OPCODE_AUIPC: begin
                reg_write   = 1'b1;
                alu_src     = 1'b1;     // Use immediate
                alu_op      = ALU_ADD;  // ADD PC + immediate
                mem_to_reg  = 1'b0;     // Use ALU result
            end
            
            default: begin
                // Invalid instruction - all control signals remain at default (NOP)
            end
        endcase
    end
    
endmodule