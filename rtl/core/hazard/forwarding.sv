// Forwarding Unit
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Determine, for EX stage source operands (rs1/rs2), whether a newer value
//   is available from later pipeline stages (MEM/WB) and should be forwarded
//   to avoid stalls.
//
// Interface:
// - Inputs are register indices from EX and destination/values from MEM/WB.
// - Outputs are:
//   - forward_*_sel: 00 no forward, 01 from MEM, 10 from WB.
//   - forward_data_*: the corresponding data buses to feed EX multiplexers.
//
// Notes:
// - This unit does not handle load-use one-cycle latency (that is handled by
//   hazard_unit via stall). It only resolves RAW hazards where data is ready.
// -----------------------------------------------------------------------------

module forwarding #(
    parameter XLEN = 64
) (
    // Register addresses from EX stage
    input  logic [4:0] ex_rs1,
    input  logic [4:0] ex_rs2,
    
    // MEM stage forwarding
    input  logic [4:0]      mem_rd,
    input  logic [XLEN-1:0] mem_alu_result,
    input  logic            mem_reg_write,
    
    // WB stage forwarding
    input  logic [4:0]      wb_rd,
    input  logic [XLEN-1:0] wb_data,
    input  logic            wb_reg_write,
    
    // Forwarding control outputs
    output logic [1:0]      forward_a_sel,
    output logic [1:0]      forward_b_sel,
    
    // Forwarded data outputs
    output logic [XLEN-1:0] forward_data_a,
    output logic [XLEN-1:0] forward_data_b
);

    // Forwarding selection for operand A
    always_comb begin
        if (mem_reg_write && (mem_rd != 5'b00000) && (mem_rd == ex_rs1)) begin
            forward_a_sel = 2'b01; // Forward from MEM stage
            forward_data_a = mem_alu_result;
        end else if (wb_reg_write && (wb_rd != 5'b00000) && (wb_rd == ex_rs1)) begin
            forward_a_sel = 2'b10; // Forward from WB stage
            forward_data_a = wb_data;
        end else begin
            forward_a_sel = 2'b00; // No forwarding
            forward_data_a = '0;
        end
    end

    // Forwarding selection for operand B
    always_comb begin
        if (mem_reg_write && (mem_rd != 5'b00000) && (mem_rd == ex_rs2)) begin
            forward_b_sel = 2'b01; // Forward from MEM stage
            forward_data_b = mem_alu_result;
        end else if (wb_reg_write && (wb_rd != 5'b00000) && (wb_rd == ex_rs2)) begin
            forward_b_sel = 2'b10; // Forward from WB stage
            forward_data_b = wb_data;
        end else begin
            forward_b_sel = 2'b00; // No forwarding
            forward_data_b = '0;
        end
    end

endmodule
