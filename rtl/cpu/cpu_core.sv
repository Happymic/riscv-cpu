//////////////////////////////////////////////////////////////////////////////////
// Module: cpu_core
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Main CPU core module implementing 5-stage pipeline for RV32I
//              Stages: IF (Instruction Fetch), ID (Instruction Decode), 
//              EX (Execute), MEM (Memory), WB (Write Back)
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

import cpu_types::*;

module cpu_core (
    input  logic        clk,
    input  logic        rst_n,
    
    // Instruction fetch interface
    output logic [31:0] pc_out,            // Program counter output
    output logic        icache_req,        // I-cache request
    input  logic [31:0] icache_data,       // Instruction from I-cache
    input  logic        icache_stall,      // I-cache stall signal
    
    // Data memory interface
    output logic        dcache_req,        // D-cache request
    output logic        dcache_we,         // D-cache write enable
    output logic [31:0] dcache_addr,       // D-cache address
    output logic [31:0] dcache_wdata,      // D-cache write data
    output logic [3:0]  dcache_be,         // D-cache byte enable
    input  logic [31:0] dcache_rdata,      // Data from D-cache
    input  logic        dcache_stall,      // D-cache stall signal
    
    // Exception interface
    output logic        exception,         // Exception occurred
    output logic [31:0] exception_cause,   // Exception cause code
    output logic [31:0] exception_addr,    // Exception address
    input  logic        interrupt,         // External interrupt
    input  logic [31:0] mtvec,             // Machine trap vector
    
    // Debug interface
    output logic [31:0] debug_pc,          // Current PC for debugging
    output logic [31:0] debug_inst,        // Current instruction
    output logic        debug_valid        // Instruction valid
);

    //////////////////////////////////////////////////////////////////////////////////
    // Pipeline Registers and Control Signals
    //////////////////////////////////////////////////////////////////////////////////
    
    // Pipeline registers
    if_id_reg_t  if_id_reg, if_id_next;
    id_ex_reg_t  id_ex_reg, id_ex_next;
    ex_mem_reg_t ex_mem_reg, ex_mem_next;
    mem_wb_reg_t mem_wb_reg, mem_wb_next;
    
    // Internal signals
    logic [31:0] pc_current, pc_next;
    logic        pc_enable;
    logic        pipeline_stall;
    logic        pipeline_flush;
    
    // Hazard detection signals
    logic        data_hazard_stall;
    logic        load_use_hazard;
    logic        branch_hazard;
    
    // Forwarding signals
    logic [1:0]  forward_a;                // Forwarding for rs1
    logic [1:0]  forward_b;                // Forwarding for rs2
    
    // Branch prediction signals
    logic        branch_predicted;
    logic        branch_mispredicted;
    logic [31:0] branch_target;
    
    // Register file signals
    logic [31:0] rf_rs1_data;
    logic [31:0] rf_rs2_data;
    logic        rf_we;
    logic [4:0]  rf_wa;
    logic [31:0] rf_wd;
    
    // Control signals
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic        alu_src;
    logic [3:0]  alu_op;
    logic        mem_read;
    logic        mem_write;
    logic        reg_write;
    logic        branch;
    logic        jump;
    logic        mem_to_reg;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Module Instances
    //////////////////////////////////////////////////////////////////////////////////
    
    // Instruction Fetch Stage
    if_stage u_if_stage (
        .clk                (clk),
        .rst_n              (rst_n),
        .stall              (pipeline_stall),
        .flush              (pipeline_flush),
        .branch_taken       (branch_mispredicted),
        .branch_target      (branch_target),
        .pc_current         (pc_current),
        .pc_next            (pc_next),
        .icache_req         (icache_req),
        .icache_data        (icache_data),
        .icache_stall       (icache_stall),
        .if_id_next         (if_id_next)
    );
    
    // Instruction Decode Stage
    id_stage u_id_stage (
        .clk                (clk),
        .rst_n              (rst_n),
        .if_id_reg          (if_id_reg),
        .stall              (data_hazard_stall),
        .flush              (pipeline_flush),
        .rf_rs1_data        (rf_rs1_data),
        .rf_rs2_data        (rf_rs2_data),
        .id_ex_next         (id_ex_next),
        .opcode             (opcode),
        .funct3             (funct3),
        .funct7             (funct7)
    );
    
    // Execute Stage
    ex_stage u_ex_stage (
        .clk                (clk),
        .rst_n              (rst_n),
        .id_ex_reg          (id_ex_reg),
        .forward_a          (forward_a),
        .forward_b          (forward_b),
        .ex_mem_alu_result  (ex_mem_reg.alu_result),
        .wb_data            (rf_wd),
        .ex_mem_next        (ex_mem_next),
        .branch_taken       (branch_mispredicted),
        .branch_target      (branch_target)
    );
    
    // Memory Stage
    mem_stage u_mem_stage (
        .clk                (clk),
        .rst_n              (rst_n),
        .ex_mem_reg         (ex_mem_reg),
        .dcache_req         (dcache_req),
        .dcache_we          (dcache_we),
        .dcache_addr        (dcache_addr),
        .dcache_wdata       (dcache_wdata),
        .dcache_be          (dcache_be),
        .dcache_rdata       (dcache_rdata),
        .dcache_stall       (dcache_stall),
        .mem_wb_next        (mem_wb_next)
    );
    
    // Write Back Stage
    wb_stage u_wb_stage (
        .clk                (clk),
        .rst_n              (rst_n),
        .mem_wb_reg         (mem_wb_reg),
        .rf_we              (rf_we),
        .rf_wa              (rf_wa),
        .rf_wd              (rf_wd)
    );
    
    // Register File
    regfile u_regfile (
        .clk                (clk),
        .rst_n              (rst_n),
        .rs1_addr           (if_id_reg.instruction[19:15]),
        .rs2_addr           (if_id_reg.instruction[24:20]),
        .rs1_data           (rf_rs1_data),
        .rs2_data           (rf_rs2_data),
        .we                 (rf_we),
        .wa                 (rf_wa),
        .wd                 (rf_wd)
    );
    
    // Hazard Detection Unit
    hazard_unit u_hazard_unit (
        .id_ex_mem_read     (id_ex_reg.mem_read),
        .id_ex_rd           (id_ex_reg.rd_addr),
        .if_id_rs1          (if_id_reg.instruction[19:15]),
        .if_id_rs2          (if_id_reg.instruction[24:20]),
        .branch_taken       (branch_mispredicted),
        .dcache_stall       (dcache_stall),
        .icache_stall       (icache_stall),
        .stall              (pipeline_stall),
        .flush              (pipeline_flush),
        .data_hazard_stall  (data_hazard_stall)
    );
    
    // Forwarding Unit
    forwarding_unit u_forwarding_unit (
        .ex_mem_reg_write   (ex_mem_reg.reg_write),
        .mem_wb_reg_write   (mem_wb_reg.reg_write),
        .ex_mem_rd          (ex_mem_reg.rd_addr),
        .mem_wb_rd          (mem_wb_reg.rd_addr),
        .id_ex_rs1          (id_ex_reg.rs1_addr),
        .id_ex_rs2          (id_ex_reg.rs2_addr),
        .forward_a          (forward_a),
        .forward_b          (forward_b)
    );
    
    // Control Unit
    control_unit u_control_unit (
        .opcode             (opcode),
        .funct3             (funct3),
        .funct7             (funct7),
        .alu_src            (alu_src),
        .alu_op             (alu_op),
        .mem_read           (mem_read),
        .mem_write          (mem_write),
        .reg_write          (reg_write),
        .branch             (branch),
        .jump               (jump),
        .mem_to_reg         (mem_to_reg)
    );
    
    //////////////////////////////////////////////////////////////////////////////////
    // Pipeline Register Updates
    //////////////////////////////////////////////////////////////////////////////////
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_reg  <= '0;
            id_ex_reg  <= '0;
            ex_mem_reg <= '0;
            mem_wb_reg <= '0;
            pc_current <= 32'h0000_0000;  // Reset PC to 0
        end else begin
            // Update pipeline registers
            if (!pipeline_stall) begin
                if_id_reg <= if_id_next;
                id_ex_reg <= id_ex_next;
            end
            ex_mem_reg <= ex_mem_next;
            mem_wb_reg <= mem_wb_next;
            
            // Update PC
            if (!pipeline_stall) begin
                if (branch_mispredicted) begin
                    pc_current <= branch_target;
                end else begin
                    pc_current <= pc_next;
                end
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Output Assignments
    //////////////////////////////////////////////////////////////////////////////////
    
    assign pc_out = pc_current;
    assign debug_pc = if_id_reg.pc;
    assign debug_inst = if_id_reg.instruction;
    assign debug_valid = if_id_reg.valid;
    
    // Exception handling (simplified)
    assign exception = if_id_reg.exception;
    assign exception_cause = if_id_reg.exception_cause;
    assign exception_addr = if_id_reg.pc;
    
endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: forwarding_unit
// Description: Detects data hazards and generates forwarding control signals
//////////////////////////////////////////////////////////////////////////////////

module forwarding_unit (
    input  logic        ex_mem_reg_write,
    input  logic        mem_wb_reg_write,
    input  logic [4:0]  ex_mem_rd,
    input  logic [4:0]  mem_wb_rd,
    input  logic [4:0]  id_ex_rs1,
    input  logic [4:0]  id_ex_rs2,
    output logic [1:0]  forward_a,         // 00: no forward, 01: from EX/MEM, 10: from MEM/WB
    output logic [1:0]  forward_b          // 00: no forward, 01: from EX/MEM, 10: from MEM/WB
);

    always_comb begin
        // Default: no forwarding
        forward_a = 2'b00;
        forward_b = 2'b00;
        
        // Forward from EX/MEM stage (priority 1)
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1)) begin
            forward_a = 2'b01;
        end
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2)) begin
            forward_b = 2'b01;
        end
        
        // Forward from MEM/WB stage (priority 2)
        if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1) &&
            !(ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1))) begin
            forward_a = 2'b10;
        end
        if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2) &&
            !(ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2))) begin
            forward_b = 2'b10;
        end
    end

endmodule