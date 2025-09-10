// L3 Shared Cache
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Role:
// - Last-level cache shared by multiple L2 ports. Round-robin arbitration picks
//   one requesting port per serve, then executes the same write-back/allocate
//   policy as L2. Memory interface is line-based.
//
// Arbitration:
// - Round-robin pointer advances after each RESPOND state to provide fairness.
//
// Simplifications:
// - Single outstanding request; true multi-port and MSHR-based non-blocking
//   designs would decouple pipeline from memory latency.
// -----------------------------------------------------------------------------

module l3_cache #(
    parameter CACHE_SIZE = 2097152, // 2MB
    parameter BLOCK_SIZE = 64,      // 64 bytes per block
    parameter ASSOCIATIVITY = 2,    // 2-way set associative
    parameter XLEN = 64,
    parameter NUM_PORTS = 4         // Number of L2 cache ports
) (
    input  logic clk,
    input  logic rst_n,
    
    // L2 Cache interfaces (multiple ports)
    input  logic [NUM_PORTS-1:0] [XLEN-1:0] l2_addr,
    input  logic [NUM_PORTS-1:0] [BLOCK_SIZE*8-1:0] l2_wdata,
    output logic [NUM_PORTS-1:0] [BLOCK_SIZE*8-1:0] l2_rdata,
    input  logic [NUM_PORTS-1:0] l2_we,
    input  logic [NUM_PORTS-1:0] l2_req,
    output logic [NUM_PORTS-1:0] l2_ack,
    
    // Memory interface
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

    // Round-robin arbitration
    logic [$clog2(NUM_PORTS)-1:0] arb_pointer;
    logic [$clog2(NUM_PORTS)-1:0] current_port;
    logic port_selected;

    // Select current port using round-robin
    always_comb begin
        current_port = 0;
        port_selected = 1'b0;
        
        for (int p = 0; p < NUM_PORTS; p++) begin
            if (l2_req[(arb_pointer + p) % NUM_PORTS] && !port_selected) begin
                current_port = (arb_pointer + p) % NUM_PORTS;
                port_selected = 1'b1;
            end
        end
    end

    // Current request signals
    logic [XLEN-1:0] current_addr;
    logic [BLOCK_SIZE*8-1:0] current_wdata;
    logic current_we;
    logic current_req;

    assign current_addr = l2_addr[current_port];
    assign current_wdata = l2_wdata[current_port];
    assign current_we = l2_we[current_port];
    assign current_req = port_selected;

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
    logic [$clog2(NUM_PORTS)-1:0] serving_port;

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
            arb_pointer <= '0;
            serving_port <= '0;
        end else begin
            state <= next_state;
            
            // Update arbitration pointer on request completion
            if (state == RESPOND) begin
                arb_pointer <= (arb_pointer + 1) % NUM_PORTS;
            end
            
            // Capture serving port
            if (state == IDLE && current_req) begin
                serving_port <= current_port;
            end
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
    generate
        for (genvar p = 0; p < NUM_PORTS; p++) begin : gen_ack
            assign l2_ack[p] = (serving_port == p) && (state == RESPOND);
            assign l2_rdata[p] = hit_data;
        end
    endgenerate

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
