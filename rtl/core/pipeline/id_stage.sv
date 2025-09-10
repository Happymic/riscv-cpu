// Instruction Decode Stage (ID)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Parse instruction fields, generate immediates for all RISC-V formats,
//   determine basic control signals for ALU and memory, and read operand data
//   from the general-purpose register file.
//
// Interface summary:
// - From IF:
//   - pc_in/instr_in/valid_in: instruction context and validity.
// - Register file:
//   - rs1_addr/rs2_addr (out): register indices to read.
//   - rs1_data/rs2_data (in): read data values.
// - Control in:
//   - stall: hold pipeline registers when 1.
//   - flush: convert outputs to bubble when 1.
// - To EX:
//   - rs1_out/rs2_out/imm_out: decoded operands and immediate.
//   - rd_addr_out: destination register index.
//   - reg_write_out/mem_read_out/mem_write_out/alu_op_out: control signals.
//   - pc_out/valid_out: forwarded context and validity.
//
// Notes:
// - Control generation is simplified: only a subset of opcodes is recognized.
// - Sign extension width is parameterized by XLEN.
// - On flush, all outputs are cleared to inject bubble safely.
// -----------------------------------------------------------------------------

module id_stage #(
    parameter XLEN = 64,
    parameter ILEN = 32
) (
    input  logic clk,
    input  logic rst_n,
    
    // Input from IF stage
    input  logic [XLEN-1:0] pc_in,
    input  logic [ILEN-1:0] instr_in,
    input  logic            valid_in,
    
    // Register file interface
    output logic [4:0]      rs1_addr,
    output logic [4:0]      rs2_addr,
    input  logic [XLEN-1:0] rs1_data,
    input  logic [XLEN-1:0] rs2_data,
    
    // Control signals
    input  logic stall,
    input  logic flush,
    
    // Output to EX stage
    output logic [XLEN-1:0] pc_out,
    output logic [XLEN-1:0] rs1_out,
    output logic [XLEN-1:0] rs2_out,
    output logic [XLEN-1:0] imm_out,
    output logic [4:0]      rd_addr_out,
    output logic            reg_write_out,
    output logic            mem_read_out,
    output logic            mem_write_out,
    output logic [3:0]      alu_op_out,
    output logic            valid_out
);

    // Instruction fields
    logic [6:0]  opcode;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [11:0] imm_i;
    logic [11:0] imm_s;
    logic [12:0] imm_b;
    logic [19:0] imm_u;
    logic [20:0] imm_j;
    
    // Decode instruction fields
    assign opcode = instr_in[6:0];
    assign rd = instr_in[11:7];
    assign rs1 = instr_in[19:15];
    assign rs2 = instr_in[24:20];
    assign funct3 = instr_in[14:12];
    assign funct7 = instr_in[31:25];
    assign imm_i = instr_in[31:20];
    assign imm_s = {instr_in[31:25], instr_in[11:7]};
    assign imm_b = {instr_in[31], instr_in[7], instr_in[30:25], instr_in[11:8], 1'b0};
    assign imm_u = instr_in[31:12];
    assign imm_j = {instr_in[31], instr_in[19:12], instr_in[20], instr_in[30:21], 1'b0};
    
    // Register addresses
    assign rs1_addr = rs1;
    assign rs2_addr = rs2;
    
    // Control signal generation (simplified)
    logic [XLEN-1:0] immediate;
    logic reg_write, mem_read, mem_write;
    logic [3:0] alu_op;
    
    // Immediate selection
    always_comb begin
        case (opcode)
            7'b0010011, 7'b0000011, 7'b1100111: // I-type
                immediate = {{(XLEN-12){imm_i[11]}}, imm_i};
            7'b0100011: // S-type
                immediate = {{(XLEN-12){imm_s[11]}}, imm_s};
            7'b1100011: // B-type
                immediate = {{(XLEN-13){imm_b[12]}}, imm_b};
            7'b0110111, 7'b0010111: // U-type
                immediate = {{(XLEN-32){imm_u[19]}}, imm_u, 12'b0};
            7'b1101111: // J-type
                immediate = {{(XLEN-21){imm_j[20]}}, imm_j};
            default:
                immediate = '0;
        endcase
    end
    
    // Control signal generation
    always_comb begin
        reg_write = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        alu_op = 4'b0000;
        
        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1'b1;
                alu_op = {funct7[5], funct3};
            end
            7'b0010011: begin // I-type (ALU)
                reg_write = 1'b1;
                alu_op = {1'b0, funct3};
            end
            7'b0000011: begin // Load
                reg_write = 1'b1;
                mem_read = 1'b1;
                alu_op = 4'b0000; // ADD
            end
            7'b0100011: begin // Store
                mem_write = 1'b1;
                alu_op = 4'b0000; // ADD
            end
            default: begin
                reg_write = 1'b0;
                mem_read = 1'b0;
                mem_write = 1'b0;
                alu_op = 4'b0000;
            end
        endcase
    end
    
    // Pipeline registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out <= '0;
            rs1_out <= '0;
            rs2_out <= '0;
            imm_out <= '0;
            rd_addr_out <= '0;
            reg_write_out <= 1'b0;
            mem_read_out <= 1'b0;
            mem_write_out <= 1'b0;
            alu_op_out <= 4'b0000;
            valid_out <= 1'b0;
        end else if (!stall) begin
            if (flush) begin
                pc_out <= '0;
                rs1_out <= '0;
                rs2_out <= '0;
                imm_out <= '0;
                rd_addr_out <= '0;
                reg_write_out <= 1'b0;
                mem_read_out <= 1'b0;
                mem_write_out <= 1'b0;
                alu_op_out <= 4'b0000;
                valid_out <= 1'b0;
            end else begin
                pc_out <= pc_in;
                rs1_out <= rs1_data;
                rs2_out <= rs2_data;
                imm_out <= immediate;
                rd_addr_out <= rd;
                reg_write_out <= reg_write;
                mem_read_out <= mem_read;
                mem_write_out <= mem_write;
                alu_op_out <= alu_op;
                valid_out <= valid_in;
            end
        end
    end

endmodule
