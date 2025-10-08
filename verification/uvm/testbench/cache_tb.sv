//////////////////////////////////////////////////////////////////////////////////
// Testbench: cache_tb
// Description: Top-level testbench for cache verification
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module cache_tb;
    
    import uvm_pkg::*;
    import cache_pkg::*;
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
    cache_if cache_vif(clk, rst_n);
    
    // DUT instantiation
    l1_dcache #(
        .CACHE_SIZE_KB(32),
        .LINE_SIZE_BYTES(16),
        .ASSOCIATIVITY(2)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        
        // CPU interface
        .req(cache_vif.req),
        .we(cache_vif.we),
        .addr(cache_vif.addr),
        .wdata(cache_vif.wdata),
        .be(cache_vif.be),
        .rdata(cache_vif.rdata),
        .hit(cache_vif.hit),
        .stall(cache_vif.stall),
        
        // L2 cache interface
        .l2_req(cache_vif.l2_req),
        .l2_we(cache_vif.l2_we),
        .l2_addr(cache_vif.l2_addr),
        .l2_wdata(cache_vif.l2_wdata),
        .l2_rdata(cache_vif.l2_rdata),
        .l2_valid(cache_vif.l2_valid)
    );
    
    // L2 cache model instantiation
    l2_cache_model #(
        .RESPONSE_DELAY(3)
    ) l2_model (
        .clk(clk),
        .rst_n(rst_n),
        .l2_req(cache_vif.l2_req),
        .l2_we(cache_vif.l2_we),
        .l2_addr(cache_vif.l2_addr),
        .l2_wdata(cache_vif.l2_wdata),
        .l2_rdata(cache_vif.l2_rdata),
        .l2_valid(cache_vif.l2_valid)
    );
    
    // UVM test execution
    initial begin
        // Register the virtual interface with UVM config DB
        uvm_config_db#(virtual cache_if)::set(null, "*", "vif", cache_vif);
        
        // Set default test timeout
        uvm_top.set_timeout(10ms);
        
        // Run the test
        run_test();
    end
    
    // Dump waveforms
    initial begin
        $dumpfile("cache_test.vcd");
        $dumpvars(0, cache_tb);
    end
    
    // Watchdog timer
    initial begin
        #50ms;
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule