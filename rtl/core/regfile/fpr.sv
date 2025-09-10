// Floating Point Register File (FPR)
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Implements 32 floating-point registers (f0..f31) of FLEN width.
// - Provides two read ports + one extra rs3 port for fused ops, and one write port.
//
// Behavior:
// - No special x0 semantics (FP registers are not hardwired). Reset clears to 0.
// - Timing same as GPR: comb reads, synchronous write.
// -----------------------------------------------------------------------------

module fpr #(
    parameter FLEN = 64,
    parameter REG_NUM = 32
) (
    input  logic clk,
    input  logic rst_n,
    
    // Read ports
    input  logic [4:0]      rs1_addr,
    input  logic [4:0]      rs2_addr,
    input  logic [4:0]      rs3_addr,
    output logic [FLEN-1:0] rs1_data,
    output logic [FLEN-1:0] rs2_data,
    output logic [FLEN-1:0] rs3_data,
    
    // Write port
    input  logic [4:0]      rd_addr,
    input  logic [FLEN-1:0] rd_data,
    input  logic            rd_we
);

    // Floating-point register file storage
    logic [FLEN-1:0] fp_registers [REG_NUM-1:0];

    // Read logic (combinational)
    assign rs1_data = fp_registers[rs1_addr];
    assign rs2_data = fp_registers[rs2_addr];
    assign rs3_data = fp_registers[rs3_addr];

    // Write logic (sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < REG_NUM; i++) begin
                fp_registers[i] <= '0;
            end
        end else if (rd_we) begin
            fp_registers[rd_addr] <= rd_data;
        end
    end

endmodule
