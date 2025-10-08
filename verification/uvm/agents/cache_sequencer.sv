//////////////////////////////////////////////////////////////////////////////////
// Class: cache_sequencer
// Description: UVM sequencer for cache transactions
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_SEQUENCER_SV
`define CACHE_SEQUENCER_SV

class cache_sequencer extends uvm_sequencer #(cache_transaction);
    
    `uvm_component_utils(cache_sequencer)
    
    function new(string name = "cache_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
endclass

`endif