//////////////////////////////////////////////////////////////////////////////////
// Cache UVM Tests
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_TEST_SV
`define CACHE_TEST_SV

// Base test class
class cache_base_test extends uvm_test;
    
    cache_env           env;
    cache_config        cfg;
    
    `uvm_component_utils(cache_base_test)
    
    function new(string name = "cache_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        cfg = cache_config::type_id::create("cfg");
        cfg.is_active = UVM_ACTIVE;
        cfg.coverage_enable = 1;
        cfg.scoreboard_enable = 1;
        
        uvm_config_db#(cache_config)::set(this, "*", "cfg", cfg);
        
        env = cache_env::type_id::create("env", this);
    endfunction
    
    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
    
endclass

// Random test
class cache_random_test extends cache_base_test;
    
    `uvm_component_utils(cache_random_test)
    
    function new(string name = "cache_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        cache_random_sequence seq;
        
        phase.raise_objection(this);
        
        seq = cache_random_sequence::type_id::create("seq");
        seq.num_transactions = 200;
        seq.start(env.agent.sequencer);
        
        phase.drop_objection(this);
    endtask
    
endclass

// Sequential read test
class cache_sequential_test extends cache_base_test;
    
    `uvm_component_utils(cache_sequential_test)
    
    function new(string name = "cache_sequential_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        cache_sequential_read_sequence seq;
        
        phase.raise_objection(this);
        
        seq = cache_sequential_read_sequence::type_id::create("seq");
        seq.start_addr = 32'h1000;
        seq.num_reads = 128;
        seq.start(env.agent.sequencer);
        
        phase.drop_objection(this);
    endtask
    
endclass

// Write-read test
class cache_write_read_test extends cache_base_test;
    
    `uvm_component_utils(cache_write_read_test)
    
    function new(string name = "cache_write_read_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        cache_write_read_sequence seq;
        
        phase.raise_objection(this);
        
        seq = cache_write_read_sequence::type_id::create("seq");
        seq.base_addr = 32'h2000;
        seq.num_pairs = 64;
        seq.start(env.agent.sequencer);
        
        phase.drop_objection(this);
    endtask
    
endclass

// Stress test
class cache_stress_test extends cache_base_test;
    
    `uvm_component_utils(cache_stress_test)
    
    function new(string name = "cache_stress_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        cache_stress_sequence seq;
        
        phase.raise_objection(this);
        
        seq = cache_stress_sequence::type_id::create("seq");
        seq.num_transactions = 1000;
        seq.addr_range_start = 32'h0;
        seq.addr_range_end = 32'h100000;
        seq.start(env.agent.sequencer);
        
        phase.drop_objection(this);
    endtask
    
endclass

`endif