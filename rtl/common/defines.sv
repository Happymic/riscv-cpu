// Global Definitions and Parameters
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Centralize common parameters, opcodes, typedefs, and helper macros used
//   across the CPU design to keep modules consistent and readable.
//
// Contents overview:
// - Global width parameters (XLEN/ILEN/FLEN) and cache/TLB sizing knobs.
// - RISC-V opcode constants and ALU/branch/memory operation enums.
// - Exception/interrupt codes and privilege-level constants.
// - CSR addresses (subset) for M/S modes and PMP-related bits.
// - Memory map examples for testbench environments.
// - Utility macros for sign/zero extension and simulation assertions.
//
// Usage:
// - `include this file in modules that need shared constants.
// - Override parameters at module instantiation where appropriate.
// -----------------------------------------------------------------------------

`ifndef RISCV_DEFINES_SV
`define RISCV_DEFINES_SV

// Global Parameters
parameter XLEN = 64;              // Register width
parameter ILEN = 32;              // Instruction width
parameter FLEN = 64;              // Floating point register width

// Cache Parameters
parameter L1I_SIZE = 16384;       // 16KB L1 I-Cache
parameter L1D_SIZE = 32768;       // 32KB L1 D-Cache
parameter L2_SIZE = 262144;       // 256KB L2 Cache
parameter L3_SIZE = 2097152;      // 2MB L3 Cache
parameter CACHE_LINE_SIZE = 64;   // 64-byte cache lines
parameter CACHE_WAYS = 2;         // 2-way associative

// TLB Parameters
parameter ITLB_ENTRIES = 32;      // I-TLB entries
parameter DTLB_ENTRIES = 64;      // D-TLB entries
parameter ASID_WIDTH = 16;        // ASID width

// Branch Prediction Parameters
parameter BTB_SIZE = 256;         // BTB entries
parameter BHT_SIZE = 4096;        // BHT entries
parameter RAS_DEPTH = 16;         // Return address stack depth

// Pipeline Parameters
parameter ROB_SIZE = 128;         // Reorder buffer size
parameter IQ_SIZE = 32;           // Instruction queue size
parameter LSQ_SIZE = 16;          // Load/store queue size

// RISC-V Instruction Opcodes
parameter OP_LOAD     = 7'b0000011;
parameter OP_LOAD_FP  = 7'b0000111;
parameter OP_MISC_MEM = 7'b0001111;
parameter OP_OP_IMM   = 7'b0010011;
parameter OP_AUIPC    = 7'b0010111;
parameter OP_OP_IMM_32= 7'b0011011;
parameter OP_STORE    = 7'b0100011;
parameter OP_STORE_FP = 7'b0100111;
parameter OP_AMO      = 7'b0101111;
parameter OP_OP       = 7'b0110011;
parameter OP_LUI      = 7'b0110111;
parameter OP_OP_32    = 7'b0111011;
parameter OP_MADD     = 7'b1000011;
parameter OP_MSUB     = 7'b1000111;
parameter OP_NMSUB    = 7'b1001011;
parameter OP_NMADD    = 7'b1001111;
parameter OP_OP_FP    = 7'b1010011;
parameter OP_BRANCH   = 7'b1100011;
parameter OP_JALR     = 7'b1100111;
parameter OP_JAL      = 7'b1101111;
parameter OP_SYSTEM   = 7'b1110011;

// ALU Operations
typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b1000,
    ALU_SLL  = 4'b0001,
    ALU_SLT  = 4'b0010,
    ALU_SLTU = 4'b0011,
    ALU_XOR  = 4'b0100,
    ALU_SRL  = 4'b0101,
    ALU_SRA  = 4'b1101,
    ALU_OR   = 4'b0110,
    ALU_AND  = 4'b0111
} alu_op_t;

// Branch Types
typedef enum logic [2:0] {
    BR_BEQ  = 3'b000,
    BR_BNE  = 3'b001,
    BR_BLT  = 3'b100,
    BR_BGE  = 3'b101,
    BR_BLTU = 3'b110,
    BR_BGEU = 3'b111
} branch_op_t;

// Memory Access Types
typedef enum logic [2:0] {
    MEM_BYTE     = 3'b000,
    MEM_HALF     = 3'b001,
    MEM_WORD     = 3'b010,
    MEM_DOUBLE   = 3'b011,
    MEM_BYTE_U   = 3'b100,
    MEM_HALF_U   = 3'b101,
    MEM_WORD_U   = 3'b110
} mem_op_t;

