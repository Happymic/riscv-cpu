//////////////////////////////////////////////////////////////////////////////////
// Module: mem_stage
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Memory (MEM) stage of the 5-stage pipeline
//              Handles data cache access for loads and stores
//              Supports byte, halfword, and word operations
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

import cpu_types::*;

module mem_stage (
    input  logic        clk,
    input  logic        rst_n,
    input  ex_mem_reg_t ex_mem_reg,         // EX/MEM pipeline register
    
    // Data cache interface
    output logic        dcache_req,         // Cache request
    output logic        dcache_we,          // Cache write enable
    output logic [31:0] dcache_addr,        // Cache address
    output logic [31:0] dcache_wdata,       // Cache write data
    output logic [3:0]  dcache_be,          // Byte enable for writes
    input  logic [31:0] dcache_rdata,       // Cache read data
    input  logic        dcache_stall,       // Cache stall signal
    
    // To MEM/WB register
    output mem_wb_reg_t mem_wb_next         // Next MEM/WB register values
);

    // Internal signals
    logic [31:0] mem_rdata_aligned;         // Aligned read data
    logic [31:0] store_data_aligned;        // Aligned store data
    logic [1:0]  byte_offset;               // Byte offset within word
    
    // Extract byte offset from address
    assign byte_offset = ex_mem_reg.alu_result[1:0];
    
    //////////////////////////////////////////////////////////////////////////////////
    // Memory Request Generation
    //////////////////////////////////////////////////////////////////////////////////
    
    // Generate cache request signals
    assign dcache_req = ex_mem_reg.valid && (ex_mem_reg.mem_read || ex_mem_reg.mem_write);
    assign dcache_we = ex_mem_reg.mem_write;
    assign dcache_addr = {ex_mem_reg.alu_result[31:2], 2'b00};  // Word-aligned address
    
    //////////////////////////////////////////////////////////////////////////////////
    // Store Data Alignment and Byte Enable Generation
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Default values
        store_data_aligned = ex_mem_reg.rs2_data;
        dcache_be = 4'b1111;  // Default: word access
        
        if (ex_mem_reg.mem_write) begin
            case (ex_mem_reg.funct3)
                // SB (Store Byte)
                3'b000: begin
                    case (byte_offset)
                        2'b00: begin
                            store_data_aligned = {24'h0, ex_mem_reg.rs2_data[7:0]};
                            dcache_be = 4'b0001;
                        end
                        2'b01: begin
                            store_data_aligned = {16'h0, ex_mem_reg.rs2_data[7:0], 8'h0};
                            dcache_be = 4'b0010;
                        end
                        2'b10: begin
                            store_data_aligned = {8'h0, ex_mem_reg.rs2_data[7:0], 16'h0};
                            dcache_be = 4'b0100;
                        end
                        2'b11: begin
                            store_data_aligned = {ex_mem_reg.rs2_data[7:0], 24'h0};
                            dcache_be = 4'b1000;
                        end
                    endcase
                end
                
                // SH (Store Halfword)
                3'b001: begin
                    case (byte_offset[1])
                        1'b0: begin
                            store_data_aligned = {16'h0, ex_mem_reg.rs2_data[15:0]};
                            dcache_be = 4'b0011;
                        end
                        1'b1: begin
                            store_data_aligned = {ex_mem_reg.rs2_data[15:0], 16'h0};
                            dcache_be = 4'b1100;
                        end
                    endcase
                end
                
                // SW (Store Word)
                3'b010: begin
                    store_data_aligned = ex_mem_reg.rs2_data;
                    dcache_be = 4'b1111;
                end
                
                default: begin
                    store_data_aligned = ex_mem_reg.rs2_data;
                    dcache_be = 4'b1111;
                end
            endcase
        end
    end
    
    assign dcache_wdata = store_data_aligned;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Load Data Alignment and Sign Extension
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Default: pass through word data
        mem_rdata_aligned = dcache_rdata;
        
        if (ex_mem_reg.mem_read) begin
            case (ex_mem_reg.funct3)
                // LB (Load Byte - sign extended)
                3'b000: begin
                    case (byte_offset)
                        2'b00: mem_rdata_aligned = {{24{dcache_rdata[7]}}, dcache_rdata[7:0]};
                        2'b01: mem_rdata_aligned = {{24{dcache_rdata[15]}}, dcache_rdata[15:8]};
                        2'b10: mem_rdata_aligned = {{24{dcache_rdata[23]}}, dcache_rdata[23:16]};
                        2'b11: mem_rdata_aligned = {{24{dcache_rdata[31]}}, dcache_rdata[31:24]};
                    endcase
                end
                
                // LH (Load Halfword - sign extended)
                3'b001: begin
                    case (byte_offset[1])
                        1'b0: mem_rdata_aligned = {{16{dcache_rdata[15]}}, dcache_rdata[15:0]};
                        1'b1: mem_rdata_aligned = {{16{dcache_rdata[31]}}, dcache_rdata[31:16]};
                    endcase
                end
                
                // LW (Load Word)
                3'b010: begin
                    mem_rdata_aligned = dcache_rdata;
                end
                
                // LBU (Load Byte Unsigned)
                3'b100: begin
                    case (byte_offset)
                        2'b00: mem_rdata_aligned = {24'h0, dcache_rdata[7:0]};
                        2'b01: mem_rdata_aligned = {24'h0, dcache_rdata[15:8]};
                        2'b10: mem_rdata_aligned = {24'h0, dcache_rdata[23:16]};
                        2'b11: mem_rdata_aligned = {24'h0, dcache_rdata[31:24]};
                    endcase
                end
                
                // LHU (Load Halfword Unsigned)
                3'b101: begin
                    case (byte_offset[1])
                        1'b0: mem_rdata_aligned = {16'h0, dcache_rdata[15:0]};
                        1'b1: mem_rdata_aligned = {16'h0, dcache_rdata[31:16]};
                    endcase
                end
                
                default: begin
                    mem_rdata_aligned = dcache_rdata;
                end
            endcase
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // MEM/WB Register Preparation
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        mem_wb_next = '0;  // Default values
        
        if (ex_mem_reg.valid && !dcache_stall) begin
            mem_wb_next.pc = ex_mem_reg.pc;
            mem_wb_next.alu_result = ex_mem_reg.alu_result;
            mem_wb_next.mem_data = mem_rdata_aligned;
            mem_wb_next.rd_addr = ex_mem_reg.rd_addr;
            mem_wb_next.reg_write = ex_mem_reg.reg_write;
            mem_wb_next.mem_to_reg = ex_mem_reg.mem_read;  // Select memory data if load
            mem_wb_next.valid = 1'b1;
        end else if (ex_mem_reg.valid && dcache_stall) begin
            // Stall - preserve current state
            mem_wb_next = mem_wb_next;  // Will be updated by pipeline register
        end
    end
    
endmodule