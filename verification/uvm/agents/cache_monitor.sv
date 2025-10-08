//////////////////////////////////////////////////////////////////////////////////
// Class: cache_monitor
// Description: UVM monitor for cache interface
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_MONITOR_SV
`define CACHE_MONITOR_SV

class cache_monitor extends uvm_monitor;
    
    virtual cache_if vif;
    uvm_analysis_port #(cache_transaction) ap;
    
    `uvm_component_utils(cache_monitor)
    
    function new(string name = "cache_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cache_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MONITOR", "Virtual interface not found")
        end
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        forever begin
            monitor_transaction();
        end
    endtask
    
    virtual task monitor_transaction();
        cache_transaction txn;
        
        @(posedge vif.clk);
        if (vif.req) begin
            txn = cache_transaction::type_id::create("txn");
            
            txn.operation = vif.we ? WRITE : READ;
            txn.address = vif.addr;
            txn.data = vif.wdata;
            txn.byte_enable = vif.be;
            
            do begin
                @(posedge vif.clk);
            end while (vif.stall);
            
            txn.read_data = vif.rdata;
            txn.hit = vif.hit;
            txn.stall = vif.stall;
            
            `uvm_info("MONITOR", $sformatf("Monitored transaction: %s", txn.convert2string()), UVM_HIGH)
            ap.write(txn);
        end
    endtask
    
endclass

`endif