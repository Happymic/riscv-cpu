//////////////////////////////////////////////////////////////////////////////////
// Module: if_stage
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Instruction Fetch (IF) stage of the 5-stage pipeline
//              Handles PC management, instruction fetching from I-cache,
//              and branch prediction
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

import cpu_types::*;

module if_stage (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        stall,              // Pipeline stall signal
    input  logic        flush,              // Pipeline flush signal
    input  logic        branch_taken,       // Branch taken from EX stage
    input  logic [31:0] branch_target,      // Branch target address
    
    // PC management
    output logic [31:0] pc_current,         // Current PC
    output logic [31:0] pc_next,            // Next PC
    
    // I-cache interface
    output logic        icache_req,         // Cache request
    input  logic [31:0] icache_data,        // Instruction from cache
    input  logic        icache_stall,       // Cache stall signal
    
    // To IF/ID register
    output if_id_reg_t  if_id_next          // Next IF/ID register values
);

    // Internal signals
    logic [31:0] pc_plus_4;
    logic [31:0] pc_selected;
    logic        btb_hit;
    logic [31:0] btb_target;
    logic        instruction_valid;
    
    // PC register
    logic [31:0] pc_reg;
    
    // Branch Target Buffer (BTB) for branch prediction
    branch_predictor u_branch_predictor (
        .clk            (clk),
        .rst_n          (rst_n),
        .pc             (pc_reg),
        .btb_hit        (btb_hit),
        .btb_target     (btb_target),
        .update_en      (branch_taken),
        .update_pc      (pc_current),
        .update_target  (branch_target),
        .update_taken   (branch_taken)
    );
    
    // PC increment
    assign pc_plus_4 = pc_reg + 32'd4;
    
    // PC selection logic
    always_comb begin
        if (branch_taken) begin
            // Branch misprediction - use correct target
            pc_selected = branch_target;
        end else if (btb_hit && !stall) begin
            // Branch prediction hit - use predicted target
            pc_selected = btb_target;
        end else if (!stall) begin
            // Normal execution - increment PC
            pc_selected = pc_plus_4;
        end else begin
            // Stall - keep current PC
            pc_selected = pc_reg;
        end
    end
    
    // PC register update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 32'h0000_0000;  // Reset to address 0
        end else if (!stall || branch_taken) begin
            pc_reg <= pc_selected;
        end
    end
    
    // I-cache request generation
    assign icache_req = !stall && !flush;
    
    // Instruction validity check
    assign instruction_valid = icache_req && !icache_stall && !flush;
    
    // IF/ID register preparation
    always_comb begin
        if_id_next = '0;  // Default values
        
        if (flush || !instruction_valid) begin
            // Insert NOP (bubble) on flush or invalid instruction
            if_id_next.instruction = 32'h0000_0013;  // NOP (addi x0, x0, 0)
            if_id_next.valid = 1'b0;
        end else begin
            if_id_next.pc = pc_reg;
            if_id_next.instruction = icache_data;
            if_id_next.valid = 1'b1;
            if_id_next.exception = 1'b0;  // No exception handling in basic implementation
            if_id_next.exception_cause = 32'h0;
        end
    end
    
    // Output assignments
    assign pc_current = pc_reg;
    assign pc_next = pc_selected;
    
endmodule