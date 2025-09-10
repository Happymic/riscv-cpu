// Memory Access Stage (MEM)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Drive data memory requests for loads/stores using the computed address
//   from EX, capture read data, and pipeline results to WB.
//
// Interface/Protocol:
// - dmem_addr/wdata/we/be: simple request signals for a single-beat access.
// - dmem_valid: indicates the read data on dmem_rdata is valid.
// - For loads, valid_out is gated by dmem_valid to model memory latency.
// - For stores, this stage asserts dmem_we; write completion is modeled as
//   immediate in the basic testbench (no response channel).
//
// Simplifications:
// - dmem_be is hardwired to full 64-bit writes; subword granularity can be
//   added by decoding funct3 and address alignment.
// - No exception handling here; alignment/protection would be added with MMU.
// -----------------------------------------------------------------------------

module mem_stage #(
    parameter XLEN = 64
) (
    input  logic clk,
    input  logic rst_n,
    
    // Input from EX stage
    input  logic [XLEN-1:0] pc_in,
    input  logic [XLEN-1:0] alu_result_in,
    input  logic [XLEN-1:0] rs2_data_in,
    input  logic [4:0]      rd_addr_in,
    input  logic            reg_write_in,
    input  logic            mem_read_in,
    input  logic            mem_write_in,
    input  logic            valid_in,
    
    // Memory interface
    output logic [XLEN-1:0] dmem_addr,
    output logic [XLEN-1:0] dmem_wdata,
    input  logic [XLEN-1:0] dmem_rdata,
    output logic            dmem_we,
    output logic [7:0]      dmem_be,
    input  logic            dmem_valid,
    
    // Control signals
    input  logic stall,
    input  logic flush,
    
    // Output to WB stage
    output logic [XLEN-1:0] pc_out,
    output logic [XLEN-1:0] alu_result_out,
    output logic [XLEN-1:0] mem_data_out,
    output logic [4:0]      rd_addr_out,
    output logic            reg_write_out,
    output logic            mem_read_out,
    output logic            valid_out
);

    // Memory interface
    assign dmem_addr = alu_result_in;
    assign dmem_wdata = rs2_data_in;
    assign dmem_we = mem_write_in && valid_in;
    assign dmem_be = 8'hFF; // Byte enable (simplified - full word access)
    
    // Pipeline registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out <= '0;
            alu_result_out <= '0;
            mem_data_out <= '0;
            rd_addr_out <= '0;
            reg_write_out <= 1'b0;
            mem_read_out <= 1'b0;
            valid_out <= 1'b0;
        end else if (!stall) begin
            if (flush) begin
                pc_out <= '0;
                alu_result_out <= '0;
                mem_data_out <= '0;
                rd_addr_out <= '0;
                reg_write_out <= 1'b0;
                mem_read_out <= 1'b0;
                valid_out <= 1'b0;
            end else begin
                pc_out <= pc_in;
                alu_result_out <= alu_result_in;
                mem_data_out <= dmem_rdata;
                rd_addr_out <= rd_addr_in;
                reg_write_out <= reg_write_in;
                mem_read_out <= mem_read_in;
                valid_out <= valid_in && (!mem_read_in || dmem_valid);
            end
        end
    end

endmodule
