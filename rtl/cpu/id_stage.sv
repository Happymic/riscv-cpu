//////////////////////////////////////////////////////////////////////////////////
// Module: id_stage
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Instruction Decode (ID) stage of the 5-stage pipeline
//              Decodes instructions, reads register file, generates control signals,
//              and prepares immediate values
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

import cpu_types::*;

module id_stage (
    input  logic        clk,
    input  logic        rst_n,
    input  if_id_reg_t  if_id_reg,          // IF/ID pipeline register
    input  logic        stall,              // Stall signal from hazard unit
    input  logic        flush,              // Flush signal for branch misprediction
    
    // Register file interface
    input  logic [31:0] rf_rs1_data,        // Register file rs1 data
    input  logic [31:0] rf_rs2_data,        // Register file rs2 data
    
    // To ID/EX register
    output id_ex_reg_t  id_ex_next,         // Next ID/EX register values
    
    // Decoded instruction fields
    output logic [6:0]  opcode,
    output logic [2:0]  funct3,
    output logic [6:0]  funct7
);

    // Instruction fields extraction
    logic [4:0]  rs1, rs2, rd;
    logic [31:0] instruction;
    logic [31:0] immediate;
    
    // Control signals
    logic        alu_src;
    logic [3:0]  alu_op;
    logic        mem_read;
    logic        mem_write;
    logic        reg_write;
    logic        branch;
    logic        jump;
    logic        jal;
    logic        jalr;
    logic        lui;
    logic        auipc;
    
    // Extract instruction
    assign instruction = if_id_reg.instruction;
    
    // Decode instruction fields
    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];
    
    // Immediate generation based on instruction type
    always_comb begin
        immediate = 32'h0;
        
        case (opcode)
            // I-type immediate (arithmetic, loads, JALR)
            7'b0010011,  // Immediate arithmetic
            7'b0000011,  // Loads
            7'b1100111:  // JALR
                immediate = {{20{instruction[31]}}, instruction[31:20]};
            
            // S-type immediate (stores)
            7'b0100011:  // Stores
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            
            // B-type immediate (branches)
            7'b1100011:  // Branches
                immediate = {{19{instruction[31]}}, instruction[31], instruction[7], 
                           instruction[30:25], instruction[11:8], 1'b0};
            
            // U-type immediate (LUI, AUIPC)
            7'b0110111,  // LUI
            7'b0010111:  // AUIPC
                immediate = {instruction[31:12], 12'h0};
            
            // J-type immediate (JAL)
            7'b1101111:  // JAL
                immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12], 
                           instruction[20], instruction[30:21], 1'b0};
            
            default: immediate = 32'h0;
        endcase
    end
    
    // Control signal generation
    always_comb begin
        // Default values
        alu_src    = 1'b0;
        alu_op     = 4'b0000;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        reg_write  = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        jal        = 1'b0;
        jalr       = 1'b0;
        lui        = 1'b0;
        auipc      = 1'b0;
        
        case (opcode)
            // R-type instructions
            7'b0110011: begin
                reg_write = 1'b1;
                alu_src = 1'b0;  // Use register value
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? 4'b0001 : 4'b0000;  // SUB : ADD
                    3'b001: alu_op = 4'b0010;  // SLL
                    3'b010: alu_op = 4'b0011;  // SLT
                    3'b011: alu_op = 4'b0100;  // SLTU
                    3'b100: alu_op = 4'b0101;  // XOR
                    3'b101: alu_op = (funct7[5]) ? 4'b0111 : 4'b0110;  // SRA : SRL
                    3'b110: alu_op = 4'b1000;  // OR
                    3'b111: alu_op = 4'b1001;  // AND
                    default: alu_op = 4'b0000;
                endcase
            end
            
            // I-type arithmetic instructions
            7'b0010011: begin
                reg_write = 1'b1;
                alu_src = 1'b1;  // Use immediate
                case (funct3)
                    3'b000: alu_op = 4'b0000;  // ADDI
                    3'b010: alu_op = 4'b0011;  // SLTI
                    3'b011: alu_op = 4'b0100;  // SLTIU
                    3'b100: alu_op = 4'b0101;  // XORI
                    3'b110: alu_op = 4'b1000;  // ORI
                    3'b111: alu_op = 4'b1001;  // ANDI
                    3'b001: alu_op = 4'b0010;  // SLLI
                    3'b101: alu_op = (funct7[5]) ? 4'b0111 : 4'b0110;  // SRAI : SRLI
                    default: alu_op = 4'b0000;
                endcase
            end
            
            // Load instructions
            7'b0000011: begin
                reg_write = 1'b1;
                mem_read = 1'b1;
                alu_src = 1'b1;  // Use immediate for address calculation
                alu_op = 4'b0000;  // ADD for address calculation
            end
            
            // Store instructions
            7'b0100011: begin
                mem_write = 1'b1;
                alu_src = 1'b1;  // Use immediate for address calculation
                alu_op = 4'b0000;  // ADD for address calculation
            end
            
            // Branch instructions
            7'b1100011: begin
                branch = 1'b1;
                alu_src = 1'b0;  // Compare registers
                case (funct3)
                    3'b000: alu_op = 4'b1010;  // BEQ
                    3'b001: alu_op = 4'b1011;  // BNE
                    3'b100: alu_op = 4'b1100;  // BLT
                    3'b101: alu_op = 4'b1101;  // BGE
                    3'b110: alu_op = 4'b1110;  // BLTU
                    3'b111: alu_op = 4'b1111;  // BGEU
                    default: alu_op = 4'b1010;
                endcase
            end
            
            // JAL instruction
            7'b1101111: begin
                reg_write = 1'b1;
                jump = 1'b1;
                jal = 1'b1;
                alu_op = 4'b0000;  // PC + 4 will be stored
            end
            
            // JALR instruction
            7'b1100111: begin
                reg_write = 1'b1;
                jump = 1'b1;
                jalr = 1'b1;
                alu_src = 1'b1;
                alu_op = 4'b0000;  // ADD for target calculation
            end
            
            // LUI instruction
            7'b0110111: begin
                reg_write = 1'b1;
                lui = 1'b1;
                alu_src = 1'b1;
                alu_op = 4'b0000;  // Pass immediate through
            end
            
            // AUIPC instruction
            7'b0010111: begin
                reg_write = 1'b1;
                auipc = 1'b1;
                alu_src = 1'b1;
                alu_op = 4'b0000;  // ADD PC + immediate
            end
            
            default: begin
                // NOP or invalid instruction
                alu_op = 4'b0000;
            end
        endcase
    end
    
    // ID/EX register preparation
    always_comb begin
        id_ex_next = '0;  // Default values
        
        if (flush || stall) begin
            // Insert NOP bubble
            id_ex_next.valid = 1'b0;
            id_ex_next.reg_write = 1'b0;
            id_ex_next.mem_read = 1'b0;
            id_ex_next.mem_write = 1'b0;
        end else if (if_id_reg.valid) begin
            // Normal instruction decode
            id_ex_next.pc = if_id_reg.pc;
            id_ex_next.rs1_data = (lui) ? 32'h0 : rf_rs1_data;  // LUI doesn't use rs1
            id_ex_next.rs2_data = rf_rs2_data;
            id_ex_next.imm = immediate;
            id_ex_next.rs1_addr = rs1;
            id_ex_next.rs2_addr = rs2;
            id_ex_next.rd_addr = rd;
            id_ex_next.opcode = opcode;
            id_ex_next.funct3 = funct3;
            id_ex_next.funct7 = funct7;
            id_ex_next.alu_src = alu_src;
            id_ex_next.alu_op = alu_op;
            id_ex_next.mem_read = mem_read;
            id_ex_next.mem_write = mem_write;
            id_ex_next.reg_write = reg_write;
            id_ex_next.branch = branch;
            id_ex_next.jump = jump;
            id_ex_next.valid = 1'b1;
            
            // Special handling for AUIPC - pass PC instead of rs1
            if (auipc) begin
                id_ex_next.rs1_data = if_id_reg.pc;
            end
        end
    end
    
endmodule