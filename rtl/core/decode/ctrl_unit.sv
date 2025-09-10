// Control Unit
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Map decoded instruction info (opcode/funct fields and compressed hint)
//   into datapath control signals: ALU op, operand source, memory size/type,
//   write-back selection, CSR operations, and system/trap flags.
//
// Important:
// - In a clean design, rs1/rs2/rd come from the decoder, not opcode bits.
//   This file notes that with comments; refactor recommended when integrating.
//
// Outputs overview:
// - reg_write/mem_read/mem_write/branch/jump/alu_src/alu_op
// - reg_write_src: 00 ALU, 01 MEM, 10 PC+4, 11 CSR
// - mem_size/mem_unsigned: load-store width and sign policy
// - CSR: csr_read/csr_write/csr_op, and system signals (ecall/ebreak/mret/sret)
// - Exceptions: illegal_instr when pattern unsupported
// - Branch metadata: is_call/is_return for predictor/RAS
// -----------------------------------------------------------------------------

module ctrl_unit (
    // Decoded instruction information
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    input  logic [4:0] rs2,     // Need rs2 for SYSTEM instructions
    input  logic       is_compressed,
    
    // Control outputs for datapath
    output logic       reg_write,
    output logic       mem_read,
    output logic       mem_write,
    output logic       branch,
    output logic       jump,
    output logic       alu_src,      // 0: reg, 1: imm
    output logic [1:0] reg_write_src, // 00: alu, 01: mem, 10: pc+4, 11: csr
    output logic [3:0] alu_op,
    output logic [2:0] mem_size,     // 000: byte, 001: half, 010: word, 011: double
    output logic       mem_unsigned,  // For load instructions
    
    // System control
    output logic       csr_read,
    output logic       csr_write,
    output logic [1:0] csr_op,       // 00: none, 01: write, 10: set, 11: clear
    output logic       ecall,
    output logic       ebreak,
    output logic       mret,
    output logic       sret,
    
    // Exception signals
    output logic       illegal_instr,
    
    // Branch type
    output logic       is_call,      // JAL/JALR with rd != x0
    output logic       is_return     // JALR with rs1=x1, rd=x0
);

    // ALU operation encoding
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b1000;
    localparam ALU_SLL  = 4'b0001;
    localparam ALU_SLT  = 4'b0010;
    localparam ALU_SLTU = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SRA  = 4'b1101;
    localparam ALU_OR   = 4'b0110;
    localparam ALU_AND  = 4'b0111;

    // Register addresses should be passed as inputs, not extracted from opcode
    // These are placeholders and will be properly connected in the pipeline

    // Main control logic
    always_comb begin
        // Default values
        reg_write = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        branch = 1'b0;
        jump = 1'b0;
        alu_src = 1'b0;
        reg_write_src = 2'b00;
        alu_op = ALU_ADD;
        mem_size = 3'b000;
        mem_unsigned = 1'b0;
        csr_read = 1'b0;
        csr_write = 1'b0;
        csr_op = 2'b00;
        ecall = 1'b0;
        ebreak = 1'b0;
        mret = 1'b0;
        sret = 1'b0;
        illegal_instr = 1'b0;
        is_call = 1'b0;
        is_return = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type (OP)
                reg_write = 1'b1;
                alu_src = 1'b0;
                reg_write_src = 2'b00;
                case (funct3)
                    3'b000: alu_op = funct7[5] ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                endcase
            end

            7'b0010011: begin // I-type (OP-IMM)
                reg_write = 1'b1;
                alu_src = 1'b1;
                reg_write_src = 2'b00;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    3'b001: alu_op = ALU_SLL;
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
                endcase
            end

            7'b0000011: begin // Load
                reg_write = 1'b1;
                mem_read = 1'b1;
                alu_src = 1'b1;
                alu_op = ALU_ADD;
                reg_write_src = 2'b01;
                case (funct3)
                    3'b000: begin mem_size = 3'b000; mem_unsigned = 1'b0; end // LB
                    3'b001: begin mem_size = 3'b001; mem_unsigned = 1'b0; end // LH
                    3'b010: begin mem_size = 3'b010; mem_unsigned = 1'b0; end // LW
                    3'b011: begin mem_size = 3'b011; mem_unsigned = 1'b0; end // LD
                    3'b100: begin mem_size = 3'b000; mem_unsigned = 1'b1; end // LBU
                    3'b101: begin mem_size = 3'b001; mem_unsigned = 1'b1; end // LHU
                    3'b110: begin mem_size = 3'b010; mem_unsigned = 1'b1; end // LWU
                endcase
            end

            7'b0100011: begin // Store
                mem_write = 1'b1;
                alu_src = 1'b1;
                alu_op = ALU_ADD;
                case (funct3)
                    3'b000: mem_size = 3'b000; // SB
                    3'b001: mem_size = 3'b001; // SH
                    3'b010: mem_size = 3'b010; // SW
                    3'b011: mem_size = 3'b011; // SD
                endcase
            end

            7'b1100011: begin // Branch
                branch = 1'b1;
                alu_src = 1'b0;
                case (funct3)
                    3'b000: alu_op = ALU_SUB; // BEQ (compare for equality)
                    3'b001: alu_op = ALU_SUB; // BNE
                    3'b100: alu_op = ALU_SLT; // BLT
                    3'b101: alu_op = ALU_SLT; // BGE
                    3'b110: alu_op = ALU_SLTU; // BLTU
                    3'b111: alu_op = ALU_SLTU; // BGEU
                endcase
            end

            7'b1101111: begin // JAL
                reg_write = 1'b1;
                jump = 1'b1;
                reg_write_src = 2'b10;
                is_call = 1'b1; // Will be determined by pipeline based on rd
            end

            7'b1100111: begin // JALR
                reg_write = 1'b1;
                jump = 1'b1;
                alu_src = 1'b1;
                alu_op = ALU_ADD;
                reg_write_src = 2'b10;
                is_call = 1'b1; // Will be determined by pipeline based on rd
                is_return = 1'b0; // Will be determined by pipeline based on rs1/rd
            end

            7'b0110111: begin // LUI
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = ALU_ADD; // Add immediate to 0
                reg_write_src = 2'b00;
            end

            7'b0010111: begin // AUIPC
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = ALU_ADD; // Add immediate to PC
                reg_write_src = 2'b00;
            end

            7'b1110011: begin // SYSTEM
                case (funct3)
                    3'b000: begin // ECALL, EBREAK, MRET, SRET
                        case ({rs2, funct7})
                            12'b000000000000: ecall = 1'b1;
                            12'b000000000001: ebreak = 1'b1;
                            12'b001100000010: mret = 1'b1;
                            12'b000100000010: sret = 1'b1;
                            default: illegal_instr = 1'b1;
                        endcase
                    end
                    3'b001: begin // CSRRW
                        reg_write = 1'b1;
                        csr_read = 1'b1;
                        csr_write = 1'b1;
                        csr_op = 2'b01;
                        reg_write_src = 2'b11;
                    end
                    3'b010: begin // CSRRS
                        reg_write = 1'b1;
                        csr_read = 1'b1;
                        csr_write = 1'b1; // Pipeline will check rs1 != 0
                        csr_op = 2'b10;
                        reg_write_src = 2'b11;
                    end
                    3'b011: begin // CSRRC
                        reg_write = 1'b1;
                        csr_read = 1'b1;
                        csr_write = 1'b1; // Pipeline will check rs1 != 0
                        csr_op = 2'b11;
                        reg_write_src = 2'b11;
                    end
                    3'b101: begin // CSRRWI
                        reg_write = 1'b1;
                        csr_read = 1'b1;
                        csr_write = 1'b1;
                        csr_op = 2'b01;
                        reg_write_src = 2'b11;
                    end
                    3'b110: begin // CSRRSI
                        reg_write = 1'b1;
                        csr_read = 1'b1;
                        csr_write = 1'b1; // Pipeline will check rs1 != 0
                        csr_op = 2'b10;
                        reg_write_src = 2'b11;
                    end
                    3'b111: begin // CSRRCI
                        reg_write = 1'b1;
                        csr_read = 1'b1;
                        csr_write = 1'b1; // Pipeline will check rs1 != 0
                        csr_op = 2'b11;
                        reg_write_src = 2'b11;
                    end
                endcase
            end

            default: illegal_instr = 1'b1;
        endcase
    end

endmodule
