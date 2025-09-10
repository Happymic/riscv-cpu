//////////////////////////////////////////////////////////////////////////////////
// Module: csr
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Control and Status Registers (CSR) for RISC-V M-mode
//              Implements basic CSRs: mstatus, mtvec, mepc, mcause, mtval, satp
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module csr (
    input  logic        clk,
    input  logic        rst_n,
    
    // CSR access interface
    input  logic [11:0] csr_addr,           // CSR address
    input  logic        csr_we,             // CSR write enable
    input  logic [31:0] csr_wdata,          // CSR write data
    output logic [31:0] csr_rdata,          // CSR read data
    input  logic [2:0]  csr_op,             // CSR operation (CSRRW, CSRRS, CSRRC)
    
    // Exception interface
    input  logic        exception,          // Exception occurred
    input  logic [31:0] exception_pc,       // PC when exception occurred
    input  logic [31:0] exception_cause,    // Exception cause code
    input  logic [31:0] exception_val,      // Exception value (address/instruction)
    
    // Interrupt interface
    input  logic        ext_interrupt,      // External interrupt
    input  logic        timer_interrupt,    // Timer interrupt
    input  logic        sw_interrupt,       // Software interrupt
    
    // System control outputs
    output logic [31:0] mtvec_o,            // Machine trap vector
    output logic [31:0] mepc_o,             // Machine exception PC
    output logic        mstatus_mie,        // Machine interrupt enable
    output logic [31:0] satp_o              // Supervisor address translation and protection
);

    //////////////////////////////////////////////////////////////////////////////////
    // CSR Addresses
    //////////////////////////////////////////////////////////////////////////////////
    
    localparam CSR_MSTATUS   = 12'h300;     // Machine status register
    localparam CSR_MISA      = 12'h301;     // Machine ISA register
    localparam CSR_MIE       = 12'h304;     // Machine interrupt enable
    localparam CSR_MTVEC     = 12'h305;     // Machine trap vector
    localparam CSR_MSCRATCH  = 12'h340;     // Machine scratch register
    localparam CSR_MEPC      = 12'h341;     // Machine exception PC
    localparam CSR_MCAUSE    = 12'h342;     // Machine cause register
    localparam CSR_MTVAL     = 12'h343;     // Machine trap value
    localparam CSR_MIP       = 12'h344;     // Machine interrupt pending
    localparam CSR_SATP      = 12'h180;     // Supervisor address translation
    
    // CSR operation codes
    localparam CSR_RW = 3'b001;             // Read/Write
    localparam CSR_RS = 3'b010;             // Read/Set bits
    localparam CSR_RC = 3'b011;             // Read/Clear bits
    
    //////////////////////////////////////////////////////////////////////////////////
    // CSR Registers
    //////////////////////////////////////////////////////////////////////////////////
    
    // Machine-mode CSRs
    logic [31:0] mstatus;                   // Machine status
    logic [31:0] misa;                      // Machine ISA
    logic [31:0] mie;                       // Machine interrupt enable
    logic [31:0] mtvec;                     // Machine trap vector
    logic [31:0] mscratch;                  // Machine scratch
    logic [31:0] mepc;                      // Machine exception PC
    logic [31:0] mcause;                    // Machine cause
    logic [31:0] mtval;                     // Machine trap value
    logic [31:0] mip;                       // Machine interrupt pending
    
    // Supervisor-mode CSRs
    logic [31:0] satp;                      // Address translation and protection
    
    //////////////////////////////////////////////////////////////////////////////////
    // MISA Register Configuration (RV32I with M-mode)
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        misa = 32'h0;
        misa[31:30] = 2'b01;    // XLEN = 32
        misa[8] = 1'b1;         // I - RV32I base ISA
        misa[12] = 1'b1;        // M - Integer multiply/divide
        misa[20] = 1'b1;        // U - User mode
        misa[18] = 1'b1;        // S - Supervisor mode
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Interrupt Pending Register
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        mip = 32'h0;
        mip[11] = ext_interrupt;    // MEIP - Machine external interrupt pending
        mip[7] = timer_interrupt;   // MTIP - Machine timer interrupt pending
        mip[3] = sw_interrupt;      // MSIP - Machine software interrupt pending
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // CSR Read Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        csr_rdata = 32'h0;
        
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
            CSR_SATP:     csr_rdata = satp;
            default:      csr_rdata = 32'h0;
        endcase
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // CSR Write Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset CSRs
            mstatus  <= 32'h0;
            mie      <= 32'h0;
            mtvec    <= 32'h0;
            mscratch <= 32'h0;
            mepc     <= 32'h0;
            mcause   <= 32'h0;
            mtval    <= 32'h0;
            satp     <= 32'h0;
        end else begin
            // Handle exception
            if (exception) begin
                mepc   <= exception_pc;
                mcause <= exception_cause;
                mtval  <= exception_val;
                
                // Disable interrupts on exception
                mstatus[3] <= 1'b0;  // MIE bit
                
                // Save previous interrupt enable
                mstatus[7] <= mstatus[3];  // MPIE = MIE
            end
            // Handle CSR write
            else if (csr_we) begin
                case (csr_addr)
                    CSR_MSTATUS: begin
                        case (csr_op)
                            CSR_RW: mstatus <= csr_wdata;
                            CSR_RS: mstatus <= mstatus | csr_wdata;
                            CSR_RC: mstatus <= mstatus & ~csr_wdata;
                        endcase
                    end
                    
                    CSR_MIE: begin
                        case (csr_op)
                            CSR_RW: mie <= csr_wdata;
                            CSR_RS: mie <= mie | csr_wdata;
                            CSR_RC: mie <= mie & ~csr_wdata;
                        endcase
                    end
                    
                    CSR_MTVEC: begin
                        mtvec <= csr_wdata & ~32'h3;  // Align to 4-byte boundary
                    end
                    
                    CSR_MSCRATCH: begin
                        mscratch <= csr_wdata;
                    end
                    
                    CSR_MEPC: begin
                        mepc <= csr_wdata & ~32'h3;  // Align to 4-byte boundary
                    end
                    
                    CSR_MCAUSE: begin
                        mcause <= csr_wdata;
                    end
                    
                    CSR_MTVAL: begin
                        mtval <= csr_wdata;
                    end
                    
                    CSR_SATP: begin
                        satp <= csr_wdata;
                    end
                endcase
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Output Assignments
    //////////////////////////////////////////////////////////////////////////////////
    
    assign mtvec_o = mtvec;
    assign mepc_o = mepc;
    assign mstatus_mie = mstatus[3];  // MIE bit
    assign satp_o = satp;
    
endmodule