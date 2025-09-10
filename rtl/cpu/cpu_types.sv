//////////////////////////////////////////////////////////////////////////////////
// Package: cpu_types
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Type definitions for the CPU pipeline registers
//////////////////////////////////////////////////////////////////////////////////

`ifndef CPU_TYPES_SV
`define CPU_TYPES_SV

package cpu_types;

    // IF/ID Pipeline Register
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] instruction;
        logic        valid;
        logic        exception;
        logic [31:0] exception_cause;
    } if_id_reg_t;
    
    // ID/EX Pipeline Register
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] rs1_data;
        logic [31:0] rs2_data;
        logic [31:0] imm;
        logic [4:0]  rs1_addr;
        logic [4:0]  rs2_addr;
        logic [4:0]  rd_addr;
        logic [6:0]  opcode;
        logic [2:0]  funct3;
        logic [6:0]  funct7;
        logic        alu_src;
        logic [3:0]  alu_op;
        logic        mem_read;
        logic        mem_write;
        logic        reg_write;
        logic        branch;
        logic        jump;
        logic        valid;
    } id_ex_reg_t;
    
    // EX/MEM Pipeline Register
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] alu_result;
        logic [31:0] rs2_data;
        logic [4:0]  rd_addr;
        logic        mem_read;
        logic        mem_write;
        logic        reg_write;
        logic [2:0]  funct3;
        logic        branch_taken;
        logic [31:0] branch_target;
        logic        valid;
    } ex_mem_reg_t;
    
    // MEM/WB Pipeline Register
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] alu_result;
        logic [31:0] mem_data;
        logic [4:0]  rd_addr;
        logic        reg_write;
        logic        mem_to_reg;
        logic        valid;
    } mem_wb_reg_t;

endpackage

`endif