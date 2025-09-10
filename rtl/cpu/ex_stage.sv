//////////////////////////////////////////////////////////////////////////////////
// Module: ex_stage
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Execute (EX) stage of the 5-stage pipeline
//              Performs ALU operations, branch resolution, and address calculation
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

import cpu_types::*;

module ex_stage (
    input  logic        clk,
    input  logic        rst_n,
    input  id_ex_reg_t  id_ex_reg,          // ID/EX pipeline register
    
    // Forwarding inputs
    input  logic [1:0]  forward_a,          // Forwarding control for rs1
    input  logic [1:0]  forward_b,          // Forwarding control for rs2
    input  logic [31:0] ex_mem_alu_result,  // Forwarding from EX/MEM
    input  logic [31:0] wb_data,            // Forwarding from WB
    
    // To EX/MEM register
    output ex_mem_reg_t ex_mem_next,        // Next EX/MEM register values
    
    // Branch resolution
    output logic        branch_taken,       // Branch taken signal
    output logic [31:0] branch_target       // Branch target address
);

    // ALU signals
    logic [31:0] alu_operand_a;
    logic [31:0] alu_operand_b;
    logic [31:0] alu_result;
    logic        alu_zero;
    logic        alu_negative;
    logic        alu_overflow;
    
    // Forwarding mux outputs
    logic [31:0] forwarded_rs1;
    logic [31:0] forwarded_rs2;
    
    // Branch comparison signals
    logic        branch_condition;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Forwarding Multiplexers
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Forward rs1
        case (forward_a)
            2'b00: forwarded_rs1 = id_ex_reg.rs1_data;      // No forwarding
            2'b01: forwarded_rs1 = ex_mem_alu_result;       // Forward from EX/MEM
            2'b10: forwarded_rs1 = wb_data;                 // Forward from MEM/WB
            default: forwarded_rs1 = id_ex_reg.rs1_data;
        endcase
        
        // Forward rs2
        case (forward_b)
            2'b00: forwarded_rs2 = id_ex_reg.rs2_data;      // No forwarding
            2'b01: forwarded_rs2 = ex_mem_alu_result;       // Forward from EX/MEM
            2'b10: forwarded_rs2 = wb_data;                 // Forward from MEM/WB
            default: forwarded_rs2 = id_ex_reg.rs2_data;
        endcase
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // ALU Input Selection
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Operand A selection
        alu_operand_a = forwarded_rs1;
        
        // Operand B selection (register or immediate)
        if (id_ex_reg.alu_src) begin
            alu_operand_b = id_ex_reg.imm;
        end else begin
            alu_operand_b = forwarded_rs2;
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // ALU Operations
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        alu_result = 32'h0;
        alu_zero = 1'b0;
        alu_negative = 1'b0;
        alu_overflow = 1'b0;
        
        case (id_ex_reg.alu_op)
            4'b0000: begin  // ADD
                alu_result = alu_operand_a + alu_operand_b;
                alu_overflow = (alu_operand_a[31] == alu_operand_b[31]) && 
                              (alu_result[31] != alu_operand_a[31]);
            end
            
            4'b0001: begin  // SUB
                alu_result = alu_operand_a - alu_operand_b;
                alu_overflow = (alu_operand_a[31] != alu_operand_b[31]) && 
                              (alu_result[31] != alu_operand_a[31]);
            end
            
            4'b0010: begin  // SLL (Shift Left Logical)
                alu_result = alu_operand_a << alu_operand_b[4:0];
            end
            
            4'b0011: begin  // SLT (Set Less Than - signed)
                alu_result = ($signed(alu_operand_a) < $signed(alu_operand_b)) ? 32'h1 : 32'h0;
            end
            
            4'b0100: begin  // SLTU (Set Less Than - unsigned)
                alu_result = (alu_operand_a < alu_operand_b) ? 32'h1 : 32'h0;
            end
            
            4'b0101: begin  // XOR
                alu_result = alu_operand_a ^ alu_operand_b;
            end
            
            4'b0110: begin  // SRL (Shift Right Logical)
                alu_result = alu_operand_a >> alu_operand_b[4:0];
            end
            
            4'b0111: begin  // SRA (Shift Right Arithmetic)
                alu_result = $signed(alu_operand_a) >>> alu_operand_b[4:0];
            end
            
            4'b1000: begin  // OR
                alu_result = alu_operand_a | alu_operand_b;
            end
            
            4'b1001: begin  // AND
                alu_result = alu_operand_a & alu_operand_b;
            end
            
            // Branch comparison operations
            4'b1010: begin  // BEQ (Branch if Equal)
                alu_result = (alu_operand_a == alu_operand_b) ? 32'h1 : 32'h0;
            end
            
            4'b1011: begin  // BNE (Branch if Not Equal)
                alu_result = (alu_operand_a != alu_operand_b) ? 32'h1 : 32'h0;
            end
            
            4'b1100: begin  // BLT (Branch if Less Than - signed)
                alu_result = ($signed(alu_operand_a) < $signed(alu_operand_b)) ? 32'h1 : 32'h0;
            end
            
            4'b1101: begin  // BGE (Branch if Greater or Equal - signed)
                alu_result = ($signed(alu_operand_a) >= $signed(alu_operand_b)) ? 32'h1 : 32'h0;
            end
            
            4'b1110: begin  // BLTU (Branch if Less Than - unsigned)
                alu_result = (alu_operand_a < alu_operand_b) ? 32'h1 : 32'h0;
            end
            
            4'b1111: begin  // BGEU (Branch if Greater or Equal - unsigned)
                alu_result = (alu_operand_a >= alu_operand_b) ? 32'h1 : 32'h0;
            end
            
            default: alu_result = 32'h0;
        endcase
        
        // Set flags
        alu_zero = (alu_result == 32'h0);
        alu_negative = alu_result[31];
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Branch Resolution
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        branch_taken = 1'b0;
        branch_target = 32'h0;
        
        if (id_ex_reg.branch && id_ex_reg.valid) begin
            // Branch instruction - check condition
            branch_condition = (alu_result != 32'h0);
            if (branch_condition) begin
                branch_taken = 1'b1;
                branch_target = id_ex_reg.pc + id_ex_reg.imm;
            end
        end else if (id_ex_reg.jump && id_ex_reg.valid) begin
            // Jump instruction
            branch_taken = 1'b1;
            if (id_ex_reg.opcode == 7'b1101111) begin  // JAL
                branch_target = id_ex_reg.pc + id_ex_reg.imm;
            end else if (id_ex_reg.opcode == 7'b1100111) begin  // JALR
                branch_target = (forwarded_rs1 + id_ex_reg.imm) & ~32'h1;  // Clear LSB
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // EX/MEM Register Preparation
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        ex_mem_next = '0;  // Default values
        
        if (id_ex_reg.valid) begin
            ex_mem_next.pc = id_ex_reg.pc;
            ex_mem_next.rd_addr = id_ex_reg.rd_addr;
            ex_mem_next.mem_read = id_ex_reg.mem_read;
            ex_mem_next.mem_write = id_ex_reg.mem_write;
            ex_mem_next.reg_write = id_ex_reg.reg_write;
            ex_mem_next.funct3 = id_ex_reg.funct3;
            ex_mem_next.branch_taken = branch_taken;
            ex_mem_next.branch_target = branch_target;
            ex_mem_next.valid = 1'b1;
            
            // ALU result or PC+4 for JAL/JALR
            if (id_ex_reg.jump) begin
                ex_mem_next.alu_result = id_ex_reg.pc + 32'd4;  // Return address
            end else begin
                ex_mem_next.alu_result = alu_result;
            end
            
            // Store data (rs2) with forwarding
            ex_mem_next.rs2_data = forwarded_rs2;
        end
    end
    
endmodule