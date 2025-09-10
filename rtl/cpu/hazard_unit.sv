//////////////////////////////////////////////////////////////////////////////////
// Module: hazard_unit
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Hazard detection unit for the 5-stage pipeline
//              Detects and resolves data hazards, control hazards, and structural hazards
//              Generates stall and flush signals for pipeline control
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module hazard_unit (
    // Load-use hazard detection
    input  logic        id_ex_mem_read,     // ID/EX stage has load instruction
    input  logic [4:0]  id_ex_rd,           // ID/EX destination register
    input  logic [4:0]  if_id_rs1,          // IF/ID source register 1
    input  logic [4:0]  if_id_rs2,          // IF/ID source register 2
    
    // Control hazard detection
    input  logic        branch_taken,       // Branch taken signal from EX stage
    
    // Structural hazard detection
    input  logic        dcache_stall,       // Data cache stall
    input  logic        icache_stall,       // Instruction cache stall
    
    // Hazard control outputs
    output logic        stall,              // Pipeline stall signal
    output logic        flush,              // Pipeline flush signal
    output logic        data_hazard_stall   // Data hazard stall signal
);

    // Internal signals
    logic load_use_hazard;
    logic structural_hazard;
    logic control_hazard;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Load-Use Hazard Detection
    //////////////////////////////////////////////////////////////////////////////////
    
    // Detect when current instruction in ID stage depends on load in EX stage
    always_comb begin
        load_use_hazard = 1'b0;
        
        if (id_ex_mem_read && (id_ex_rd != 5'h0)) begin
            // Check if the load destination matches current instruction's sources
            if ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2)) begin
                load_use_hazard = 1'b1;
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Structural Hazard Detection
    //////////////////////////////////////////////////////////////////////////////////
    
    // Detect cache stalls
    always_comb begin
        structural_hazard = icache_stall || dcache_stall;
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Control Hazard Detection
    //////////////////////////////////////////////////////////////////////////////////
    
    // Branch misprediction causes control hazard
    always_comb begin
        control_hazard = branch_taken;
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Hazard Resolution Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Default: no stall or flush
        stall = 1'b0;
        flush = 1'b0;
        data_hazard_stall = 1'b0;
        
        // Priority-based hazard resolution
        if (structural_hazard) begin
            // Structural hazard - stall entire pipeline
            stall = 1'b1;
            flush = 1'b0;
        end else if (control_hazard) begin
            // Control hazard - flush IF and ID stages
            stall = 1'b0;
            flush = 1'b1;
        end else if (load_use_hazard) begin
            // Load-use hazard - stall IF and ID, insert bubble in EX
            stall = 1'b1;
            data_hazard_stall = 1'b1;
            flush = 1'b0;
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Debug Output (simulation only)
    //////////////////////////////////////////////////////////////////////////////////
    
    `ifdef SIMULATION
    always @(*) begin
        if (load_use_hazard) begin
            $display("Time %t: Load-use hazard detected", $time);
        end
        if (control_hazard) begin
            $display("Time %t: Control hazard detected (branch taken)", $time);
        end
        if (structural_hazard) begin
            $display("Time %t: Structural hazard detected (cache stall)", $time);
        end
    end
    `endif
    
endmodule