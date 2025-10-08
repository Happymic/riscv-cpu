//////////////////////////////////////////////////////////////////////////////////
// Interface: cache_if
// Description: Interface for L1 D-Cache verification
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_IF_SV
`define CACHE_IF_SV

interface cache_if(input logic clk, input logic rst_n);
    
    // CPU interface signals
    logic        req;
    logic        we;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [3:0]  be;
    logic [31:0] rdata;
    logic        hit;
    logic        stall;
    
    // L2 cache interface signals
    logic        l2_req;
    logic        l2_we;
    logic [31:0] l2_addr;
    logic [127:0] l2_wdata;
    logic [127:0] l2_rdata;
    logic        l2_valid;
    
    // Clocking blocks for synchronous driving and sampling
    clocking driver_cb @(posedge clk);
        default input #1step output #1;
        output req, we, addr, wdata, be;
        input rdata, hit, stall;
    endclocking
    
    clocking monitor_cb @(posedge clk);
        default input #1step;
        input req, we, addr, wdata, be, rdata, hit, stall;
    endclocking
    
    // L2 cache model clocking block
    clocking l2_cb @(posedge clk);
        default input #1step output #1;
        input l2_req, l2_we, l2_addr, l2_wdata;
        output l2_rdata, l2_valid;
    endclocking
    
    // Modports
    modport driver_mp (clocking driver_cb, input clk, rst_n);
    modport monitor_mp (clocking monitor_cb, input clk, rst_n);
    modport l2_mp (clocking l2_cb, input clk, rst_n);
    modport dut_mp (
        input clk, rst_n, req, we, addr, wdata, be, l2_rdata, l2_valid,
        output rdata, hit, stall, l2_req, l2_we, l2_addr, l2_wdata
    );
    
    // Assertions
    property no_req_during_reset;
        @(posedge clk) !rst_n |-> !req;
    endproperty
    
    property stall_during_miss;
        @(posedge clk) (req && !hit) |-> stall;
    endproperty
    
    property valid_address_alignment;
        @(posedge clk) req |-> (addr[1:0] == 2'b00);
    endproperty
    
    assert_no_req_during_reset: assert property(no_req_during_reset)
        else `uvm_error("CACHE_IF", "Request asserted during reset")
    
    assert_stall_during_miss: assert property(stall_during_miss)
        else `uvm_error("CACHE_IF", "Cache miss should cause stall")
    
    assert_valid_address: assert property(valid_address_alignment)
        else `uvm_error("CACHE_IF", "Address must be word-aligned")
    
endinterface

`endif