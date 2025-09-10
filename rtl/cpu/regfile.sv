//////////////////////////////////////////////////////////////////////////////////
// Module: regfile
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: 32x32-bit Register File for RISC-V RV32I
//              Implements 32 general-purpose registers with x0 hardwired to zero
//              Supports 2 read ports and 1 write port
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module regfile (
    input  logic        clk,
    input  logic        rst_n,
    
    // Read port 1
    input  logic [4:0]  rs1_addr,           // Read address 1
    output logic [31:0] rs1_data,           // Read data 1
    
    // Read port 2
    input  logic [4:0]  rs2_addr,           // Read address 2
    output logic [31:0] rs2_data,           // Read data 2
    
    // Write port
    input  logic        we,                 // Write enable
    input  logic [4:0]  wa,                 // Write address
    input  logic [31:0] wd                  // Write data
);

    // Register array: 32 registers of 32 bits each
    logic [31:0] registers [0:31];
    
    // Integer for initialization loop
    integer i;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Register Write Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers to 0
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'h0;
            end
        end else if (we && (wa != 5'h0)) begin
            // Write to register (except x0)
            registers[wa] <= wd;
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Register Read Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    // Read port 1
    always_comb begin
        if (rs1_addr == 5'h0) begin
            rs1_data = 32'h0;  // x0 is hardwired to zero
        end else begin
            rs1_data = registers[rs1_addr];
        end
    end
    
    // Read port 2
    always_comb begin
        if (rs2_addr == 5'h0) begin
            rs2_data = 32'h0;  // x0 is hardwired to zero
        end else begin
            rs2_data = registers[rs2_addr];
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Debug: Register content display (simulation only)
    //////////////////////////////////////////////////////////////////////////////////
    
    `ifdef SIMULATION
    always @(posedge clk) begin
        if (we && (wa != 5'h0)) begin
            $display("Time %t: Register x%0d written with value 0x%08x", $time, wa, wd);
        end
    end
    `endif
    
endmodule