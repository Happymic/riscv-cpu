// Control and Status Register File (CSR)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Scope:
// - Implements a subset of privileged CSRs for Machine and Supervisor modes.
// - Provides read/modify/write via csr_op, and basic trap/interrupt entry.
//
// Interface:
// - csr_addr/csr_wdata/csr_rdata: address and data ports
// - csr_op/csr_valid           : 01=write, 10=set, 11=clear (00=none)
// - exception/interrupt inputs : trigger trap entry and context save to mepc/mcause
// - privilege_mode/satp/sum/mxr: exported status fields
//
// Notes:
// - This is not a full privileged spec implementation (e.g., delegation,
//   timer/clint/plc wiring not included). It is a functional baseline for
//   learning and basic software bring-up.
// -----------------------------------------------------------------------------

module csr #(
    parameter XLEN = 64
) (
    input  logic clk,
    input  logic rst_n,
    
    // CSR access interface
    input  logic [11:0]     csr_addr,
    input  logic [XLEN-1:0] csr_wdata,
    output logic [XLEN-1:0] csr_rdata,
    input  logic [1:0]      csr_op, // 00: none, 01: write, 10: set, 11: clear
    input  logic            csr_valid,
    
    // Exception and interrupt interface
    input  logic            exception,
    input  logic [XLEN-1:0] exception_pc,
    input  logic [3:0]      exception_cause,
    input  logic            interrupt,
    input  logic [3:0]      interrupt_cause,
    
    // Privilege mode
    output logic [1:0]      privilege_mode, // 00: User, 01: Supervisor, 11: Machine
    
    // Memory management
    output logic [XLEN-1:0] satp,
    output logic            sum,
    output logic            mxr
);

    // CSR addresses (Machine mode)
    localparam CSR_MSTATUS   = 12'h300;
    localparam CSR_MISA      = 12'h301;
    localparam CSR_MIE       = 12'h304;
    localparam CSR_MTVEC     = 12'h305;
    localparam CSR_MSCRATCH  = 12'h340;
    localparam CSR_MEPC      = 12'h341;
    localparam CSR_MCAUSE    = 12'h342;
    localparam CSR_MTVAL     = 12'h343;
    localparam CSR_MIP       = 12'h344;
    
    // Supervisor mode CSRs
    localparam CSR_SSTATUS   = 12'h100;
    localparam CSR_SIE       = 12'h104;
    localparam CSR_STVEC     = 12'h105;
    localparam CSR_SSCRATCH  = 12'h140;
    localparam CSR_SEPC      = 12'h141;
    localparam CSR_SCAUSE    = 12'h142;
    localparam CSR_STVAL     = 12'h143;
    localparam CSR_SIP       = 12'h144;
    localparam CSR_SATP      = 12'h180;

    // CSR storage
    logic [XLEN-1:0] mstatus;
    logic [XLEN-1:0] misa;
    logic [XLEN-1:0] mie;
    logic [XLEN-1:0] mtvec;
    logic [XLEN-1:0] mscratch;
    logic [XLEN-1:0] mepc;
    logic [XLEN-1:0] mcause;
    logic [XLEN-1:0] mtval;
    logic [XLEN-1:0] mip;
    
    logic [XLEN-1:0] sstatus;
    logic [XLEN-1:0] sie;
    logic [XLEN-1:0] stvec;
    logic [XLEN-1:0] sscratch;
    logic [XLEN-1:0] sepc;
    logic [XLEN-1:0] scause;
    logic [XLEN-1:0] stval;
    logic [XLEN-1:0] sip;
    logic [XLEN-1:0] satp_reg;

    // Privilege mode register
    logic [1:0] priv_mode;
    assign privilege_mode = priv_mode;

    // Memory management outputs
    assign satp = satp_reg;
    assign sum = mstatus[18]; // SUM bit
    assign mxr = mstatus[19]; // MXR bit

    // CSR read logic
    always_comb begin
        case (csr_addr)
            CSR_MSTATUS:  csr_rdata = mstatus;
            CSR_MISA:     csr_rdata = misa;
            CSR_MIE:      csr_rdata = mie;
            CSR_MTVEC:    csr_rdata = mtvec;
            CSR_MSCRATCH: csr_rdata = mscratch;
            CSR_MEPC:     csr_rdata = mepc;
            CSR_MCAUSE:   csr_rdata = mcause;
            CSR_MTVAL:    csr_rdata = mtval;
            CSR_MIP:      csr_rdata = mip;
            CSR_SSTATUS:  csr_rdata = sstatus;
            CSR_SIE:      csr_rdata = sie;
            CSR_STVEC:    csr_rdata = stvec;
            CSR_SSCRATCH: csr_rdata = sscratch;
            CSR_SEPC:     csr_rdata = sepc;
            CSR_SCAUSE:   csr_rdata = scause;
            CSR_STVAL:    csr_rdata = stval;
            CSR_SIP:      csr_rdata = sip;
            CSR_SATP:     csr_rdata = satp_reg;
            default:      csr_rdata = '0;
        endcase
    end

    // CSR write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus <= 64'h0000_0000_0000_1800; // Initial MPP = 11 (Machine mode)
            misa <= 64'h8000_0000_0014_112D; // RV64IMAFDC
            mie <= '0;
            mtvec <= '0;
            mscratch <= '0;
            mepc <= '0;
            mcause <= '0;
            mtval <= '0;
            mip <= '0;
            sstatus <= '0;
            sie <= '0;
            stvec <= '0;
            sscratch <= '0;
            sepc <= '0;
            scause <= '0;
            stval <= '0;
            sip <= '0;
            satp_reg <= '0;
            priv_mode <= 2'b11; // Start in Machine mode
        end else begin
            // Handle exceptions and interrupts
            if (exception || interrupt) begin
                if (priv_mode <= 2'b01) begin // Trap to machine mode
                    mepc <= exception_pc;
                    mcause <= interrupt ? {1'b1, 59'b0, interrupt_cause} : 
                                        {1'b0, 59'b0, exception_cause};
                    mstatus[12:11] <= priv_mode; // Save previous privilege in MPP
                    mstatus[7] <= mstatus[3]; // Save MIE to MPIE
                    mstatus[3] <= 1'b0; // Clear MIE
                    priv_mode <= 2'b11; // Enter machine mode
                end
            end
            
            // CSR write operations
            if (csr_valid) begin
                case (csr_op)
                    2'b01: begin // Write
                        case (csr_addr)
                            CSR_MSTATUS:  mstatus <= csr_wdata;
                            CSR_MIE:      mie <= csr_wdata;
                            CSR_MTVEC:    mtvec <= csr_wdata;
                            CSR_MSCRATCH: mscratch <= csr_wdata;
                            CSR_MEPC:     mepc <= csr_wdata;
                            CSR_MCAUSE:   mcause <= csr_wdata;
                            CSR_MTVAL:    mtval <= csr_wdata;
                            CSR_SSTATUS:  sstatus <= csr_wdata;
                            CSR_SIE:      sie <= csr_wdata;
                            CSR_STVEC:    stvec <= csr_wdata;
                            CSR_SSCRATCH: sscratch <= csr_wdata;
                            CSR_SEPC:     sepc <= csr_wdata;
                            CSR_SCAUSE:   scause <= csr_wdata;
                            CSR_STVAL:    stval <= csr_wdata;
                            CSR_SATP:     satp_reg <= csr_wdata;
                        endcase
                    end
                    2'b10: begin // Set bits
                        case (csr_addr)
                            CSR_MSTATUS:  mstatus <= mstatus | csr_wdata;
                            CSR_MIE:      mie <= mie | csr_wdata;
                            CSR_SSTATUS:  sstatus <= sstatus | csr_wdata;
                            CSR_SIE:      sie <= sie | csr_wdata;
                        endcase
                    end
                    2'b11: begin // Clear bits
                        case (csr_addr)
                            CSR_MSTATUS:  mstatus <= mstatus & ~csr_wdata;
                            CSR_MIE:      mie <= mie & ~csr_wdata;
                            CSR_SSTATUS:  sstatus <= sstatus & ~csr_wdata;
                            CSR_SIE:      sie <= sie & ~csr_wdata;
                        endcase
                    end
                endcase
            end
        end
    end

endmodule
