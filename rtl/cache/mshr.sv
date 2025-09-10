// Miss Status Holding Registers (MSHR)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Track in-flight cache misses so subsequent accesses to the same block can
//   be coalesced, and memory responses can be matched back to requesters.
//
// Interfaces:
// - Allocation: alloc_addr/alloc_valid -> alloc_ready, alloc_entry_id.
// - Memory: mem_req/mem_addr initiate miss fetches; resp_* matches data back.
// - Deallocation: free an entry once consumers are satisfied.
// - Coalescing check: coal_* probes if an address is already pending.
//
// Model:
// - Simple priority encoder chooses a pending entry to send to memory.
// - Data buffer holds the returned block until deallocation.
// - BLOCK_SIZE is in bytes; addresses are aligned to block boundaries.
// -----------------------------------------------------------------------------

module mshr #(
    parameter XLEN = 64,
    parameter NUM_ENTRIES = 8,
    parameter BLOCK_SIZE = 64
) (
    input  logic clk,
    input  logic rst_n,
    
    // Allocation interface
    input  logic [XLEN-1:0] alloc_addr,
    input  logic            alloc_valid,
    output logic            alloc_ready,
    output logic [2:0]      alloc_entry_id,
    
    // Deallocation interface
    input  logic [2:0]      dealloc_entry_id,
    input  logic            dealloc_valid,
    
    // Memory request interface
    output logic [XLEN-1:0] mem_addr,
    output logic            mem_req,
    input  logic            mem_ack,
    
    // Memory response interface
    input  logic [2:0]      resp_entry_id,
    input  logic [BLOCK_SIZE*8-1:0] resp_data,
    input  logic            resp_valid,
    
    // Miss handling status
    output logic [NUM_ENTRIES-1:0] entry_valid,
    output logic [NUM_ENTRIES-1:0] entry_pending,
    output logic [NUM_ENTRIES-1:0] [XLEN-1:0] entry_addr,
    output logic [NUM_ENTRIES-1:0] [BLOCK_SIZE*8-1:0] entry_data,
    
    // Coalescing interface
    input  logic [XLEN-1:0] coal_addr,
    input  logic            coal_check,
    output logic            coal_hit,
    output logic [2:0]      coal_entry_id
);

    localparam BLOCK_OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam ENTRY_ID_BITS = $clog2(NUM_ENTRIES);

    // MSHR entry structure
    typedef struct packed {
        logic valid;
        logic pending;
        logic [XLEN-BLOCK_OFFSET_BITS-1:0] block_addr;
        logic [BLOCK_SIZE*8-1:0] data;
    } mshr_entry_t;

    mshr_entry_t mshr_entries [NUM_ENTRIES-1:0];

    // Entry allocation logic
    logic [NUM_ENTRIES-1:0] entry_free;
    logic [ENTRY_ID_BITS-1:0] free_entry_id;
    logic found_free_entry;

    // Find free entry
    always_comb begin
        found_free_entry = 1'b0;
        free_entry_id = 0;
        for (int i = 0; i < NUM_ENTRIES; i++) begin
            entry_free[i] = !mshr_entries[i].valid;
            if (!mshr_entries[i].valid && !found_free_entry) begin
                free_entry_id = i;
                found_free_entry = 1'b1;
            end
        end
    end

    assign alloc_ready = found_free_entry;
    assign alloc_entry_id = free_entry_id;

    // Coalescing logic - check if address is already being handled
    logic [XLEN-BLOCK_OFFSET_BITS-1:0] coal_block_addr;
    assign coal_block_addr = coal_addr[XLEN-1:BLOCK_OFFSET_BITS];

    always_comb begin
        coal_hit = 1'b0;
        coal_entry_id = 0;
        
        for (int i = 0; i < NUM_ENTRIES; i++) begin
            if (mshr_entries[i].valid && 
                mshr_entries[i].block_addr == coal_block_addr) begin
                coal_hit = 1'b1;
                coal_entry_id = i;
                break;
            end
        end
    end

    // Memory request arbitration
    logic [NUM_ENTRIES-1:0] req_priority;
    logic [ENTRY_ID_BITS-1:0] selected_entry;
    logic found_pending;

    // Simple priority encoder for memory requests
    always_comb begin
        found_pending = 1'b0;
        selected_entry = 0;
        
        for (int i = 0; i < NUM_ENTRIES; i++) begin
            req_priority[i] = mshr_entries[i].valid && mshr_entries[i].pending;
            if (mshr_entries[i].valid && mshr_entries[i].pending && !found_pending) begin
                selected_entry = i;
                found_pending = 1'b1;
            end
        end
    end

    assign mem_req = found_pending;
    assign mem_addr = {mshr_entries[selected_entry].block_addr, {BLOCK_OFFSET_BITS{1'b0}}};

    // Output assignments
    genvar i;
    generate
        for (i = 0; i < NUM_ENTRIES; i++) begin : gen_outputs
            assign entry_valid[i] = mshr_entries[i].valid;
            assign entry_pending[i] = mshr_entries[i].pending;
            assign entry_addr[i] = {mshr_entries[i].block_addr, {BLOCK_OFFSET_BITS{1'b0}}};
            assign entry_data[i] = mshr_entries[i].data;
        end
    endgenerate

    // MSHR entry management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                mshr_entries[i].valid <= 1'b0;
                mshr_entries[i].pending <= 1'b0;
                mshr_entries[i].block_addr <= '0;
                mshr_entries[i].data <= '0;
            end
        end else begin
            // Handle allocation
            if (alloc_valid && alloc_ready) begin
                mshr_entries[free_entry_id].valid <= 1'b1;
                mshr_entries[free_entry_id].pending <= 1'b1;
                mshr_entries[free_entry_id].block_addr <= alloc_addr[XLEN-1:BLOCK_OFFSET_BITS];
                mshr_entries[free_entry_id].data <= '0;
            end
            
            // Handle memory acknowledgment
            if (mem_ack && found_pending) begin
                mshr_entries[selected_entry].pending <= 1'b0;
            end
            
            // Handle memory response
            if (resp_valid) begin
                mshr_entries[resp_entry_id].data <= resp_data;
            end
            
            // Handle deallocation
            if (dealloc_valid) begin
                mshr_entries[dealloc_entry_id].valid <= 1'b0;
                mshr_entries[dealloc_entry_id].pending <= 1'b0;
            end
        end
    end

    // Assertions for debugging
    // synthesis translate_off
    always_ff @(posedge clk) begin
        if (rst_n) begin
            // Check that we don't allocate to an occupied entry
            if (alloc_valid && alloc_ready) begin
                assert(!mshr_entries[free_entry_id].valid) 
                else $error("Allocating to occupied MSHR entry %0d", free_entry_id);
            end
            
            // Check that deallocation is to a valid entry
            if (dealloc_valid) begin
                assert(mshr_entries[dealloc_entry_id].valid) 
                else $error("Deallocating invalid MSHR entry %0d", dealloc_entry_id);
            end
            
            // Check that response is to a valid entry
            if (resp_valid) begin
                assert(mshr_entries[resp_entry_id].valid) 
                else $error("Response to invalid MSHR entry %0d", resp_entry_id);
            end
        end
    end
    // synthesis translate_on

endmodule
