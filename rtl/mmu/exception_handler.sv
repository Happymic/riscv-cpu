//////////////////////////////////////////////////////////////////////////////////
// Module: exception_handler
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Exception handler for MMU-related faults and violations
//              Generates appropriate exception codes for page faults and access violations
//              Interfaces with CPU exception handling mechanism
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module exception_handler (
    input  logic        clk,
    input  logic        rst_n,
    
    // MMU fault inputs
    input  logic        page_fault,         // Page fault from MMU
    input  logic        access_fault,       // Access fault from MMU
    input  logic [31:0] fault_addr,         // Faulting virtual address
    input  logic        is_load,            // Load operation
    input  logic        is_store,           // Store operation
    input  logic        is_fetch,           // Instruction fetch
    
    // Exception outputs to CPU
    output logic        exception,          // Exception signal
    output logic [31:0] exception_cause,    // Exception cause code
    output logic [31:0] exception_value,    // Exception value (faulting address)
    
    // Control inputs
    input  logic        supervisor_mode,    // Current privilege mode
    input  logic        mmu_enabled         // MMU enable status
);

    //////////////////////////////////////////////////////////////////////////////////
    // RISC-V Exception Cause Codes
    //////////////////////////////////////////////////////////////////////////////////
    
    // Instruction page faults
    localparam CAUSE_INST_PAGE_FAULT = 32'd12;
    
    // Load page faults
    localparam CAUSE_LOAD_PAGE_FAULT = 32'd13;
    
    // Store/AMO page faults  
    localparam CAUSE_STORE_PAGE_FAULT = 32'd15;
    
    // Access faults
    localparam CAUSE_INST_ACCESS_FAULT = 32'd1;
    localparam CAUSE_LOAD_ACCESS_FAULT = 32'd5;
    localparam CAUSE_STORE_ACCESS_FAULT = 32'd7;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Exception Generation Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        exception = 1'b0;
        exception_cause = 32'h0;
        exception_value = 32'h0;
        
        if (mmu_enabled && (page_fault || access_fault)) begin
            exception = 1'b1;
            exception_value = fault_addr;
            
            if (page_fault) begin
                // Page fault - determine type based on operation
                if (is_fetch) begin
                    exception_cause = CAUSE_INST_PAGE_FAULT;
                end else if (is_load) begin
                    exception_cause = CAUSE_LOAD_PAGE_FAULT;
                end else if (is_store) begin
                    exception_cause = CAUSE_STORE_PAGE_FAULT;
                end else begin
                    // Default to load page fault
                    exception_cause = CAUSE_LOAD_PAGE_FAULT;
                end
            end else if (access_fault) begin
                // Access fault - permission violation
                if (is_fetch) begin
                    exception_cause = CAUSE_INST_ACCESS_FAULT;
                end else if (is_load) begin
                    exception_cause = CAUSE_LOAD_ACCESS_FAULT;
                end else if (is_store) begin
                    exception_cause = CAUSE_STORE_ACCESS_FAULT;
                end else begin
                    // Default to load access fault
                    exception_cause = CAUSE_LOAD_ACCESS_FAULT;
                end
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Debug Output (simulation only)
    //////////////////////////////////////////////////////////////////////////////////
    
    `ifdef SIMULATION
    always @(posedge clk) begin
        if (exception) begin
            case (exception_cause)
                CAUSE_INST_PAGE_FAULT: begin
                    $display("Time %t: Instruction Page Fault - Addr: 0x%08x", 
                            $time, exception_value);
                end
                CAUSE_LOAD_PAGE_FAULT: begin
                    $display("Time %t: Load Page Fault - Addr: 0x%08x", 
                            $time, exception_value);
                end
                CAUSE_STORE_PAGE_FAULT: begin
                    $display("Time %t: Store Page Fault - Addr: 0x%08x", 
                            $time, exception_value);
                end
                CAUSE_INST_ACCESS_FAULT: begin
                    $display("Time %t: Instruction Access Fault - Addr: 0x%08x", 
                            $time, exception_value);
                end
                CAUSE_LOAD_ACCESS_FAULT: begin
                    $display("Time %t: Load Access Fault - Addr: 0x%08x", 
                            $time, exception_value);
                end
                CAUSE_STORE_ACCESS_FAULT: begin
                    $display("Time %t: Store Access Fault - Addr: 0x%08x", 
                            $time, exception_value);
                end
                default: begin
                    $display("Time %t: Unknown MMU Exception - Cause: %0d, Addr: 0x%08x", 
                            $time, exception_cause, exception_value);
                end
            endcase
        end
    end
    `endif
    
endmodule