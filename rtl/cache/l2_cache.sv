// L2 Unified Cache
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Role:
// - Unified mid-level cache serving both L1 I- and D-caches. Basic arbiter
//   selects between I/D requests (D has priority here), then processes hit/miss
//   with a write-back, write-allocate policy.
//
// Interfaces:
// - L1I/L1D: address/req, returns full line data and ack. For D, write data + we.
// - Memory: line-granular read/write with simple req/ack.
// - Control: flush clears valid/dirty; busy indicates miss pipeline active.
//
// Simplifications:
// - Single outstanding request (no MSHR here); serialization happens via FSM.
// - Arbitration is fixed-priority IDLE->L1D->L1I per current_req.
// -----------------------------------------------------------------------------

module l2_cache #(
    parameter CACHE_SIZE = 262144, // 256KB
    parameter BLOCK_SIZE = 64,     // 64 bytes per block
    parameter ASSOCIATIVITY = 2,   // 2-way set associative
    parameter XLEN = 64
) (
    input  logic clk,
    input  logic rst_n,
    
    // L1 I-Cache interface
    input  logic [XLEN-1:0] l1i_addr,
    output logic [BLOCK_SIZE*8-1:0] l1i_data,
    input  logic            l1i_req,
    output logic            l1i_ack,
    
    // L1 D-Cache interface
    input  logic [XLEN-1:0] l1d_addr,
    input  logic [BLOCK_SIZE*8-1:0] l1d_wdata,
    output logic [BLOCK_SIZE*8-1:0] l1d_rdata,
    input  logic            l1d_we,
    input  logic            l1d_req,
    output logic            l1d_ack,
    
    // L3/Memory interface
    output logic [XLEN-1:0] mem_addr,
    output logic [BLOCK_SIZE*8-1:0] mem_wdata,
    input  logic [BLOCK_SIZE*8-1:0] mem_rdata,
    output logic            mem_we,
    output logic            mem_req,
    input  logic            mem_ack,
    
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

    // Arbitration between L1I and L1D
    typedef enum logic [1:0] {
        ARB_IDLE,
        ARB_L1I,
        ARB_L1D
    } arb_state_t;
    
    arb_state_t arb_state, next_arb_state;
    
    logic [XLEN-1:0] current_addr;
    logic [BLOCK_SIZE*8-1:0] current_wdata;
    logic current_we;
    logic current_req;

    // Arbitration logic
    always_comb begin
        next_arb_state = arb_state;
        case (arb_state)
            ARB_IDLE: begin
                if (l1d_req) begin
                    next_arb_state = ARB_L1D;
                end else if (l1i_req) begin
                    next_arb_state = ARB_L1I;
                end
            end
            ARB_L1I: begin
                if (!l1i_req) begin
                    next_arb_state = ARB_IDLE;
                end
            end
            ARB_L1D: begin
                if (!l1d_req) begin
                    next_arb_state = ARB_IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arb_state <= ARB_IDLE;
        end else begin
            arb_state <= next_arb_state;
        end
    end

    // Select current request
    always_comb begin
        case (arb_state)
            ARB_L1I: begin
                current_addr = l1i_addr;
                current_wdata = '0;
                current_we = 1'b0;
                current_req = l1i_req;
            end
            ARB_L1D: begin
                current_addr = l1d_addr;
                current_wdata = l1d_wdata;
                current_we = l1d_we;
                current_req = l1d_req;
            end
            default: begin
                current_addr = '0;
                current_wdata = '0;
                current_we = 1'b0;
                current_req = 1'b0;
            end
        endcase
    end

    // Address breakdown
    logic [BLOCK_OFFSET_BITS-1:0] block_offset;
    logic [INDEX_BITS-1:0] index;
    logic [TAG_BITS-1:0] tag;
    
    assign block_offset = current_addr[BLOCK_OFFSET_BITS-1:0];
    assign index = current_addr[INDEX_BITS+BLOCK_OFFSET_BITS-1:BLOCK_OFFSET_BITS];
    assign tag = current_addr[XLEN-1:INDEX_BITS+BLOCK_OFFSET_BITS];

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

    // Data output
    logic [BLOCK_SIZE*8-1:0] hit_data;
    assign hit_data = cache_data[index][hit_way].data;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        WRITEBACK,
        ALLOCATE,
        REFILL,
        RESPOND
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
                if (current_req) begin
                    if (cache_hit) begin
                        next_state = RESPOND;
                    end else begin
                        if (need_writeback) begin
                            next_state = WRITEBACK;
                        end else begin
                            next_state = ALLOCATE;
                        end
                    end
                end
            end
            RESPOND: begin
                next_state = IDLE;
            end
            WRITEBACK: begin
                if (mem_ack) begin
                    next_state = ALLOCATE;
                end
            end
            ALLOCATE: begin
                next_state = REFILL;
            end
            REFILL: begin
                if (mem_ack) begin
                    next_state = RESPOND;
                end
            end
        endcase
    end

    // Control signals
    assign l1i_ack = (arb_state == ARB_L1I) && (state == RESPOND);
    assign l1d_ack = (arb_state == ARB_L1D) && (state == RESPOND);
    assign l1i_data = hit_data;
    assign l1d_rdata = hit_data;
    assign busy = (state != IDLE);

    // Memory interface
    always_comb begin
        mem_req = 1'b0;
        mem_we = 1'b0;
        mem_addr = '0;
        mem_wdata = '0;
        
        case (state)
            WRITEBACK: begin
                mem_req = 1'b1;
                mem_we = 1'b1;
                mem_addr = {cache_data[index][replace_way].tag, index, {BLOCK_OFFSET_BITS{1'b0}}};
                mem_wdata = cache_data[index][replace_way].data;
            end
            ALLOCATE: begin
                mem_req = 1'b1;
                mem_we = 1'b0;
                mem_addr = {current_addr[XLEN-1:BLOCK_OFFSET_BITS], {BLOCK_OFFSET_BITS{1'b0}}};
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
                if ((state == RESPOND) && cache_hit) begin
                    // Update LRU
                    if (way_hit[0]) lru[index] <= 1'b1; // Make way 1 LRU
                    if (way_hit[1]) lru[index] <= 1'b0; // Make way 0 LRU
                    
                    // Handle writes
                    if (current_we) begin
                        cache_data[index][hit_way].dirty <= 1'b1;
                        cache_data[index][hit_way].data <= current_wdata;
                    end
                end
                
                // Refill on memory response
                if (state == REFILL && mem_ack) begin
                    cache_data[index][replace_way].valid <= 1'b1;
                    cache_data[index][replace_way].dirty <= current_we;
                    cache_data[index][replace_way].tag <= tag;
                    cache_data[index][replace_way].data <= current_we ? current_wdata : mem_rdata;
                    
                    // Update LRU
                    if (replace_way == 0) lru[index] <= 1'b1;
                    if (replace_way == 1) lru[index] <= 1'b0;
                end
            end
        end
    end

endmodule
