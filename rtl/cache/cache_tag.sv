// Cache Tag Comparison Logic
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Given an address and set-associative tag/valid/dirty arrays, detect hits,
//   select a victim way (LRU), and provide write/invalidate controls to update
//   tags and status bits. Useful as a building block for cache pipelines.
//
// Address breakdown:
// - [TAG | INDEX | BLOCK_OFFSET]
// - TAG_BITS/INDEX_BITS/BLOCK_OFFSET_BITS are derived from parameters.
//
// Outputs:
// - way_hit/cache_hit/hit_way: which way (if any) matches and is valid.
// - lru_victim_way: which way should be evicted on miss (simple LRU for 2-way).
// - *we/*wdata: write intents toward tag/valid/dirty arrays per way.
//
// Notes:
// - This module focuses on metadata path and does not include data array.
// - Assertions at bottom help catch protocol errors during simulation.
// -----------------------------------------------------------------------------

module cache_tag #(
    parameter XLEN = 64,
    parameter CACHE_SIZE = 32768,  // 32KB
    parameter BLOCK_SIZE = 64,     // 64 bytes per block
    parameter ASSOCIATIVITY = 2    // 2-way set associative
) (
    input  logic clk,
    input  logic rst_n,
    
    // Address input
    input  logic [XLEN-1:0] addr,
    
    // Tag array interface
    output logic [TAG_ADDR_BITS-1:0] tag_addr,
    output logic [ASSOCIATIVITY-1:0] [TAG_BITS-1:0] tag_wdata,
    input  logic [ASSOCIATIVITY-1:0] [TAG_BITS-1:0] tag_rdata,
    output logic [ASSOCIATIVITY-1:0] tag_we,
    output logic                     tag_re,
    
    // Valid bit array interface
    output logic [TAG_ADDR_BITS-1:0] valid_addr,
    output logic [ASSOCIATIVITY-1:0] valid_wdata,
    input  logic [ASSOCIATIVITY-1:0] valid_rdata,
    output logic [ASSOCIATIVITY-1:0] valid_we,
    output logic                     valid_re,
    
    // Dirty bit array interface (for D-cache)
    output logic [TAG_ADDR_BITS-1:0] dirty_addr,
    output logic [ASSOCIATIVITY-1:0] dirty_wdata,
    input  logic [ASSOCIATIVITY-1:0] dirty_rdata,
    output logic [ASSOCIATIVITY-1:0] dirty_we,
    output logic                     dirty_re,
    
    // Hit/miss detection
    output logic [ASSOCIATIVITY-1:0] way_hit,
    output logic                     cache_hit,
    output logic [WAY_BITS-1:0]      hit_way,
    
    // Update interface
    input  logic                     update_valid,
    input  logic [WAY_BITS-1:0]      update_way,
    input  logic [TAG_BITS-1:0]      update_tag,
    input  logic                     update_valid_bit,
    input  logic                     update_dirty_bit,
    
    // Invalidation interface
    input  logic                     invalidate,
    input  logic [WAY_BITS-1:0]      invalidate_way,
    
    // LRU update interface
    input  logic                     lru_update,
    input  logic [WAY_BITS-1:0]      lru_way,
    output logic [WAY_BITS-1:0]      lru_victim_way
);

    localparam BLOCK_OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam INDEX_BITS = $clog2(CACHE_SIZE / (BLOCK_SIZE * ASSOCIATIVITY));
    localparam TAG_BITS = XLEN - INDEX_BITS - BLOCK_OFFSET_BITS;
    localparam TAG_ADDR_BITS = INDEX_BITS;
    localparam WAY_BITS = $clog2(ASSOCIATIVITY);
    localparam NUM_SETS = 1 << INDEX_BITS;

    // Address breakdown
    logic [BLOCK_OFFSET_BITS-1:0] block_offset;
    logic [INDEX_BITS-1:0]         index;
    logic [TAG_BITS-1:0]           tag;
    
    assign block_offset = addr[BLOCK_OFFSET_BITS-1:0];
    assign index = addr[INDEX_BITS+BLOCK_OFFSET_BITS-1:BLOCK_OFFSET_BITS];
    assign tag = addr[XLEN-1:INDEX_BITS+BLOCK_OFFSET_BITS];

    // Tag array addressing
    assign tag_addr = index;
    assign valid_addr = index;
    assign dirty_addr = index;

    // Read enables
    assign tag_re = 1'b1;    // Always reading for comparison
    assign valid_re = 1'b1;  // Always reading for hit detection
    assign dirty_re = 1'b1;  // Always reading for dirty status

    // Hit detection logic
    genvar i;
    generate
        for (i = 0; i < ASSOCIATIVITY; i++) begin : gen_hit_detect
            assign way_hit[i] = valid_rdata[i] && (tag_rdata[i] == tag);
        end
    endgenerate
    
    assign cache_hit = |way_hit;

    // Priority encoder to find hit way
    always_comb begin
        hit_way = 0;
        for (int j = 0; j < ASSOCIATIVITY; j++) begin
            if (way_hit[j]) begin
                hit_way = j;
            end
        end
    end

    // LRU tracking (simple pseudo-LRU for 2-way)
    logic [NUM_SETS-1:0] lru_bits;
    
    generate
        if (ASSOCIATIVITY == 2) begin : gen_2way_lru
            // For 2-way: 0 = way 0 is LRU, 1 = way 1 is LRU
            assign lru_victim_way = lru_bits[index] ? 0 : 1;
        end else begin : gen_nway_lru
            // For N-way, implement more complex LRU (simplified here)
            assign lru_victim_way = 0; // Default to way 0
        end
    endgenerate

    // LRU update logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lru_bits <= '0;
        end else begin
            if (lru_update) begin
                if (ASSOCIATIVITY == 2) begin
                    // Update LRU bit: recently accessed way becomes MRU
                    lru_bits[index] <= lru_way[0]; // If way 0 accessed, set bit to 1 (way 1 becomes LRU)
                end
            end
        end
    end

    // Write control logic
    always_comb begin
        // Default: no writes
        tag_we = '0;
        valid_we = '0;
        dirty_we = '0;
        tag_wdata = '0;
        valid_wdata = '0;
        dirty_wdata = '0;

        if (update_valid) begin
            // Update specific way
            tag_we[update_way] = 1'b1;
            tag_wdata[update_way] = update_tag;
            
            valid_we[update_way] = 1'b1;
            valid_wdata[update_way] = update_valid_bit;
            
            dirty_we[update_way] = 1'b1;
            dirty_wdata[update_way] = update_dirty_bit;
        end else if (invalidate) begin
            // Invalidate specific way
            valid_we[invalidate_way] = 1'b1;
            valid_wdata[invalidate_way] = 1'b0;
            
            dirty_we[invalidate_way] = 1'b1;
            dirty_wdata[invalidate_way] = 1'b0;
        end
    end

    // Additional utility outputs for debugging
    logic [ASSOCIATIVITY-1:0] way_valid;
    logic [ASSOCIATIVITY-1:0] way_dirty;
    
    assign way_valid = valid_rdata;
    assign way_dirty = dirty_rdata;

    // Assertions for verification
    // synthesis translate_off
    property p_hit_way_onehot;
        @(posedge clk) disable iff (!rst_n)
        cache_hit |-> $onehot(way_hit);
    endproperty
    
    property p_update_way_valid;
        @(posedge clk) disable iff (!rst_n)
        update_valid |-> (update_way < ASSOCIATIVITY);
    endproperty
    
    property p_invalidate_way_valid;
        @(posedge clk) disable iff (!rst_n)
        invalidate |-> (invalidate_way < ASSOCIATIVITY);
    endproperty

    assert_hit_way_onehot: assert property(p_hit_way_onehot)
        else $error("Multiple ways hit simultaneously");
    
    assert_update_way_valid: assert property(p_update_way_valid)
        else $error("Invalid update way: %0d", update_way);
    
    assert_invalidate_way_valid: assert property(p_invalidate_way_valid)
        else $error("Invalid invalidate way: %0d", invalidate_way);
    // synthesis translate_on

endmodule
