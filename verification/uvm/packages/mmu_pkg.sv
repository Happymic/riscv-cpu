//////////////////////////////////////////////////////////////////////////////////
// Package: mmu_pkg
// Description: UVM package for MMU verification
//////////////////////////////////////////////////////////////////////////////////

`ifndef MMU_PKG_SV
`define MMU_PKG_SV

package mmu_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    typedef enum bit [1:0] {
        MMU_LOAD  = 2'b00,
        MMU_STORE = 2'b01,
        MMU_FETCH = 2'b10
    } mmu_op_e;
    
    typedef enum bit {
        USER_MODE = 1'b0,
        SUPERVISOR_MODE = 1'b1
    } privilege_mode_e;
    
    `include "mmu_transaction.sv"
    `include "mmu_config.sv"
    `include "mmu_sequencer.sv"
    `include "mmu_driver.sv"
    `include "mmu_monitor.sv"
    `include "mmu_agent.sv"
    `include "mmu_scoreboard.sv"
    `include "mmu_env.sv"
    `include "mmu_sequences.sv"
    `include "mmu_test.sv"
    
endpackage

`endif