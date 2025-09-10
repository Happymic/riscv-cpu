// RISC-V Instruction Decoder
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Extract canonical instruction fields, sign-extend immediates for all types
//   (I/S/B/U/J), and classify instruction categories for control generation.
//
// Outputs:
// - opcode/rd/rs1/rs2/funct3/funct7: directly sliced from the ILEN=32 word.
// - imm_*: sign-extended immediates to XLEN width.
// - type/category flags and utility control hints (uses_rs1/uses_rs2/writes_rd).
// - is_compressed: true when lower bits != 2'b11 (indicates 16-bit encoding).
//
// Notes:
// - This module is combinational and side-effect free; intended to be used by
//   a control unit and the ID stage pipeline register.
// -----------------------------------------------------------------------------

module decoder #(
    parameter XLEN = 64,
    parameter ILEN = 32
) (
    // Input instruction
    input  logic [ILEN-1:0] instruction,
    
    // Decoded instruction fields
    output logic [6:0]      opcode,
    output logic [4:0]      rd,
    output logic [2:0]      funct3,
    output logic [4:0]      rs1,
    output logic [4:0]      rs2,
    output logic [6:0]      funct7,
    
    // Immediate values
    output logic [XLEN-1:0] imm_i,
    output logic [XLEN-1:0] imm_s,
    output logic [XLEN-1:0] imm_b,
    output logic [XLEN-1:0] imm_u,
    output logic [XLEN-1:0] imm_j,
    
    // Instruction type identification
    output logic is_r_type,
    output logic is_i_type,
    output logic is_s_type,
    output logic is_b_type,
    output logic is_u_type,
    output logic is_j_type,
    
    // Instruction categories
    output logic is_load,
    output logic is_store,
    output logic is_branch,
    output logic is_jal,
    output logic is_jalr,
    output logic is_auipc,
    output logic is_lui,
    output logic is_alu_reg,
    output logic is_alu_imm,
    output logic is_system,
    output logic is_fence,
    
    // Control signals
    output logic uses_rs1,
    output logic uses_rs2,
    output logic writes_rd,
    output logic is_compressed
);

    // Extract instruction fields
    assign opcode = instruction[6:0];
    assign rd = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign funct7 = instruction[31:25];

    // Immediate extraction with sign extension
    assign imm_i = {{(XLEN-12){instruction[31]}}, instruction[31:20]};
    assign imm_s = {{(XLEN-12){instruction[31]}}, instruction[31:25], instruction[11:7]};
    assign imm_b = {{(XLEN-13){instruction[31]}}, instruction[31], instruction[7], 
                    instruction[30:25], instruction[11:8], 1'b0};
    assign imm_u = {{(XLEN-32){instruction[31]}}, instruction[31:12], 12'b0};
    assign imm_j = {{(XLEN-21){instruction[31]}}, instruction[31], instruction[19:12], 
                    instruction[20], instruction[30:21], 1'b0};

    // Instruction type decode
    assign is_r_type = (opcode == 7'b0110011) || (opcode == 7'b0111011); // OP, OP-32
    assign is_i_type = (opcode == 7'b0010011) || (opcode == 7'b0011011) || // OP-IMM, OP-IMM-32
                       (opcode == 7'b0000011) || (opcode == 7'b1100111) || // LOAD, JALR
                       (opcode == 7'b1110011); // SYSTEM
    assign is_s_type = (opcode == 7'b0100011); // STORE
    assign is_b_type = (opcode == 7'b1100011); // BRANCH
    assign is_u_type = (opcode == 7'b0110111) || (opcode == 7'b0010111); // LUI, AUIPC
    assign is_j_type = (opcode == 7'b1101111); // JAL

    // Instruction categories
    assign is_load = (opcode == 7'b0000011);
    assign is_store = (opcode == 7'b0100011);
    assign is_branch = (opcode == 7'b1100011);
    assign is_jal = (opcode == 7'b1101111);
    assign is_jalr = (opcode == 7'b1100111);
    assign is_auipc = (opcode == 7'b0010111);
    assign is_lui = (opcode == 7'b0110111);
    assign is_alu_reg = (opcode == 7'b0110011) || (opcode == 7'b0111011);
    assign is_alu_imm = (opcode == 7'b0010011) || (opcode == 7'b0011011);
    assign is_system = (opcode == 7'b1110011);
    assign is_fence = (opcode == 7'b0001111);

    // Register usage
    assign uses_rs1 = is_r_type || is_i_type || is_s_type || is_b_type;
    assign uses_rs2 = is_r_type || is_s_type || is_b_type;
    assign writes_rd = is_r_type || is_i_type || is_u_type || is_j_type || 
                      (is_system && (funct3 != 3'b000)); // Not for ECALL/EBREAK

    // Compressed instruction detection (bits [1:0] != 2'b11)
    assign is_compressed = (instruction[1:0] != 2'b11);

endmodule
