//////////////////////////////////////////////////////////////////////////////////
// Module: top
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Top-level module integrating CPU core, cache hierarchy, MMU, and memory
//              Implements RISC-V RV32I with M-mode support
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module top (
    input  logic        clk,            // System clock
    input  logic        rst_n,          // Active-low reset
    
    // External memory interface (simplified)
    output logic        mem_req,        // Memory request
    output logic        mem_we,         // Memory write enable
    output logic [31:0] mem_addr,       // Memory address
    output logic [31:0] mem_wdata,      // Memory write data
    output logic [3:0]  mem_be,         // Byte enable
    input  logic [31:0] mem_rdata,      // Memory read data
    input  logic        mem_ready,      // Memory ready signal
    
    // Debug interface
    output logic [31:0] debug_pc,       // Current PC for debugging
    output logic [31:0] debug_inst,     // Current instruction
    output logic        debug_valid     // Instruction valid
);

    //////////////////////////////////////////////////////////////////////////////////
    // Internal Signals
    //////////////////////////////////////////////////////////////////////////////////
    
    // CPU to L1 I-Cache interface
    logic [31:0] cpu_pc;                // Program counter
    logic        cpu_icache_req;        // I-cache request
    logic [31:0] icache_data;            // Instruction from I-cache
    logic        icache_hit;             // I-cache hit signal
    logic        icache_stall;           // I-cache stall signal
    
    // CPU to L1 D-Cache interface
    logic        cpu_dcache_req;        // D-cache request
    logic        cpu_dcache_we;         // D-cache write enable
    logic [31:0] cpu_dcache_addr;       // D-cache address
    logic [31:0] cpu_dcache_wdata;      // D-cache write data
    logic [3:0]  cpu_dcache_be;         // D-cache byte enable
    logic [31:0] dcache_rdata;          // Data from D-cache
    logic        dcache_hit;            // D-cache hit signal
    logic        dcache_stall;          // D-cache stall signal
    
    // L1 to L2 cache interface
    logic        l1i_l2_req;            // L1I to L2 request
    logic [31:0] l1i_l2_addr;           // L1I to L2 address
    logic [127:0] l2_l1i_data;          // L2 to L1I data (cache line)
    logic        l2_l1i_valid;          // L2 to L1I valid signal
    
    logic        l1d_l2_req;            // L1D to L2 request
    logic        l1d_l2_we;             // L1D to L2 write enable
    logic [31:0] l1d_l2_addr;           // L1D to L2 address
    logic [127:0] l1d_l2_wdata;         // L1D to L2 write data
    logic [127:0] l2_l1d_data;          // L2 to L1D data
    logic        l2_l1d_valid;          // L2 to L1D valid signal
    
    // L2 to L3 cache interface
    logic        l2_l3_req;             // L2 to L3 request
    logic        l2_l3_we;              // L2 to L3 write enable
    logic [31:0] l2_l3_addr;            // L2 to L3 address
    logic [127:0] l2_l3_wdata;          // L2 to L3 write data
    logic [127:0] l3_l2_data;           // L3 to L2 data
    logic        l3_l2_valid;           // L3 to L2 valid signal
    
    // MMU interface
    logic [31:0] virtual_addr;          // Virtual address from CPU
    logic [31:0] physical_addr;         // Physical address from MMU
    logic        mmu_enable;            // MMU enable signal
    logic        page_fault;            // Page fault exception
    logic        access_fault;          // Access fault exception
    logic        mmu_busy;              // MMU busy signal
    
    // Exception and interrupt signals
    logic        exception;             // Exception signal
    logic [31:0] exception_cause;       // Exception cause
    logic [31:0] exception_addr;        // Exception address
    logic        interrupt;             // External interrupt
    logic [31:0] mtvec;                 // Machine trap vector
    
    //////////////////////////////////////////////////////////////////////////////////
    // CPU Core Instance
    //////////////////////////////////////////////////////////////////////////////////
    
    cpu_core u_cpu_core (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // Instruction fetch interface
        .pc_out             (cpu_pc),
        .icache_req         (cpu_icache_req),
        .icache_data        (icache_data),
        .icache_stall       (icache_stall),
        
        // Data memory interface
        .dcache_req         (cpu_dcache_req),
        .dcache_we          (cpu_dcache_we),
        .dcache_addr        (cpu_dcache_addr),
        .dcache_wdata       (cpu_dcache_wdata),
        .dcache_be          (cpu_dcache_be),
        .dcache_rdata       (dcache_rdata),
        .dcache_stall       (dcache_stall),
        
        // Exception interface
        .exception          (exception),
        .exception_cause    (exception_cause),
        .exception_addr     (exception_addr),
        .interrupt          (interrupt),
        .mtvec              (mtvec),
        
        // Debug interface
        .debug_pc           (debug_pc),
        .debug_inst         (debug_inst),
        .debug_valid        (debug_valid)
    );
    
    //////////////////////////////////////////////////////////////////////////////////
    // L1 Instruction Cache Instance
    //////////////////////////////////////////////////////////////////////////////////
    
    l1_icache #(
        .CACHE_SIZE_KB      (32),          // 32KB cache
        .LINE_SIZE_BYTES    (16),          // 16 bytes per line
        .ASSOCIATIVITY      (2)             // 2-way set associative
    ) u_l1_icache (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // CPU interface
        .req                (cpu_icache_req),
        .addr               (cpu_pc),
        .data_out           (icache_data),
        .hit                (icache_hit),
        .stall              (icache_stall),
        
        // L2 interface
        .l2_req             (l1i_l2_req),
        .l2_addr            (l1i_l2_addr),
        .l2_data            (l2_l1i_data),
        .l2_valid           (l2_l1i_valid)
    );
    
    //////////////////////////////////////////////////////////////////////////////////
    // L1 Data Cache Instance
    //////////////////////////////////////////////////////////////////////////////////
    
    l1_dcache #(
        .CACHE_SIZE_KB      (32),          // 32KB cache
        .LINE_SIZE_BYTES    (16),          // 16 bytes per line
        .ASSOCIATIVITY      (2)             // 2-way set associative
    ) u_l1_dcache (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // CPU interface
        .req                (cpu_dcache_req),
        .we                 (cpu_dcache_we),
        .addr               (cpu_dcache_addr),
        .wdata              (cpu_dcache_wdata),
        .be                 (cpu_dcache_be),
        .rdata              (dcache_rdata),
        .hit                (dcache_hit),
        .stall              (dcache_stall),
        
        // L2 interface
        .l2_req             (l1d_l2_req),
        .l2_we              (l1d_l2_we),
        .l2_addr            (l1d_l2_addr),
        .l2_wdata           (l1d_l2_wdata),
        .l2_rdata           (l2_l1d_data),
        .l2_valid           (l2_l1d_valid)
    );
    
    //////////////////////////////////////////////////////////////////////////////////
    // L2 Unified Cache Instance
    //////////////////////////////////////////////////////////////////////////////////
    
    l2_cache #(
        .CACHE_SIZE_KB      (256),         // 256KB cache
        .LINE_SIZE_BYTES    (16),          // 16 bytes per line
        .ASSOCIATIVITY      (2)             // 2-way set associative
    ) u_l2_cache (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // L1I interface
        .l1i_req            (l1i_l2_req),
        .l1i_addr           (l1i_l2_addr),
        .l1i_data           (l2_l1i_data),
        .l1i_valid          (l2_l1i_valid),
        
        // L1D interface
        .l1d_req            (l1d_l2_req),
        .l1d_we             (l1d_l2_we),
        .l1d_addr           (l1d_l2_addr),
        .l1d_wdata          (l1d_l2_wdata),
        .l1d_rdata          (l2_l1d_data),
        .l1d_valid          (l2_l1d_valid),
        
        // L3 interface
        .l3_req             (l2_l3_req),
        .l3_we              (l2_l3_we),
        .l3_addr            (l2_l3_addr),
        .l3_wdata           (l2_l3_wdata),
        .l3_rdata           (l3_l2_data),
        .l3_valid           (l3_l2_valid)
    );
    
    //////////////////////////////////////////////////////////////////////////////////
    // L3 Cache Instance
    //////////////////////////////////////////////////////////////////////////////////
    
    l3_cache #(
        .CACHE_SIZE_KB      (2048),        // 2MB cache
        .LINE_SIZE_BYTES    (16),          // 16 bytes per line
        .ASSOCIATIVITY      (2)             // 2-way set associative
    ) u_l3_cache (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // L2 interface
        .l2_req             (l2_l3_req),
        .l2_we              (l2_l3_we),
        .l2_addr            (l2_l3_addr),
        .l2_wdata           (l2_l3_wdata),
        .l2_rdata           (l3_l2_data),
        .l2_valid           (l3_l2_valid),
        
        // Memory interface
        .mem_req            (mem_req),
        .mem_we             (mem_we),
        .mem_addr           (mem_addr),
        .mem_wdata          (mem_wdata),
        .mem_be             (mem_be),
        .mem_rdata          (mem_rdata),
        .mem_ready          (mem_ready)
    );
    
    //////////////////////////////////////////////////////////////////////////////////
    // MMU Instance
    //////////////////////////////////////////////////////////////////////////////////
    
    mmu u_mmu (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // CPU interface
        .enable             (mmu_enable),
        .virtual_addr       (virtual_addr),
        .physical_addr      (physical_addr),
        .page_fault         (page_fault),
        .access_fault       (access_fault),
        .busy               (mmu_busy),
        
        // Memory interface for page table walks
        .ptw_req            (/* connect to memory */),
        .ptw_addr           (/* connect to memory */),
        .ptw_rdata          (/* connect to memory */),
        .ptw_ready          (/* connect to memory */)
    );
    
endmodule