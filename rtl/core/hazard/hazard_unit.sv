// Hazard Detection Unit
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Detect data and control hazards and generate pipeline control signals to
//   stall or flush stages accordingly. Also computes simple forwarding selects
//   for EX operand multiplexers.
//
// Supported hazards:
// - Load-use hazard: if EX is a load and ID consumes EX.rd as rs1/rs2, stall
//   IF and ID for one cycle to let data become available for forwarding.
// - Control hazard: when a branch is taken/mispredicted, flush ID and EX.
//
// Outputs:
// - stall_if/stall_id: hold respective stages.
// - flush_id/flush_ex: inject bubbles to squash wrong-path instructions.
// - forward_a/forward_b: 2-bit select (00: none, 01: from MEM, 10: from WB).
// -----------------------------------------------------------------------------

module hazard_unit (
    // Pipeline stage inputs
    input  logic [4:0] if_rs1,
    input  logic [4:0] if_rs2,
    input  logic [4:0] id_rs1,
    input  logic [4:0] id_rs2,
    input  logic [4:0] ex_rd,
    input  logic [4:0] mem_rd,
    input  logic [4:0] wb_rd,
    
    // Control signals
    input  logic ex_mem_read,
    input  logic ex_reg_write,
    input  logic mem_reg_write,
    input  logic wb_reg_write,
    input  logic branch_taken,
    
    // Hazard control outputs
    output logic stall_if,
    output logic stall_id,
    output logic flush_id,
    output logic flush_ex,
    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);

    // Load-use hazard detection
    logic load_use_hazard;
    assign load_use_hazard = ex_mem_read && 
                            ((ex_rd == id_rs1 && id_rs1 != 5'b00000) ||
                             (ex_rd == id_rs2 && id_rs2 != 5'b00000));

    // Control hazard (branch misprediction)
    assign flush_id = branch_taken;
    assign flush_ex = branch_taken;

    // Stall logic
    assign stall_if = load_use_hazard;
    assign stall_id = load_use_hazard;

    // Forwarding logic for ALU operand A
    always_comb begin
        if (mem_reg_write && (mem_rd != 5'b00000) && (mem_rd == id_rs1))
            forward_a = 2'b01; // Forward from MEM stage
        else if (wb_reg_write && (wb_rd != 5'b00000) && (wb_rd == id_rs1))
            forward_a = 2'b10; // Forward from WB stage
        else
            forward_a = 2'b00; // No forwarding
    end

    // Forwarding logic for ALU operand B
    always_comb begin
        if (mem_reg_write && (mem_rd != 5'b00000) && (mem_rd == id_rs2))
            forward_b = 2'b01; // Forward from MEM stage
        else if (wb_reg_write && (wb_rd != 5'b00000) && (wb_rd == id_rs2))
            forward_b = 2'b10; // Forward from WB stage
        else
            forward_b = 2'b00; // No forwarding
    end

endmodule
