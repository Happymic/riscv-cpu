//////////////////////////////////////////////////////////////////////////////////
// Class: cache_agent
// Description: UVM agent for cache verification
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_AGENT_SV
`define CACHE_AGENT_SV

class cache_agent extends uvm_agent;
    
    cache_driver        driver;
    cache_monitor       monitor;
    cache_sequencer     sequencer;
    cache_config        cfg;
    
    `uvm_component_utils(cache_agent)
    
    function new(string name = "cache_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if (!uvm_config_db#(cache_config)::get(this, "", "cfg", cfg)) begin
            `uvm_info("AGENT", "Config not found, using default", UVM_LOW)
            cfg = cache_config::type_id::create("cfg");
        end
        
        monitor = cache_monitor::type_id::create("monitor", this);
        
        if (cfg.is_active == UVM_ACTIVE) begin
            driver = cache_driver::type_id::create("driver", this);
            sequencer = cache_sequencer::type_id::create("sequencer", this);
        end
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (cfg.is_active == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction
    
endclass

`endif