//////////////////////////////////////////////////////////////////////////////////
// Module: page_table_walk
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Page Table Walker for RISC-V Sv32 virtual memory system
//              Implements 2-level page table traversal with proper error checking
//              Handles leaf and non-leaf PTEs according to RISC-V specification
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module page_table_walk (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control interface
    input  logic        start,              // Start page table walk
    input  logic [31:0] virtual_addr,       // Virtual address to translate
    input  logic [21:0] root_ppn,           // Root page table PPN from SATP
    output logic        done,               // Walk completed
    output logic        fault,              // Page fault occurred
    
    // Result interface
    output logic [21:0] result_ppn,         // Resulting physical page number
    output logic [7:0]  result_flags,       // Resulting PTE flags
    
    // Memory interface
    output logic        mem_req,            // Memory request
    output logic [31:0] mem_addr,           // Memory address
    input  logic [31:0] mem_rdata,          // Memory read data
    input  logic        mem_ready           // Memory ready signal
);

    //////////////////////////////////////////////////////////////////////////////////
    // Sv32 Constants and Address Fields
    //////////////////////////////////////////////////////////////////////////////////
    
    localparam VPN1_BITS = 10;
    localparam VPN0_BITS = 10;
    localparam OFFSET_BITS = 12;
    localparam PPN_BITS = 22;
    
    // PTE bit positions
    localparam PTE_V = 0;                   // Valid
    localparam PTE_R = 1;                   // Readable
    localparam PTE_W = 2;                   // Writable
    localparam PTE_X = 3;                   // Executable
    localparam PTE_U = 4;                   // User accessible
    localparam PTE_G = 5;                   // Global
    localparam PTE_A = 6;                   // Accessed
    localparam PTE_D = 7;                   // Dirty
    
    //////////////////////////////////////////////////////////////////////////////////
    // Address Breakdown
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [9:0]  vpn1, vpn0;
    logic [11:0] page_offset;
    
    assign vpn1 = virtual_addr[31:22];
    assign vpn0 = virtual_addr[21:12];
    assign page_offset = virtual_addr[11:0];
    
    //////////////////////////////////////////////////////////////////////////////////
    // State Machine
    //////////////////////////////////////////////////////////////////////////////////
    
    typedef enum logic [2:0] {
        IDLE,
        FETCH_L1_PTE,
        WAIT_L1_PTE,
        FETCH_L0_PTE,
        WAIT_L0_PTE,
        WALK_DONE,
        WALK_FAULT
    } ptw_state_t;
    
    ptw_state_t state, next_state;
    
    //////////////////////////////////////////////////////////////////////////////////
    // PTE Storage and Analysis
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [31:0] pte_l1, pte_l0;            // Level 1 and Level 0 PTEs
    logic [31:0] current_pte;               // Current PTE being analyzed
    logic [1:0]  current_level;             // Current page table level (1 or 0)
    
    // PTE field extraction
    logic        pte_valid;
    logic        pte_readable;
    logic        pte_writable;
    logic        pte_executable;
    logic        pte_user;
    logic        pte_global;
    logic        pte_accessed;
    logic        pte_dirty;
    logic [21:0] pte_ppn;
    logic        pte_is_leaf;
    logic        pte_is_pointer;
    
    always_comb begin
        pte_valid      = current_pte[PTE_V];
        pte_readable   = current_pte[PTE_R];
        pte_writable   = current_pte[PTE_W];
        pte_executable = current_pte[PTE_X];
        pte_user       = current_pte[PTE_U];
        pte_global     = current_pte[PTE_G];
        pte_accessed   = current_pte[PTE_A];
        pte_dirty      = current_pte[PTE_D];
        pte_ppn        = current_pte[31:10];
        
        // A PTE is a leaf if any of R, W, X bits are set
        pte_is_leaf = pte_readable || pte_writable || pte_executable;
        
        // A PTE is a pointer if it's valid but not a leaf
        pte_is_pointer = pte_valid && !pte_is_leaf;
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Page Table Address Calculation
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [31:0] l1_pte_addr, l0_pte_addr;
    
    // Level 1 PTE address: root_ppn * 4096 + vpn1 * 4
    assign l1_pte_addr = {root_ppn, 12'h0} + {22'h0, vpn1, 2'b00};
    
    // Level 0 PTE address: pte_l1_ppn * 4096 + vpn0 * 4
    assign l0_pte_addr = {pte_l1[31:10], 12'h0} + {22'h0, vpn0, 2'b00};
    
    //////////////////////////////////////////////////////////////////////////////////
    // State Machine Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pte_l1 <= 32'h0;
            pte_l0 <= 32'h0;
            current_level <= 2'd1;
        end else begin
            state <= next_state;
            
            // Store fetched PTEs
            case (state)
                WAIT_L1_PTE: begin
                    if (mem_ready) begin
                        pte_l1 <= mem_rdata;
                        current_level <= 2'd1;
                    end
                end
                
                WAIT_L0_PTE: begin
                    if (mem_ready) begin
                        pte_l0 <= mem_rdata;
                        current_level <= 2'd0;
                    end
                end
                
                IDLE: begin
                    if (start) begin
                        current_level <= 2'd1;
                    end
                end
            endcase
        end
    end
    
    // Select current PTE based on level
    always_comb begin
        if (current_level == 2'd1) begin
            current_pte = pte_l1;
        end else begin
            current_pte = pte_l0;
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FETCH_L1_PTE;
                end
            end
            
            FETCH_L1_PTE: begin
                next_state = WAIT_L1_PTE;
            end
            
            WAIT_L1_PTE: begin
                if (mem_ready) begin
                    if (!pte_valid) begin
                        // Invalid PTE - page fault
                        next_state = WALK_FAULT;
                    end else if (pte_is_leaf) begin
                        // Found leaf PTE at level 1 (1GB page)
                        next_state = WALK_DONE;
                    end else if (pte_is_pointer) begin
                        // Pointer to level 0 page table
                        next_state = FETCH_L0_PTE;
                    end else begin
                        // Invalid PTE format
                        next_state = WALK_FAULT;
                    end
                end
            end
            
            FETCH_L0_PTE: begin
                next_state = WAIT_L0_PTE;
            end
            
            WAIT_L0_PTE: begin
                if (mem_ready) begin
                    if (!pte_valid) begin
                        // Invalid PTE - page fault
                        next_state = WALK_FAULT;
                    end else if (pte_is_leaf) begin
                        // Found leaf PTE at level 0 (4KB page)
                        next_state = WALK_DONE;
                    end else begin
                        // Invalid: level 0 PTE cannot be a pointer
                        next_state = WALK_FAULT;
                    end
                end
            end
            
            WALK_DONE: begin
                next_state = IDLE;
            end
            
            WALK_FAULT: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Output Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        mem_req = 1'b0;
        mem_addr = 32'h0;
        done = 1'b0;
        fault = 1'b0;
        result_ppn = 22'h0;
        result_flags = 8'h0;
        
        case (state)
            FETCH_L1_PTE: begin
                mem_req = 1'b1;
                mem_addr = l1_pte_addr;
            end
            
            FETCH_L0_PTE: begin
                mem_req = 1'b1;
                mem_addr = l0_pte_addr;
            end
            
            WALK_DONE: begin
                done = 1'b1;
                result_ppn = pte_ppn;
                result_flags = current_pte[7:0];
                
                // For level 1 leaf PTEs, need to check alignment
                if (current_level == 2'd1) begin
                    // 1GB pages: PPN[0] must be zero for proper alignment
                    if (pte_ppn[9:0] != 10'h0) begin
                        fault = 1'b1;
                        done = 1'b0;
                    end else begin
                        // Construct final PPN for 1GB page
                        result_ppn = {pte_ppn[21:10], vpn0};
                    end
                end
            end
            
            WALK_FAULT: begin
                fault = 1'b1;
                done = 1'b1;
            end
        endcase
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Debug Output (simulation only)
    //////////////////////////////////////////////////////////////////////////////////
    
    `ifdef SIMULATION
    always @(posedge clk) begin
        case (state)
            FETCH_L1_PTE: begin
                $display("Time %t: PTW Level 1 fetch - VA: 0x%08x, PTE addr: 0x%08x", 
                        $time, virtual_addr, l1_pte_addr);
            end
            
            FETCH_L0_PTE: begin
                $display("Time %t: PTW Level 0 fetch - VA: 0x%08x, PTE addr: 0x%08x", 
                        $time, virtual_addr, l0_pte_addr);
            end
            
            WALK_DONE: begin
                if (current_level == 2'd1) begin
                    $display("Time %t: PTW Complete (1GB page) - VA: 0x%08x -> PPN: 0x%06x", 
                            $time, virtual_addr, result_ppn);
                end else begin
                    $display("Time %t: PTW Complete (4KB page) - VA: 0x%08x -> PPN: 0x%06x", 
                            $time, virtual_addr, result_ppn);
                end
            end
            
            WALK_FAULT: begin
                $display("Time %t: PTW Fault - VA: 0x%08x at level %0d", 
                        $time, virtual_addr, current_level);
            end
        endcase
    end
    `endif
    
endmodule