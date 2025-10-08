//////////////////////////////////////////////////////////////////////////////////
// Class: cache_config
// Description: Configuration object for cache verification
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_CONFIG_SV
`define CACHE_CONFIG_SV

class cache_config extends uvm_object;
    
    bit                 is_active = UVM_ACTIVE;
    bit                 coverage_enable = 1;
    bit                 scoreboard_enable = 1;
    
    int                 cache_size_kb = 32;
    int                 line_size_bytes = 16;
    int                 associativity = 2;
    
    `uvm_object_utils_begin(cache_config)
        `uvm_field_int(is_active, UVM_ALL_ON)
        `uvm_field_int(coverage_enable, UVM_ALL_ON)
        `uvm_field_int(scoreboard_enable, UVM_ALL_ON)
        `uvm_field_int(cache_size_kb, UVM_ALL_ON)
        `uvm_field_int(line_size_bytes, UVM_ALL_ON)
        `uvm_field_int(associativity, UVM_ALL_ON)
    `uvm_object_utils_end
    
    function new(string name = "cache_config");
        super.new(name);
    endfunction
    
endclass

`endif