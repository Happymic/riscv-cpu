//////////////////////////////////////////////////////////////////////////////////
// Simple Cache Test - No UVM Required
// Just basic SystemVerilog to test the cache module
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module simple_cache_test;

    // Clock and reset
    logic clk;
    logic rst_n;
    
    // DUT signals
    logic        req;
    logic        we;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [3:0]  be;
    logic [31:0] rdata;
    logic        hit;
    logic        stall;
    
    // L2 interface (simplified)
    logic        l2_req;
    logic        l2_we;
    logic [31:0] l2_addr;
    logic [127:0] l2_wdata;
    logic [127:0] l2_rdata;
    logic        l2_valid;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz
    end
    
    // DUT instantiation
    l1_dcache #(
        .CACHE_SIZE_KB(32),
        .LINE_SIZE_BYTES(16),
        .ASSOCIATIVITY(2)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req(req),
        .we(we),
        .addr(addr),
        .wdata(wdata),
        .be(be),
        .rdata(rdata),
        .hit(hit),
        .stall(stall),
        .l2_req(l2_req),
        .l2_we(l2_we),
        .l2_addr(l2_addr),
        .l2_wdata(l2_wdata),
        .l2_rdata(l2_rdata),
        .l2_valid(l2_valid)
    );
    
    // Simple L2 response (immediate for testing)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            l2_valid <= 1'b0;
            l2_rdata <= 128'h0;
        end else begin
            l2_valid <= l2_req;  // Respond immediately
            if (l2_req && !l2_we) begin
                // Return some test data
                l2_rdata <= {4{l2_addr}};
            end
        end
    end
    
    // Test sequence
    initial begin
        // Initialize
        rst_n = 0;
        req = 0;
        we = 0;
        addr = 32'h0;
        wdata = 32'h0;
        be = 4'h0;
        
        // Reset
        #100;
        rst_n = 1;
        #50;
        
        $display("=== Simple Cache Test Started ===");
        
        // Test 1: Simple read
        @(posedge clk);
        req = 1;
        we = 0;
        addr = 32'h1000;
        be = 4'hF;
        
        // Wait for response
        wait(!stall);
        @(posedge clk);
        $display("Test 1 - Read addr=0x%08x, data=0x%08x, hit=%b", addr, rdata, hit);
        
        req = 0;
        #20;
        
        // Test 2: Write
        @(posedge clk);
        req = 1;
        we = 1;
        addr = 32'h1004;
        wdata = 32'hDEADBEEF;
        be = 4'hF;
        
        wait(!stall);
        @(posedge clk);
        $display("Test 2 - Write addr=0x%08x, data=0x%08x, hit=%b", addr, wdata, hit);
        
        req = 0;
        #20;
        
        // Test 3: Read back
        @(posedge clk);
        req = 1;
        we = 0;
        addr = 32'h1004;
        be = 4'hF;
        
        wait(!stall);
        @(posedge clk);
        $display("Test 3 - Read back addr=0x%08x, data=0x%08x, hit=%b", addr, rdata, hit);
        
        req = 0;
        #100;
        
        $display("=== Simple Cache Test Completed ===");
        $finish;
    end
    
    // Watchdog
    initial begin
        #50000;  // 50us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
    // Dump waveforms
    initial begin
        $dumpfile("simple_cache_test.vcd");
        $dumpvars(0, simple_cache_test);
    end

endmodule