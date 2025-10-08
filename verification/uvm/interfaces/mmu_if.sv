//////////////////////////////////////////////////////////////////////////////////
// Interface: mmu_if
// Description: Interface for MMU verification
//////////////////////////////////////////////////////////////////////////////////

`ifndef MMU_IF_SV
`define MMU_IF_SV

interface mmu_if(input logic clk, input logic rst_n);
    
    // MMU control signals
    logic        enable;
    logic [31:0] virtual_addr;
    logic [31:0] physical_addr;
    logic        page_fault;
    logic        access_fault;
    logic        busy;
    
    // Operation type signals
    logic        is_load;
    logic        is_store;
    logic        is_fetch;
    logic        supervisor_mode;
    logic [31:0] satp;
    
    // Page table walk interface
    logic        ptw_req;
    logic [31:0] ptw_addr;
    logic [31:0] ptw_rdata;
    logic        ptw_ready;
    
    // Clocking blocks
    clocking driver_cb @(posedge clk);
        default input #1step output #1;
        output enable, virtual_addr, is_load, is_store, is_fetch, supervisor_mode, satp;
        output ptw_rdata, ptw_ready;
        input physical_addr, page_fault, access_fault, busy, ptw_req, ptw_addr;
    endclocking
    
    clocking monitor_cb @(posedge clk);
        default input #1step;
        input enable, virtual_addr, physical_addr, page_fault, access_fault, busy;
        input is_load, is_store, is_fetch, supervisor_mode, satp;
        input ptw_req, ptw_addr, ptw_rdata, ptw_ready;
    endclocking
    
    // Modports
    modport driver_mp (clocking driver_cb, input clk, rst_n);
    modport monitor_mp (clocking monitor_cb, input clk, rst_n);
    modport dut_mp (
        input clk, rst_n, enable, virtual_addr, is_load, is_store, is_fetch,
              supervisor_mode, satp, ptw_rdata, ptw_ready,
        output physical_addr, page_fault, access_fault, busy, ptw_req, ptw_addr
    );
    
    // Assertions
    property no_operation_during_reset;
        @(posedge clk) !rst_n |-> (!is_load && !is_store && !is_fetch);
    endproperty
    
    property exclusive_operations;
        @(posedge clk) $onehot0({is_load, is_store, is_fetch});
    endproperty
    
    property busy_during_page_walk;
        @(posedge clk) ptw_req |-> busy;
    endproperty
    
    assert_no_op_during_reset: assert property(no_operation_during_reset)
        else `uvm_error("MMU_IF", "Operation asserted during reset")
    
    assert_exclusive_ops: assert property(exclusive_operations)
        else `uvm_error("MMU_IF", "Multiple operations asserted simultaneously")
    
    assert_busy_during_ptw: assert property(busy_during_page_walk)
        else `uvm_error("MMU_IF", "MMU should be busy during page table walk")
    
endinterface

`endif