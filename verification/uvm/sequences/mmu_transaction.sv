//////////////////////////////////////////////////////////////////////////////////
// Class: mmu_transaction
// Description: UVM transaction for MMU operations
//////////////////////////////////////////////////////////////////////////////////

`ifndef MMU_TRANSACTION_SV
`define MMU_TRANSACTION_SV

class mmu_transaction extends uvm_sequence_item;
    
    rand bit             enable;
    rand bit [31:0]      virtual_addr;
    rand mmu_op_e        operation;
    rand privilege_mode_e mode;
    rand bit [31:0]      satp;
    
         bit [31:0]      physical_addr;
         bit             page_fault;
         bit             access_fault;
         bit             busy;
    
    constraint c_valid_satp {
        satp[31] == 1'b1;     // Sv32 mode enabled
        satp[30:22] == 9'h0;  // Reserved bits
    }
    
    constraint c_aligned_fetch {
        operation == MMU_FETCH -> virtual_addr[1:0] == 2'b00;
    }
    
    constraint c_reasonable_addr {
        virtual_addr < 32'h80000000;  // Keep in reasonable range
    }
    
    `uvm_object_utils_begin(mmu_transaction)
        `uvm_field_int(enable, UVM_ALL_ON)
        `uvm_field_int(virtual_addr, UVM_ALL_ON)
        `uvm_field_enum(mmu_op_e, operation, UVM_ALL_ON)
        `uvm_field_enum(privilege_mode_e, mode, UVM_ALL_ON)
        `uvm_field_int(satp, UVM_ALL_ON)
        `uvm_field_int(physical_addr, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(page_fault, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(access_fault, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(busy, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_object_utils_end
    
    function new(string name = "mmu_transaction");
        super.new(name);
    endfunction
    
    function string convert2string();
        return $sformatf("en=%b va=0x%08x op=%s mode=%s satp=0x%08x -> pa=0x%08x pf=%b af=%b busy=%b",
                        enable, virtual_addr, operation.name(), mode.name(), satp,
                        physical_addr, page_fault, access_fault, busy);
    endfunction
    
endclass

`endif