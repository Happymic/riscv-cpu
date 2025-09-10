// Write Back Stage (WB)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Select the final result to write into the register file (load data vs ALU
//   result), enforce x0 = 0 rule, and provide forwarding data to younger
//   pipeline stages.
//
// Behavior:
// - rd_we is only asserted when instruction intends to write and is valid,
//   and rd != x0.
// - wb_* outputs mirror the chosen write-back value for hazard forwarding.
// -----------------------------------------------------------------------------

module wb_stage #(
    parameter XLEN = 64
) (
    input  logic clk,
    input  logic rst_n,
    
    // Input from MEM stage
    input  logic [XLEN-1:0] pc_in,
    input  logic [XLEN-1:0] alu_result_in,
    input  logic [XLEN-1:0] mem_data_in,
    input  logic [4:0]      rd_addr_in,
    input  logic            reg_write_in,
    input  logic            mem_read_in,
    input  logic            valid_in,
    
    // Register file write interface
    output logic [4:0]      rd_addr,
    output logic [XLEN-1:0] rd_data,
    output logic            rd_we,
    
    // Forwarding output
    output logic [XLEN-1:0] wb_data,
    output logic [4:0]      wb_rd_addr,
    output logic            wb_reg_write
);

    // Write-back data selection
    logic [XLEN-1:0] wb_result;
    assign wb_result = mem_read_in ? mem_data_in : alu_result_in;
    
    // Register file write
    assign rd_addr = rd_addr_in;
    assign rd_data = wb_result;
    assign rd_we = reg_write_in && valid_in && (rd_addr_in != 5'b00000); // Don't write to x0
    
    // Forwarding outputs
    assign wb_data = wb_result;
    assign wb_rd_addr = rd_addr_in;
    assign wb_reg_write = reg_write_in && valid_in;

endmodule
