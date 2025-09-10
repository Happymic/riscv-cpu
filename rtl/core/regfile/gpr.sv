// General Purpose Register File (GPR)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Implements 32 architectural integer registers (x0..x31) of XLEN width.
// - Provides two combinational read ports and one synchronous write port.
//
// Behavior:
// - Reads are x0-aware: reading x0 returns 0 regardless of stored value.
// - Writes ignore x0: write enable to rd==0 is discarded to preserve zero.
// - Reset clears all registers to 0 for deterministic simulation.
//
// Timing:
// - Read data is available combinationally from the address inputs.
// - Write occurs on the rising edge when rd_we is high.
// -----------------------------------------------------------------------------

module gpr #(
    parameter XLEN = 64,
    parameter REG_NUM = 32
) (
    input  logic clk,
    input  logic rst_n,
    
    // Read ports
    input  logic [4:0]      rs1_addr,
    input  logic [4:0]      rs2_addr,
    output logic [XLEN-1:0] rs1_data,
    output logic [XLEN-1:0] rs2_data,
    
    // Write port
    input  logic [4:0]      rd_addr,
    input  logic [XLEN-1:0] rd_data,
    input  logic            rd_we
);

    // Register file storage
    logic [XLEN-1:0] registers [REG_NUM-1:0];

    // Read logic (combinational)
    assign rs1_data = (rs1_addr == 5'b00000) ? '0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'b00000) ? '0 : registers[rs2_addr];

    // Write logic (sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < REG_NUM; i++) begin
                registers[i] <= '0;
            end
        end else if (rd_we && (rd_addr != 5'b00000)) begin
            registers[rd_addr] <= rd_data;
        end
    end

    // x0 is always zero (hardwired)
    // This is enforced by the read logic above

endmodule
