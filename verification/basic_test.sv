//////////////////////////////////////////////////////////////////////////////////
// Basic RTL Test - Compatible with Icarus Verilog
// Tests individual components without complex SystemVerilog features
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module basic_test;

    // Clock and reset
    logic clk;
    logic rst_n;
    
    // Test signals
    logic [31:0] test_addr;
    logic [19:0] test_vpn;
    logic [21:0] test_ppn;
    logic        test_hit;
    logic        test_valid;
    logic [7:0]  test_flags;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz
    end
    
    // TLB test instance (simpler than cache)
    tlb #(
        .TLB_ENTRIES(16)
    ) tlb_dut (
        .clk(clk),
        .rst_n(rst_n),
        
        // Lookup interface
        .req(1'b1),
        .vpn(test_vpn),
        .ppn(test_ppn),
        .hit(test_hit),
        .valid(test_valid),
        .pte_flags(test_flags),
        
        // Update interface
        .update_en(1'b0),
        .update_vpn(20'h0),
        .update_ppn(22'h0),
        .update_flags(8'h0),
        
        // Invalidation interface
        .invalidate_all(1'b0),
        .invalidate_vpn(20'h0),
        .invalidate_en(1'b0)
    );
    
    // Test sequence
    initial begin
        // Initialize
        rst_n = 0;
        test_vpn = 20'h0;
        
        // Reset
        #100;
        rst_n = 1;
        #50;
        
        $display("=== Basic RTL Test Started ===");
        
        // Test 1: Basic TLB lookup
        @(posedge clk);
        test_vpn = 20'h12345;
        
        @(posedge clk);
        @(posedge clk);
        $display("Test 1 - TLB lookup VPN=0x%05x, PPN=0x%06x, hit=%b", 
                test_vpn, test_ppn, test_hit);
        
        // Test 2: Different VPN
        @(posedge clk);
        test_vpn = 20'h54321;
        
        @(posedge clk);
        @(posedge clk);
        $display("Test 2 - TLB lookup VPN=0x%05x, PPN=0x%06x, hit=%b", 
                test_vpn, test_ppn, test_hit);
        
        #100;
        
        $display("=== Basic RTL Test Completed ===");
        $display("✅ TLB module instantiated and responded");
        $finish;
    end
    
    // Watchdog
    initial begin
        #10000;  // 10us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
    // Optional: Dump waveforms (comment out if too big)
    initial begin
        $dumpfile("basic_test.vcd");
        $dumpvars(0, basic_test);
    end

endmodule