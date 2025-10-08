//////////////////////////////////////////////////////////////////////////////////
// Package: cache_pkg
// Description: UVM package for L1 D-Cache verification
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_PKG_SV
`define CACHE_PKG_SV

package cache_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    typedef enum bit {
        READ  = 1'b0,
        WRITE = 1'b1
    } cache_op_e;
    
    `include "cache_transaction.sv"
    `include "cache_config.sv"
    `include "cache_sequencer.sv"
    `include "cache_driver.sv"
    `include "cache_monitor.sv"
    `include "cache_agent.sv"
    `include "cache_scoreboard.sv"
    `include "cache_env.sv"
    `include "cache_sequences.sv"
    `include "cache_test.sv"
    
endpackage

`endif