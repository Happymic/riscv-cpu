// L1 Data Cache
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Two-way set-associative data cache supporting loads and stores with
//   byte-enable writes. On miss, allocates from L2 and uses write-back policy.
//
// CPU interface (simplified):
// - cpu_req/ack/hit handshake with single outstanding request.
// - cpu_addr/wdata/we/be for accesses; cpu_rdata returns a 64-bit word slice
//   from the cache line based on byte offset.
//
// Miss flow:
// - If victim line is dirty, write it back to L2, then allocate and refill.
// - LRU policy mirrors I-cache (simple bit per set).
//
// Notes:
// - Uses packed arrays to hold tags/data/valid/dirty; replace with SRAMs in HW.
// - Flush clears valid/dirty; memory consistency is abstracted away here.
// -----------------------------------------------------------------------------

module l1_dcache #(
    parameter CACHE_SIZE = 32768,  // 32KB
    parameter BLOCK_SIZE = 64,     // 64 bytes per block
    parameter ASSOCIATIVITY = 2,   // 2-way set associative
    parameter XLEN = 64
) (
    input  logic clk,
    input  logic rst_n,
    
    // CPU interface
    input  logic [XLEN-1:0] cpu_addr,
    input  logic [XLEN-1:0] cpu_wdata,
    output logic [XLEN-1:0] cpu_rdata,
    input  logic            cpu_we,
    input  logic [7:0]      cpu_be,
    input  logic            cpu_req,
    output logic            cpu_ack,
    output logic            cpu_hit,
    
    // L2 interface
    output logic [XLEN-1:0] l2_addr,
    output logic [BLOCK_SIZE*8-1:0] l2_wdata,
    input  logic [BLOCK_SIZE*8-1:0] l2_rdata,
    output logic            l2_we,
    output logic            l2_req,
    input  logic            l2_ack,
    
    // Control
    input  logic            flush,
    output logic            busy
);

    localparam BLOCK_OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam INDEX_BITS = $clog2(CACHE_SIZE / (BLOCK_SIZE * ASSOCIATIVITY));
    localparam TAG_BITS = XLEN - INDEX_BITS - BLOCK_OFFSET_BITS;
    localparam NUM_SETS = 1 << INDEX_BITS;

    // Cache line structure
    typedef struct packed {
        logic valid;
        logic dirty;
        logic [TAG_BITS-1:0] tag;
        logic [BLOCK_SIZE*8-1:0] data;
    } cache_line_t;

    // Cache storage
    cache_line_t cache_data [NUM_SETS-1:0] [ASSOCIATIVITY-1:0];
    logic [ASSOCIATIVITY-1:0] lru [NUM_SETS-1:0];

    // Address breakdown
    logic [BLOCK_OFFSET_BITS-1:0] block_offset;
    logic [INDEX_BITS-1:0] index;
    logic [TAG_BITS-1:0] tag;
    
    assign block_offset = cpu_addr[BLOCK_OFFSET_BITS-1:0];
    assign index = cpu_addr[INDEX_BITS+BLOCK_OFFSET_BITS-1:BLOCK_OFFSET_BITS];
    assign tag = cpu_addr[XLEN-1:INDEX_BITS+BLOCK_OFFSET_BITS];

    // Hit detection
    logic [ASSOCIATIVITY-1:0] way_hit;
    logic cache_hit;
    logic [ASSOCIATIVITY-1:0] way_valid;
    logic [$clog2(ASSOCIATIVITY)-1:0] hit_way;
    
    genvar i;
    generate
        for (i = 0; i < ASSOCIATIVITY; i++) begin : gen_hit_detect
            assign way_valid[i] = cache_data[index][i].valid;
            assign way_hit[i] = way_valid[i] && (cache_data[index][i].tag == tag);
        end
    endgenerate
    
    assign cache_hit = |way_hit;
    
    // Find hit way
    always_comb begin
        hit_way = 0;
        for (int j = 0; j < ASSOCIATIVITY; j++) begin
            if (way_hit[j]) begin
                hit_way = j;
            end
        end
    end

    // Data output multiplexing
    logic [BLOCK_SIZE*8-1:0] hit_data;
    assign hit_data = cache_data[index][hit_way].data;

    // Extract data from cache line based on address
    logic [5:0] byte_offset;
    assign byte_offset = block_offset[5:0];
    assign cpu_rdata = hit_data[byte_offset*8 +: 64];

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        WRITEBACK,
        ALLOCATE,
        REFILL
    } state_t;
    
    state_t state, next_state;

    // LRU replacement policy
    logic [$clog2(ASSOCIATIVITY)-1:0] replace_way;
    logic need_writeback;
    
    always_comb begin
        replace_way = 0;
        need_writeback = 1'b0;
        
        for (int k = 0; k < ASSOCIATIVITY; k++) begin
            if (!way_valid[k]) begin
                replace_way = k;
                need_writeback = 1'b0;
                break;
            end
        end
        
        // If all ways valid, use LRU
        if (&way_valid) begin
            replace_way = lru[index][0] ? 0 : 1; // Simple LRU for 2-way
            need_writeback = cache_data[index][replace_way].dirty;
        end
    end

    // State machine logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (cpu_req && !cache_hit) begin
                    if (need_writeback) begin
                        next_state = WRITEBACK;
                    end else begin
                        next_state = ALLOCATE;
                    end
                end
            end
            WRITEBACK: begin
                if (l2_ack) begin
                    next_state = ALLOCATE;
                end
            end
            ALLOCATE: begin
                next_state = REFILL;
            end
            REFILL: begin
                if (l2_ack) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Control signals
    assign cpu_ack = (state == IDLE) && (cache_hit || !cpu_req);
    assign cpu_hit = cache_hit;
    assign busy = (state != IDLE);

    // L2 interface signals
    always_comb begin
        l2_req = 1'b0;
        l2_we = 1'b0;
        l2_addr = '0;
        l2_wdata = '0;
        
        case (state)
            WRITEBACK: begin
                l2_req = 1'b1;
                l2_we = 1'b1;
                l2_addr = {cache_data[index][replace_way].tag, index, {BLOCK_OFFSET_BITS{1'b0}}};
                l2_wdata = cache_data[index][replace_way].data;
            end
            ALLOCATE: begin
                l2_req = 1'b1;
                l2_we = 1'b0;
                l2_addr = {cpu_addr[XLEN-1:BLOCK_OFFSET_BITS], {BLOCK_OFFSET_BITS{1'b0}}};
            end
        endcase
    end

    // Cache update logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_SETS; i++) begin
                lru[i] <= '0;
                for (int j = 0; j < ASSOCIATIVITY; j++) begin
                    cache_data[i][j].valid <= 1'b0;
                    cache_data[i][j].dirty <= 1'b0;
                    cache_data[i][j].tag <= '0;
                    cache_data[i][j].data <= '0;
                end
            end
        end else begin
            if (flush) begin
                for (int i = 0; i < NUM_SETS; i++) begin
                    for (int j = 0; j < ASSOCIATIVITY; j++) begin
                        cache_data[i][j].valid <= 1'b0;
                        cache_data[i][j].dirty <= 1'b0;
                    end
                end
            end else begin
                // Update on cache hit
                if (cpu_req && cache_hit) begin
                    // Update LRU
                    if (way_hit[0]) lru[index] <= 1'b1; // Make way 1 LRU
                    if (way_hit[1]) lru[index] <= 1'b0; // Make way 0 LRU
                    
                    // Handle writes
                    if (cpu_we) begin
                        cache_data[index][hit_way].dirty <= 1'b1;
                        // Byte-level write with byte enables
                        for (int b = 0; b < 8; b++) begin
                            if (cpu_be[b]) begin
                                cache_data[index][hit_way].data[byte_offset*8 + b*8 +: 8] <= cpu_wdata[b*8 +: 8];
                            end
                        end
                    end
                end
                
                // Refill on L2 response
                if (state == REFILL && l2_ack) begin
                    cache_data[index][replace_way].valid <= 1'b1;
                    cache_data[index][replace_way].dirty <= 1'b0;
                    cache_data[index][replace_way].tag <= tag;
                    cache_data[index][replace_way].data <= l2_rdata;
                    
                    // Update LRU
                    if (replace_way == 0) lru[index] <= 1'b1;
                    if (replace_way == 1) lru[index] <= 1'b0;
                end
            end
        end
    end

endmodule
