//////////////////////////////////////////////////////////////////////////////////
// Testbench: mmu_tb
// Description: Top-level testbench for MMU verification
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module mmu_tb;
    
    import uvm_pkg::*;
    import mmu_pkg::*;
    `include "uvm_macros.svh"
    
    // Clock and reset
    logic clk;
    logic rst_n;
    
    // Generate clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end
    
    // Generate reset
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end
    
    // Interface instantiation
    mmu_if mmu_vif(clk, rst_n);
    
    // DUT instantiation
    mmu dut (
        .clk(clk),
        .rst_n(rst_n),
        
        // CPU interface
        .enable(mmu_vif.enable),
        .virtual_addr(mmu_vif.virtual_addr),
        .physical_addr(mmu_vif.physical_addr),
        .page_fault(mmu_vif.page_fault),
        .access_fault(mmu_vif.access_fault),
        .busy(mmu_vif.busy),
        
        // Control signals
        .is_load(mmu_vif.is_load),
        .is_store(mmu_vif.is_store),
        .is_fetch(mmu_vif.is_fetch),
        .supervisor_mode(mmu_vif.supervisor_mode),
        .satp(mmu_vif.satp),
        
        // Page table walk interface
        .ptw_req(mmu_vif.ptw_req),
        .ptw_addr(mmu_vif.ptw_addr),
        .ptw_rdata(mmu_vif.ptw_rdata),
        .ptw_ready(mmu_vif.ptw_ready)
    );
    
    // Memory model instantiation
    memory_model #(
        .RESPONSE_DELAY(2)
    ) mem_model (
        .clk(clk),
        .rst_n(rst_n),
        .ptw_req(mmu_vif.ptw_req),
        .ptw_addr(mmu_vif.ptw_addr),
        .ptw_rdata(mmu_vif.ptw_rdata),
        .ptw_ready(mmu_vif.ptw_ready)
    );
    
    // UVM test execution
    initial begin
        // Register the virtual interface with UVM config DB
        uvm_config_db#(virtual mmu_if)::set(null, "*", "vif", mmu_vif);
        
        // Set default test timeout
        uvm_top.set_timeout(10ms);
        
        // Run the test
        run_test();
    end
    
    // Dump waveforms
    initial begin
        $dumpfile("mmu_test.vcd");
        $dumpvars(0, mmu_tb);
    end
    
    // Watchdog timer
    initial begin
        #50ms;
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule