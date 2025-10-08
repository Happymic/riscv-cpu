//////////////////////////////////////////////////////////////////////////////////
// Class: cache_driver
// Description: UVM driver for cache interface
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_DRIVER_SV
`define CACHE_DRIVER_SV

class cache_driver extends uvm_driver #(cache_transaction);
    
    virtual cache_if vif;
    
    `uvm_component_utils(cache_driver)
    
    function new(string name = "cache_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cache_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DRIVER", "Virtual interface not found")
        end
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        reset_interface();
        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask
    
    virtual task reset_interface();
        vif.req <= 1'b0;
        vif.we <= 1'b0;
        vif.addr <= 32'h0;
        vif.wdata <= 32'h0;
        vif.be <= 4'h0;
    endtask
    
    virtual task drive_transaction(cache_transaction txn);
        @(posedge vif.clk);
        vif.req <= 1'b1;
        vif.we <= (txn.operation == WRITE);
        vif.addr <= txn.address;
        vif.wdata <= txn.data;
        vif.be <= txn.byte_enable;
        
        do begin
            @(posedge vif.clk);
        end while (vif.stall);
        
        txn.read_data = vif.rdata;
        txn.hit = vif.hit;
        txn.stall = vif.stall;
        
        vif.req <= 1'b0;
        vif.we <= 1'b0;
        vif.addr <= 32'h0;
        vif.wdata <= 32'h0;
        vif.be <= 4'h0;
        
        `uvm_info("DRIVER", $sformatf("Drove transaction: %s", txn.convert2string()), UVM_HIGH)
    endtask
    
endclass

`endif