// Exception Causes
parameter EXC_INSTR_ADDR_MISALIGN = 4'h0;
parameter EXC_INSTR_ACCESS_FAULT  = 4'h1;
parameter EXC_ILLEGAL_INSTR       = 4'h2;
parameter EXC_BREAKPOINT          = 4'h3;
parameter EXC_LOAD_ADDR_MISALIGN  = 4'h4;
parameter EXC_LOAD_ACCESS_FAULT   = 4'h5;
parameter EXC_STORE_ADDR_MISALIGN = 4'h6;
parameter EXC_STORE_ACCESS_FAULT  = 4'h7;
parameter EXC_ECALL_UMODE         = 4'h8;
parameter EXC_ECALL_SMODE         = 4'h9;
parameter EXC_ECALL_MMODE         = 4'hB;
parameter EXC_INSTR_PAGE_FAULT    = 4'hC;
parameter EXC_LOAD_PAGE_FAULT     = 4'hD;
parameter EXC_STORE_PAGE_FAULT    = 4'hF;

// Interrupt Causes
parameter INT_S_SOFTWARE = 4'h1;
parameter INT_M_SOFTWARE = 4'h3;
parameter INT_S_TIMER    = 4'h5;
parameter INT_M_TIMER    = 4'h7;
parameter INT_S_EXTERNAL = 4'h9;
parameter INT_M_EXTERNAL = 4'hB;

// Privilege Levels
parameter PRIV_USER       = 2'b00;
parameter PRIV_SUPERVISOR = 2'b01;
parameter PRIV_MACHINE    = 2'b11;

// CSR Addresses (Machine Mode)
parameter CSR_MVENDORID  = 12'hF11;
parameter CSR_MARCHID    = 12'hF12;
parameter CSR_MIMPID     = 12'hF13;
parameter CSR_MHARTID    = 12'hF14;
parameter CSR_MSTATUS    = 12'h300;
parameter CSR_MISA       = 12'h301;
parameter CSR_MEDELEG    = 12'h302;
parameter CSR_MIDELEG    = 12'h303;
parameter CSR_MIE        = 12'h304;
parameter CSR_MTVEC      = 12'h305;
parameter CSR_MCOUNTEREN = 12'h306;
parameter CSR_MSCRATCH   = 12'h340;
parameter CSR_MEPC       = 12'h341;
parameter CSR_MCAUSE     = 12'h342;
parameter CSR_MTVAL      = 12'h343;
parameter CSR_MIP        = 12'h344;

// CSR Addresses (Supervisor Mode)
parameter CSR_SSTATUS    = 12'h100;
parameter CSR_SEDELEG    = 12'h102;
parameter CSR_SIDELEG    = 12'h103;
parameter CSR_SIE        = 12'h104;
parameter CSR_STVEC      = 12'h105;
parameter CSR_SCOUNTEREN = 12'h106;
parameter CSR_SSCRATCH   = 12'h140;
parameter CSR_SEPC       = 12'h141;
parameter CSR_SCAUSE     = 12'h142;
parameter CSR_STVAL      = 12'h143;
parameter CSR_SIP        = 12'h144;
parameter CSR_SATP       = 12'h180;

// Page Table Entry Bits
parameter PTE_V = 0;  // Valid
parameter PTE_R = 1;  // Read
parameter PTE_W = 2;  // Write  
parameter PTE_X = 3;  // Execute
parameter PTE_U = 4;  // User
parameter PTE_G = 5;  // Global
parameter PTE_A = 6;  // Accessed
parameter PTE_D = 7;  // Dirty

// Memory Map (example)
parameter DRAM_BASE      = 64'h8000_0000;
parameter DRAM_SIZE      = 64'h8000_0000; // 2GB
parameter CLINT_BASE     = 64'h0200_0000;
parameter CLINT_SIZE     = 64'h0001_0000; // 64KB
parameter PLIC_BASE      = 64'h0C00_0000;
parameter PLIC_SIZE      = 64'h0040_0000; // 4MB

// Useful Macros
`define ZERO_EXTEND(x, w) {{(w-$bits(x)){1'b0}}, x}
`define SIGN_EXTEND(x, w) {{(w-$bits(x)){x[$bits(x)-1]}}, x}

// Debug and Verification
`ifdef SIMULATION
    `define ASSERT(cond, msg) \
        assert(cond) else $error("Assertion failed: %s at %m", msg);
        
    `define COVER(cond, msg) \
        cover(cond) $display("Cover hit: %s at %m", msg);
`else
    `define ASSERT(cond, msg)
    `define COVER(cond, msg)
`endif

`endif // RISCV_DEFINES_SV
