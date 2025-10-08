//////////////////////////////////////////////////////////////////////////////////
// Class: cache_scoreboard
// Description: UVM scoreboard for cache verification
//////////////////////////////////////////////////////////////////////////////////

`ifndef CACHE_SCOREBOARD_SV
`define CACHE_SCOREBOARD_SV

class cache_scoreboard extends uvm_scoreboard;
    
    uvm_analysis_imp #(cache_transaction, cache_scoreboard) ap_imp;
    
    int transactions_count;
    int hits_count;
    int misses_count;
    
    `uvm_component_utils(cache_scoreboard)
    
    function new(string name = "cache_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_imp = new("ap_imp", this);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction
    
    virtual function void write(cache_transaction txn);
        transactions_count++;
        
        if (txn.hit) begin
            hits_count++;
            `uvm_info("SCOREBOARD", $sformatf("Cache HIT: %s", txn.convert2string()), UVM_MEDIUM)
        end else begin
            misses_count++;
            `uvm_info("SCOREBOARD", $sformatf("Cache MISS: %s", txn.convert2string()), UVM_MEDIUM)
        end
        
        check_transaction(txn);
    endfunction
    
    virtual function void check_transaction(cache_transaction txn);
        if (txn.operation == READ && txn.hit && txn.read_data === 32'hx) begin
            `uvm_error("SCOREBOARD", "Read hit returned unknown data")
        end
    endfunction
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCOREBOARD", $sformatf("Total transactions: %0d", transactions_count), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Cache hits: %0d (%.1f%%)", hits_count, 
                 100.0 * hits_count / transactions_count), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Cache misses: %0d (%.1f%%)", misses_count,
                 100.0 * misses_count / transactions_count), UVM_LOW)
    endfunction
    
endclass

`endif