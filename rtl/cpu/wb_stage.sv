//////////////////////////////////////////////////////////////////////////////////
// Module: wb_stage
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Write Back (WB) stage of the 5-stage pipeline
//              Writes results back to the register file
//              Selects between ALU result and memory data
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

import cpu_types::*;

module wb_stage (
    input  logic        clk,
    input  logic        rst_n,
    input  mem_wb_reg_t mem_wb_reg,         // MEM/WB pipeline register
    
    // Register file write interface
    output logic        rf_we,              // Register file write enable
    output logic [4:0]  rf_wa,              // Register file write address
    output logic [31:0] rf_wd               // Register file write data
);

    //////////////////////////////////////////////////////////////////////////////////
    // Write Back Data Selection
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Default values
        rf_we = 1'b0;
        rf_wa = 5'h0;
        rf_wd = 32'h0;
        
        if (mem_wb_reg.valid && mem_wb_reg.reg_write) begin
            rf_we = 1'b1;
            rf_wa = mem_wb_reg.rd_addr;
            
            // Select between ALU result and memory data
            if (mem_wb_reg.mem_to_reg) begin
                // Load instruction - use memory data
                rf_wd = mem_wb_reg.mem_data;
            end else begin
                // ALU or jump instruction - use ALU result
                rf_wd = mem_wb_reg.alu_result;
            end
        end
    end
    
    // Debug: Never write to x0 (hardwired to zero in RISC-V)
    always_comb begin
        if (rf_wa == 5'h0) begin
            rf_we = 1'b0;  // Disable write to x0
        end
    end
    
endmodule