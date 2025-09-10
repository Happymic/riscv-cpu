//////////////////////////////////////////////////////////////////////////////////
// Module: l1_icache
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: L1 Instruction Cache - 2-way set associative
//              Implements read-only cache for instruction fetch
//              Uses LRU replacement policy
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module l1_icache #(
    parameter CACHE_SIZE_KB   = 32,         // Cache size in KB
    parameter LINE_SIZE_BYTES = 16,         // Cache line size in bytes
    parameter ASSOCIATIVITY   = 2           // Number of ways (2-way set associative)
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // CPU interface
    input  logic        req,                // Cache request
    input  logic [31:0] addr,               // Request address
    output logic [31:0] data_out,           // Instruction data output
    output logic        hit,                // Cache hit signal
    output logic        stall,              // Stall signal (miss handling)
    
    // L2 cache interface
    output logic        l2_req,             // L2 cache request
    output logic [31:0] l2_addr,            // L2 cache address
    input  logic [127:0] l2_data,           // L2 cache data (full cache line)
    input  logic        l2_valid            // L2 data valid
);

    //////////////////////////////////////////////////////////////////////////////////
    // Cache Parameters Calculation
    //////////////////////////////////////////////////////////////////////////////////
    
    localparam CACHE_SIZE_BYTES  = CACHE_SIZE_KB * 1024;
    localparam NUM_LINES          = CACHE_SIZE_BYTES / LINE_SIZE_BYTES;
    localparam NUM_SETS           = NUM_LINES / ASSOCIATIVITY;
    localparam INDEX_BITS         = $clog2(NUM_SETS);
    localparam OFFSET_BITS        = $clog2(LINE_SIZE_BYTES);
    localparam TAG_BITS           = 32 - INDEX_BITS - OFFSET_BITS;
    localparam WORDS_PER_LINE     = LINE_SIZE_BYTES / 4;  // 4 words per line for 16-byte lines
    
    //////////////////////////////////////////////////////////////////////////////////
    // Cache Memory Structure
    //////////////////////////////////////////////////////////////////////////////////
    
    // Cache line structure
    typedef struct packed {
        logic                   valid;      // Valid bit
        logic [TAG_BITS-1:0]   tag;        // Tag bits
        logic [127:0]          data;       // 128-bit data (4 words)
    } cache_line_t;
    
    // Cache arrays (2 ways)
    cache_line_t cache_way0 [NUM_SETS];
    cache_line_t cache_way1 [NUM_SETS];
    
    // LRU bits (1 bit per set: 0 = way0 was used recently, 1 = way1 was used recently)
    logic [NUM_SETS-1:0] lru_bits;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Address Breakdown
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [TAG_BITS-1:0]   addr_tag;
    logic [INDEX_BITS-1:0] addr_index;
    logic [OFFSET_BITS-1:0] addr_offset;
    logic [1:0]            word_offset;     // Word within cache line
    
    assign addr_tag    = addr[31:31-TAG_BITS+1];
    assign addr_index  = addr[31-TAG_BITS:OFFSET_BITS];
    assign addr_offset = addr[OFFSET_BITS-1:0];
    assign word_offset = addr_offset[3:2];  // Select word within line
    
    //////////////////////////////////////////////////////////////////////////////////
    // Cache State Machine
    //////////////////////////////////////////////////////////////////////////////////
    
    typedef enum logic [1:0] {
        IDLE,
        MISS_REQUEST,
        MISS_WAIT,
        MISS_UPDATE
    } state_t;
    
    state_t state, next_state;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Hit/Miss Detection Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    logic way0_hit, way1_hit;
    logic cache_hit;
    logic [127:0] hit_data;
    logic hit_way;  // 0 for way0, 1 for way1
    
    always_comb begin
        // Check way 0
        way0_hit = cache_way0[addr_index].valid && 
                  (cache_way0[addr_index].tag == addr_tag);
        
        // Check way 1
        way1_hit = cache_way1[addr_index].valid && 
                  (cache_way1[addr_index].tag == addr_tag);
        
        // Overall hit
        cache_hit = way0_hit || way1_hit;
        hit_way = way1_hit;  // 1 if way1 hit, 0 if way0 hit
        
        // Select data from hitting way
        if (way0_hit) begin
            hit_data = cache_way0[addr_index].data;
        end else if (way1_hit) begin
            hit_data = cache_way1[addr_index].data;
        end else begin
            hit_data = 128'h0;
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Data Output Multiplexer
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Select the appropriate word from the cache line
        case (word_offset)
            2'b00: data_out = hit_data[31:0];
            2'b01: data_out = hit_data[63:32];
            2'b10: data_out = hit_data[95:64];
            2'b11: data_out = hit_data[127:96];
        endcase
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Cache State Machine
    //////////////////////////////////////////////////////////////////////////////////
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always_comb begin
        next_state = state;
        l2_req = 1'b0;
        l2_addr = 32'h0;
        stall = 1'b0;
        hit = 1'b0;
        
        case (state)
            IDLE: begin
                if (req) begin
                    if (cache_hit) begin
                        // Cache hit
                        hit = 1'b1;
                        next_state = IDLE;
                    end else begin
                        // Cache miss
                        stall = 1'b1;
                        next_state = MISS_REQUEST;
                    end
                end
            end
            
            MISS_REQUEST: begin
                // Request data from L2
                stall = 1'b1;
                l2_req = 1'b1;
                l2_addr = {addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};  // Aligned address
                next_state = MISS_WAIT;
            end
            
            MISS_WAIT: begin
                // Wait for L2 response
                stall = 1'b1;
                if (l2_valid) begin
                    next_state = MISS_UPDATE;
                end else begin
                    next_state = MISS_WAIT;
                end
            end
            
            MISS_UPDATE: begin
                // Update cache with new data
                stall = 1'b0;
                hit = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Cache Update Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    integer i;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset cache
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                cache_way0[i].valid <= 1'b0;
                cache_way0[i].tag <= '0;
                cache_way0[i].data <= 128'h0;
                cache_way1[i].valid <= 1'b0;
                cache_way1[i].tag <= '0;
                cache_way1[i].data <= 128'h0;
            end
            lru_bits <= '0;
        end else begin
            // Update LRU on hit
            if (state == IDLE && req && cache_hit) begin
                lru_bits[addr_index] <= !hit_way;  // Mark other way as LRU
            end
            
            // Update cache on miss
            if (state == MISS_UPDATE) begin
                // Select victim way based on LRU
                if (lru_bits[addr_index] == 1'b0) begin
                    // Replace way 0 (it's LRU)
                    cache_way0[addr_index].valid <= 1'b1;
                    cache_way0[addr_index].tag <= addr_tag;
                    cache_way0[addr_index].data <= l2_data;
                    lru_bits[addr_index] <= 1'b1;  // Mark way 1 as LRU
                end else begin
                    // Replace way 1 (it's LRU)
                    cache_way1[addr_index].valid <= 1'b1;
                    cache_way1[addr_index].tag <= addr_tag;
                    cache_way1[addr_index].data <= l2_data;
                    lru_bits[addr_index] <= 1'b0;  // Mark way 0 as LRU
                end
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Debug Output (simulation only)
    //////////////////////////////////////////////////////////////////////////////////
    
    `ifdef SIMULATION
    always @(posedge clk) begin
        if (req && cache_hit) begin
            $display("Time %t: L1 I-Cache HIT - Addr: 0x%08x, Data: 0x%08x", 
                    $time, addr, data_out);
        end
        if (state == MISS_REQUEST) begin
            $display("Time %t: L1 I-Cache MISS - Addr: 0x%08x, Requesting from L2", 
                    $time, addr);
        end
    end
    `endif
    
endmodule