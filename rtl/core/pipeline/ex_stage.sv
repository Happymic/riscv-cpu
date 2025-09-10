// Execute Stage (EX)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Perform ALU operations, apply data forwarding for source operands, and
//   pass results together with store data and control flags to the MEM stage.
//
// Forwarding model:
// - forward_sel_a/b encodes source selection:
//   00 = use local rs*_in, 01 = value from MEM, 10 = value from WB.
// - forward_data_a/b carry the corresponding forwarded values.
//
// Immediate vs register operand:
// - alu_op_in[3] acts as an immediate-select bit in this simplified encoding.
//   When set, operand B uses imm_in; otherwise it uses (possibly forwarded) rs2.
//
// Flush/Stall:
// - On stall, hold pipeline regs; on flush, clear outputs to inject a bubble.
// -----------------------------------------------------------------------------

module ex_stage #(
    parameter XLEN = 64
) (
    input  logic clk,
    input  logic rst_n,
    
    // Input from ID stage
    input  logic [XLEN-1:0] pc_in,
    input  logic [XLEN-1:0] rs1_in,
    input  logic [XLEN-1:0] rs2_in,
    input  logic [XLEN-1:0] imm_in,
    input  logic [4:0]      rd_addr_in,
    input  logic            reg_write_in,
    input  logic            mem_read_in,
    input  logic            mem_write_in,
    input  logic [3:0]      alu_op_in,
    input  logic            valid_in,
    
    // Control signals
    input  logic stall,
    input  logic flush,
    
    // Forwarding inputs
    input  logic [XLEN-1:0] forward_data_a,
    input  logic [XLEN-1:0] forward_data_b,
    input  logic [1:0]      forward_sel_a,
    input  logic [1:0]      forward_sel_b,
    
    // Output to MEM stage
    output logic [XLEN-1:0] pc_out,
    output logic [XLEN-1:0] alu_result_out,
    output logic [XLEN-1:0] rs2_data_out,
    output logic [4:0]      rd_addr_out,
    output logic            reg_write_out,
    output logic            mem_read_out,
    output logic            mem_write_out,
    output logic            valid_out
);

    logic [XLEN-1:0] alu_a, alu_b;
    logic [XLEN-1:0] alu_result;
    
    // Forwarding multiplexers
    always_comb begin
        case (forward_sel_a)
            2'b00: alu_a = rs1_in;
            2'b01: alu_a = forward_data_a; // From MEM stage
            2'b10: alu_a = forward_data_b; // From WB stage
            default: alu_a = rs1_in;
        endcase
        
        case (forward_sel_b)
            2'b00: alu_b = rs2_in;
            2'b01: alu_b = forward_data_a; // From MEM stage
            2'b10: alu_b = forward_data_b; // From WB stage
            default: alu_b = rs2_in;
        endcase
    end
    
    // ALU operation selection
    logic [XLEN-1:0] alu_operand_b;
    assign alu_operand_b = (alu_op_in[3]) ? imm_in : alu_b; // Use immediate for I-type
    
    // ALU implementation
    always_comb begin
        case (alu_op_in[2:0])
            3'b000: begin // ADD/SUB
                if (alu_op_in[3] && alu_op_in[2]) // SUB (R-type only)
                    alu_result = alu_a - alu_operand_b;
                else // ADD
                    alu_result = alu_a + alu_operand_b;
            end
            3'b001: alu_result = alu_a << alu_operand_b[5:0]; // SLL
            3'b010: alu_result = ($signed(alu_a) < $signed(alu_operand_b)) ? 1 : 0; // SLT
            3'b011: alu_result = (alu_a < alu_operand_b) ? 1 : 0; // SLTU
            3'b100: alu_result = alu_a ^ alu_operand_b; // XOR
            3'b101: begin // SRL/SRA
                if (alu_op_in[3])
                    alu_result = $signed(alu_a) >>> alu_operand_b[5:0]; // SRA
                else
                    alu_result = alu_a >> alu_operand_b[5:0]; // SRL
            end
            3'b110: alu_result = alu_a | alu_operand_b; // OR
            3'b111: alu_result = alu_a & alu_operand_b; // AND
        endcase
    end
    
    // Pipeline registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out <= '0;
            alu_result_out <= '0;
            rs2_data_out <= '0;
            rd_addr_out <= '0;
            reg_write_out <= 1'b0;
            mem_read_out <= 1'b0;
            mem_write_out <= 1'b0;
            valid_out <= 1'b0;
        end else if (!stall) begin
            if (flush) begin
                pc_out <= '0;
                alu_result_out <= '0;
                rs2_data_out <= '0;
                rd_addr_out <= '0;
                reg_write_out <= 1'b0;
                mem_read_out <= 1'b0;
                mem_write_out <= 1'b0;
                valid_out <= 1'b0;
            end else begin
                pc_out <= pc_in;
                alu_result_out <= alu_result;
                rs2_data_out <= alu_b; // Store data for memory write
                rd_addr_out <= rd_addr_in;
                reg_write_out <= reg_write_in;
                mem_read_out <= mem_read_in;
                mem_write_out <= mem_write_in;
                valid_out <= valid_in;
            end
        end
    end

endmodule
