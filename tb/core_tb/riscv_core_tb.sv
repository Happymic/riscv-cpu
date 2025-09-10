// RISC-V Core Testbench
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// What this TB provides:
// - Clock/reset generation (100MHz clock, 100ns reset pulse).
// - Simple instruction/data memory models backed by arrays.
// - DUT instantiation and basic run-loop that executes for 1000 cycles.
// - Waveform dumping to riscv_core_tb.vcd for inspection.
//
// How to use:
// - Put a program in test_program.hex (32-bit words, hex) to be loaded into imem.
// - Run scripts/simulation/run_sim.sh to compile and execute.
// - Inspect riscv_core_tb.vcd with a waveform viewer (e.g., GTKWave).
//
// Notes:
// - The top riscv_top currently is a skeleton; to observe meaningful activity,
//   add pipeline stages and wiring in rtl/core/riscv_top.sv.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module riscv_core_tb;

    // Clock and reset
    logic clk;
    logic rst_n;
    
    // Memory interfaces
    logic [63:0] imem_addr;
    logic [31:0] imem_data;
    logic        imem_valid;
    
    logic [63:0] dmem_addr;
    logic [63:0] dmem_wdata;
    logic [63:0] dmem_rdata;
    logic        dmem_we;
    logic [7:0]  dmem_be;
    logic        dmem_valid;
    
    // Clock generation (Verilator compatible)
    initial clk = 0;
    /* verilator lint_off STMTDLY */
    always #5 clk = ~clk; // 100MHz clock
    /* verilator lint_on STMTDLY */
    
    // Reset generation
    initial begin
        rst_n = 0;
        /* verilator lint_off STMTDLY */
        #100;
        /* verilator lint_on STMTDLY */
        rst_n = 1;
    end
    
    // DUT instantiation
    riscv_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .imem_valid(imem_valid),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_we(dmem_we),
        .dmem_be(dmem_be),
        .dmem_valid(dmem_valid)
    );
    
    // Simple memory model
    logic [31:0] imem [0:4095];
    logic [63:0] dmem [0:4095];
    
    // Instruction memory
    assign imem_data = imem[imem_addr[13:2]];
    assign imem_valid = 1'b1;
    
    // Data memory
    assign dmem_rdata = dmem[dmem_addr[14:3]];
    assign dmem_valid = 1'b1;
    
    always_ff @(posedge clk) begin
        if (dmem_we) begin
            for (int i = 0; i < 8; i++) begin
                if (dmem_be[i]) begin
                    dmem[dmem_addr[14:3]][i*8 +: 8] <= dmem_wdata[i*8 +: 8];
                end
            end
        end
    end
    
    // Test stimulus
    int cycle_count;
    initial begin
        // Simple test program - just NOPs
        for (int i = 0; i < 1024; i++) begin
            imem[i] = 32'h00000013; // ADDI x0, x0, 0 (NOP)
        end
        
        cycle_count = 0;
    end
    
    // Main test loop
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count >= 1000) begin
                $display("Test completed after %0d cycles", cycle_count);
                $finish;
            end
        end
    end
    
    // Waveform dumping
    initial begin
        $dumpfile("riscv_core_tb.vcd");
        $dumpvars(0, riscv_core_tb);
    end

endmodule
