//////////////////////////////////////////////////////////////////////////////////
// Class: cache_env
// Description: UVM environment for cache verification
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_ENV_SV
`define CACHE_ENV_SV

class cache_env extends uvm_env;
    
    cache_agent         agent;
    cache_scoreboard    scoreboard;
    cache_config        cfg;
    
    `uvm_component_utils(cache_env)
    
    function new(string name = "cache_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if (!uvm_config_db#(cache_config)::get(this, "", "cfg", cfg)) begin
            `uvm_info("ENV", "Config not found, using default", UVM_LOW)
            cfg = cache_config::type_id::create("cfg");
        end
        
        agent = cache_agent::type_id::create("agent", this);
        uvm_config_db#(cache_config)::set(this, "agent", "cfg", cfg);
        
        if (cfg.scoreboard_enable) begin
            scoreboard = cache_scoreboard::type_id::create("scoreboard", this);
        end
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (cfg.scoreboard_enable) begin
            agent.monitor.ap.connect(scoreboard.ap_imp);
        end
    endfunction
    
endclass

`endif