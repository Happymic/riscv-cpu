//////////////////////////////////////////////////////////////////////////////////
// Module: mmu
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Memory Management Unit for RISC-V Sv32 virtual memory
//              Implements 2-level page table translation with TLB
//              Supports 4KB pages with supervisor and user mode access control
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module mmu (
    input  logic        clk,
    input  logic        rst_n,
    
    // CPU interface
    input  logic        enable,             // MMU enable (from satp.MODE)
    input  logic [31:0] virtual_addr,       // Virtual address from CPU
    output logic [31:0] physical_addr,      // Physical address to cache/memory
    output logic        page_fault,         // Page fault exception
    output logic        access_fault,       // Access fault exception
    output logic        busy,               // MMU busy during page table walk
    
    // Control signals
    input  logic        is_load,            // Load operation
    input  logic        is_store,           // Store operation
    input  logic        is_fetch,           // Instruction fetch
    input  logic        supervisor_mode,    // Supervisor mode active
    input  logic [31:0] satp,              // Supervisor address translation register
    
    // Memory interface for page table walks
    output logic        ptw_req,            // Page table walk memory request
    output logic [31:0] ptw_addr,           // Page table walk address
    input  logic [31:0] ptw_rdata,          // Page table walk read data
    input  logic        ptw_ready           // Page table walk ready
);

    //////////////////////////////////////////////////////////////////////////////////
    // Sv32 Virtual Memory Constants
    //////////////////////////////////////////////////////////////////////////////////
    
    localparam VPN1_BITS = 10;              // Virtual page number level 1 bits
    localparam VPN0_BITS = 10;              // Virtual page number level 0 bits
    localparam OFFSET_BITS = 12;            // Page offset bits (4KB pages)
    localparam PPN_BITS = 22;               // Physical page number bits
    
    // Page Table Entry (PTE) bit positions
    localparam PTE_V     = 0;               // Valid
    localparam PTE_R     = 1;               // Readable
    localparam PTE_W     = 2;               // Writable
    localparam PTE_X     = 3;               // Executable
    localparam PTE_U     = 4;               // User accessible
    localparam PTE_G     = 5;               // Global
    localparam PTE_A     = 6;               // Accessed
    localparam PTE_D     = 7;               // Dirty
    localparam PTE_PPN0  = 10;              // PPN[0] start bit
    localparam PTE_PPN1  = 20;              // PPN[1] start bit
    
    //////////////////////////////////////////////////////////////////////////////////
    // Virtual Address Breakdown
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [9:0]  va_vpn1;                   // VPN[1] - level 1 virtual page number
    logic [9:0]  va_vpn0;                   // VPN[0] - level 0 virtual page number
    logic [11:0] va_offset;                 // Page offset
    
    assign va_vpn1   = virtual_addr[31:22];
    assign va_vpn0   = virtual_addr[21:12];
    assign va_offset = virtual_addr[11:0];
    
    //////////////////////////////////////////////////////////////////////////////////
    // SATP Register Fields
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [21:0] satp_ppn;                  // Physical page number of root page table
    logic        satp_mode;                 // Translation mode (0=Bare, 1=Sv32)
    
    assign satp_ppn  = satp[21:0];
    assign satp_mode = satp[31];
    
    //////////////////////////////////////////////////////////////////////////////////
    // MMU State Machine
    //////////////////////////////////////////////////////////////////////////////////
    
    typedef enum logic [2:0] {
        IDLE,
        TLB_LOOKUP,
        PTW_LEVEL1,
        PTW_LEVEL0,
        PTW_WAIT,
        TRANSLATION_DONE,
        FAULT
    } state_t;
    
    state_t state, next_state;
    
    //////////////////////////////////////////////////////////////////////////////////
    // TLB Interface
    //////////////////////////////////////////////////////////////////////////////////
    
    logic        tlb_req;
    logic [19:0] tlb_vpn;                   // 20-bit VPN for TLB lookup
    logic [21:0] tlb_ppn;                   // 22-bit PPN from TLB
    logic        tlb_hit;
    logic        tlb_valid;
    logic [7:0]  tlb_pte_flags;             // PTE flags from TLB
    
    assign tlb_vpn = {va_vpn1, va_vpn0};
    
    //////////////////////////////////////////////////////////////////////////////////
    // Page Table Walk Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [31:0] pte_level1;                // Level 1 PTE
    logic [31:0] pte_level0;                // Level 0 PTE
    logic [31:0] ptw_addr_level1;           // Level 1 page table address
    logic [31:0] ptw_addr_level0;           // Level 0 page table address
    logic [1:0]  ptw_level;                 // Current page table walk level
    logic        pte_valid;
    logic        pte_leaf;
    logic [7:0]  pte_flags;
    logic [21:0] pte_ppn;
    
    // Page table walk address calculation
    assign ptw_addr_level1 = {satp_ppn, 2'b00} + {va_vpn1, 2'b00};
    assign ptw_addr_level0 = {pte_level1[31:10], 2'b00} + {va_vpn0, 2'b00};
    
    //////////////////////////////////////////////////////////////////////////////////
    // PTE Analysis
    //////////////////////////////////////////////////////////////////////////////////
    
    logic current_pte_valid;
    logic [31:0] current_pte;
    
    assign current_pte = (ptw_level == 2'd1) ? pte_level1 : pte_level0;
    assign current_pte_valid = current_pte[PTE_V];
    
    // Check if PTE is a leaf (has R, W, or X bits set)
    always_comb begin
        pte_leaf = current_pte[PTE_R] || current_pte[PTE_W] || current_pte[PTE_X];
        pte_flags = current_pte[7:0];
        pte_ppn = current_pte[31:10];
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Permission Check Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    logic permission_ok;
    
    always_comb begin
        permission_ok = 1'b0;
        
        if (tlb_hit && tlb_valid) begin
            // Use TLB entry for permission check
            if (is_fetch) begin
                permission_ok = tlb_pte_flags[PTE_X] && 
                               (supervisor_mode || tlb_pte_flags[PTE_U]);
            end else if (is_load) begin
                permission_ok = tlb_pte_flags[PTE_R] && 
                               (supervisor_mode || tlb_pte_flags[PTE_U]);
            end else if (is_store) begin
                permission_ok = tlb_pte_flags[PTE_W] && 
                               (supervisor_mode || tlb_pte_flags[PTE_U]);
            end
        end else if (state == TRANSLATION_DONE) begin
            // Use current PTE for permission check
            if (is_fetch) begin
                permission_ok = pte_flags[PTE_X] && 
                               (supervisor_mode || pte_flags[PTE_U]);
            end else if (is_load) begin
                permission_ok = pte_flags[PTE_R] && 
                               (supervisor_mode || pte_flags[PTE_U]);
            end else if (is_store) begin
                permission_ok = pte_flags[PTE_W] && 
                               (supervisor_mode || pte_flags[PTE_U]);
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // TLB Instance
    //////////////////////////////////////////////////////////////////////////////////
    
    tlb u_tlb (
        .clk            (clk),
        .rst_n          (rst_n),
        
        // Lookup interface
        .req            (tlb_req),
        .vpn            (tlb_vpn),
        .ppn            (tlb_ppn),
        .hit            (tlb_hit),
        .valid          (tlb_valid),
        .pte_flags      (tlb_pte_flags),
        
        // Update interface
        .update_en      (state == TRANSLATION_DONE),
        .update_vpn     (tlb_vpn),
        .update_ppn     (pte_ppn),
        .update_flags   (pte_flags),
        
        // Invalidation interface
        .invalidate_all (1'b0),             // Can be connected to SFENCE.VMA
        .invalidate_vpn (20'h0),
        .invalidate_en  (1'b0)
    );
    
    //////////////////////////////////////////////////////////////////////////////////
    // MMU State Machine Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pte_level1 <= 32'h0;
            pte_level0 <= 32'h0;
            ptw_level <= 2'd1;
        end else begin
            state <= next_state;
            
            // Store PTEs during page table walk
            if (state == PTW_WAIT && ptw_ready) begin
                if (ptw_level == 2'd1) begin
                    pte_level1 <= ptw_rdata;
                end else if (ptw_level == 2'd0) begin
                    pte_level0 <= ptw_rdata;
                end
            end
            
            // Update page table walk level
            if (state == PTW_LEVEL1 && next_state == PTW_WAIT) begin
                ptw_level <= 2'd1;
            end else if (state == PTW_LEVEL0 && next_state == PTW_WAIT) begin
                ptw_level <= 2'd0;
            end
        end
    end
    
    always_comb begin
        next_state = state;
        tlb_req = 1'b0;
        ptw_req = 1'b0;
        ptw_addr = 32'h0;
        busy = 1'b0;
        physical_addr = virtual_addr;  // Default: direct mapping
        page_fault = 1'b0;
        access_fault = 1'b0;
        
        case (state)
            IDLE: begin
                if (enable && satp_mode) begin
                    next_state = TLB_LOOKUP;
                end else begin
                    // MMU disabled - direct mapping
                    physical_addr = virtual_addr;
                end
            end
            
            TLB_LOOKUP: begin
                tlb_req = 1'b1;
                busy = 1'b1;
                
                if (tlb_hit && tlb_valid) begin
                    // TLB hit - use cached translation
                    physical_addr = {tlb_ppn, va_offset};
                    if (permission_ok) begin
                        next_state = IDLE;
                        busy = 1'b0;
                    end else begin
                        next_state = FAULT;
                        access_fault = 1'b1;
                    end
                end else begin
                    // TLB miss - start page table walk
                    next_state = PTW_LEVEL1;
                end
            end
            
            PTW_LEVEL1: begin
                busy = 1'b1;
                ptw_req = 1'b1;
                ptw_addr = ptw_addr_level1;
                next_state = PTW_WAIT;
            end
            
            PTW_LEVEL0: begin
                busy = 1'b1;
                ptw_req = 1'b1;
                ptw_addr = ptw_addr_level0;
                next_state = PTW_WAIT;
            end
            
            PTW_WAIT: begin
                busy = 1'b1;
                if (ptw_ready) begin
                    if (!current_pte_valid) begin
                        // Invalid PTE
                        next_state = FAULT;
                        page_fault = 1'b1;
                    end else if (pte_leaf) begin
                        // Found leaf PTE
                        next_state = TRANSLATION_DONE;
                    end else if (ptw_level == 2'd1) begin
                        // Non-leaf level 1 PTE - go to level 0
                        next_state = PTW_LEVEL0;
                    end else begin
                        // Invalid page table structure
                        next_state = FAULT;
                        page_fault = 1'b1;
                    end
                end else begin
                    next_state = PTW_WAIT;
                end
            end
            
            TRANSLATION_DONE: begin
                physical_addr = {pte_ppn, va_offset};
                if (permission_ok) begin
                    next_state = IDLE;
                end else begin
                    next_state = FAULT;
                    access_fault = 1'b1;
                end
            end
            
            FAULT: begin
                page_fault = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Debug Output (simulation only)
    //////////////////////////////////////////////////////////////////////////////////
    
    `ifdef SIMULATION
    always @(posedge clk) begin
        if (state == TLB_LOOKUP && tlb_hit) begin
            $display("Time %t: MMU TLB HIT - VA: 0x%08x -> PA: 0x%08x", 
                    $time, virtual_addr, physical_addr);
        end
        if (state == PTW_LEVEL1) begin
            $display("Time %t: MMU Page Table Walk Level 1 - VA: 0x%08x", 
                    $time, virtual_addr);
        end
        if (page_fault) begin
            $display("Time %t: MMU Page Fault - VA: 0x%08x", $time, virtual_addr);
        end
    end
    `endif
    
endmodule