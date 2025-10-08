//////////////////////////////////////////////////////////////////////////////////
// Cache UVM Sequences
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_SEQUENCES_SV
`define CACHE_SEQUENCES_SV

// Base sequence
class cache_base_sequence extends uvm_sequence #(cache_transaction);
    
    `uvm_object_utils(cache_base_sequence)
    
    function new(string name = "cache_base_sequence");
        super.new(name);
    endfunction
    
endclass

// Random read/write sequence
class cache_random_sequence extends cache_base_sequence;
    
    int num_transactions = 100;
    
    `uvm_object_utils(cache_random_sequence)
    
    function new(string name = "cache_random_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        repeat(num_transactions) begin
            req = cache_transaction::type_id::create("req");
            start_item(req);
            if (!req.randomize()) begin
                `uvm_error("SEQ", "Randomization failed")
            end
            finish_item(req);
        end
    endtask
    
endclass

// Sequential read sequence
class cache_sequential_read_sequence extends cache_base_sequence;
    
    bit [31:0] start_addr = 32'h1000;
    int num_reads = 64;
    
    `uvm_object_utils(cache_sequential_read_sequence)
    
    function new(string name = "cache_sequential_read_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        for (int i = 0; i < num_reads; i++) begin
            req = cache_transaction::type_id::create("req");
            start_item(req);
            req.operation = READ;
            req.address = start_addr + (i * 4);
            req.byte_enable = 4'hF;
            req.data = 32'h0;
            finish_item(req);
        end
    endtask
    
endclass

// Write-then-read sequence
class cache_write_read_sequence extends cache_base_sequence;
    
    bit [31:0] base_addr = 32'h2000;
    int num_pairs = 32;
    
    `uvm_object_utils(cache_write_read_sequence)
    
    function new(string name = "cache_write_read_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        for (int i = 0; i < num_pairs; i++) begin
            bit [31:0] addr = base_addr + (i * 4);
            bit [31:0] data = $random();
            
            // Write
            req = cache_transaction::type_id::create("req");
            start_item(req);
            req.operation = WRITE;
            req.address = addr;
            req.data = data;
            req.byte_enable = 4'hF;
            finish_item(req);
            
            // Read back
            req = cache_transaction::type_id::create("req");
            start_item(req);
            req.operation = READ;
            req.address = addr;
            req.byte_enable = 4'hF;
            req.data = 32'h0;
            finish_item(req);
        end
    endtask
    
endclass

// Cache stress sequence (mix of operations)
class cache_stress_sequence extends cache_base_sequence;
    
    int num_transactions = 500;
    bit [31:0] addr_range_start = 32'h0;
    bit [31:0] addr_range_end = 32'h10000;
    
    `uvm_object_utils(cache_stress_sequence)
    
    function new(string name = "cache_stress_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        repeat(num_transactions) begin
            req = cache_transaction::type_id::create("req");
            start_item(req);
            if (!req.randomize() with {
                address >= addr_range_start;
                address < addr_range_end;
            }) begin
                `uvm_error("SEQ", "Randomization failed")
            end
            finish_item(req);
        end
    endtask
    
endclass

`endif