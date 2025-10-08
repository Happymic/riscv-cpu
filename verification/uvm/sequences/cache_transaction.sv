//////////////////////////////////////////////////////////////////////////////////
// Class: cache_transaction
// Description: UVM transaction for cache operations
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_TRANSACTION_SV
`define CACHE_TRANSACTION_SV

class cache_transaction extends uvm_sequence_item;
    
    rand cache_op_e     operation;
    rand bit [31:0]     address;
    rand bit [31:0]     data;
    rand bit [3:0]      byte_enable;
    
         bit [31:0]     read_data;
         bit            hit;
         bit            stall;
         
    constraint c_aligned_addr {
        address[1:0] == 2'b00;
    }
    
    constraint c_valid_be {
        byte_enable != 4'h0;
    }
    
    `uvm_object_utils_begin(cache_transaction)
        `uvm_field_enum(cache_op_e, operation, UVM_ALL_ON)
        `uvm_field_int(address, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(byte_enable, UVM_ALL_ON)
        `uvm_field_int(read_data, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(hit, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(stall, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_object_utils_end
    
    function new(string name = "cache_transaction");
        super.new(name);
    endfunction
    
    function string convert2string();
        return $sformatf("op=%s addr=0x%08x data=0x%08x be=0x%x hit=%b stall=%b",
                        operation.name(), address, data, byte_enable, hit, stall);
    endfunction
    
endclass

`endif