//////////////////////////////////////////////////////////////////////////////////
// Module: l3_cache
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: L3 Last-Level Cache - 2-way set associative
//              Interface between cache hierarchy and main memory
//              Implements write-back policy with AXI-like memory interface
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module l3_cache #(
    parameter CACHE_SIZE_KB   = 2048,       // Cache size in KB (2MB)
    parameter LINE_SIZE_BYTES = 16,         // Cache line size in bytes
    parameter ASSOCIATIVITY   = 2           // Number of ways (2-way set associative)
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // L2 cache interface
    input  logic        l2_req,             // L2 cache request
    input  logic        l2_we,              // L2 cache write enable
    input  logic [31:0] l2_addr,            // L2 cache address
    input  logic [127:0] l2_wdata,          // L2 cache write data (full line)
    output logic [127:0] l2_rdata,          // L2 cache read data (full line)
    output logic        l2_valid,           // L2 data valid
    
    // Memory interface (simplified AXI-like)
    output logic        mem_req,            // Memory request
    output logic        mem_we,             // Memory write enable
    output logic [31:0] mem_addr,           // Memory address
    output logic [31:0] mem_wdata,          // Memory write data (word)
    output logic [3:0]  mem_be,             // Byte enable
    input  logic [31:0] mem_rdata,          // Memory read data (word)
    input  logic        mem_ready           // Memory ready signal
);

    //////////////////////////////////////////////////////////////////////////////////
    // Cache Parameters Calculation
    //////////////////////////////////////////////////////////////////////////////////
    
    localparam CACHE_SIZE_BYTES  = CACHE_SIZE_KB * 1024;
    localparam NUM_LINES         = CACHE_SIZE_BYTES / LINE_SIZE_BYTES;
    localparam NUM_SETS          = NUM_LINES / ASSOCIATIVITY;
    localparam INDEX_BITS        = $clog2(NUM_SETS);
    localparam OFFSET_BITS       = $clog2(LINE_SIZE_BYTES);
    localparam TAG_BITS          = 32 - INDEX_BITS - OFFSET_BITS;
    localparam WORDS_PER_LINE    = LINE_SIZE_BYTES / 4;  // 4 words per line
    
    //////////////////////////////////////////////////////////////////////////////////
    // Cache Line Structure
    //////////////////////////////////////////////////////////////////////////////////
    
    typedef struct packed {
        logic               valid;          // Valid bit
        logic [TAG_BITS-1:0] tag;           // Tag bits
        logic [127:0]       data;           // 128-bit data (4 words)
        logic               dirty;          // Dirty bit
    } cache_line_t;
    
    // Cache arrays (2 ways)
    cache_line_t cache_way0 [NUM_SETS];
    cache_line_t cache_way1 [NUM_SETS];
    
    // LRU bits
    logic [NUM_SETS-1:0] lru_bits;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Address Breakdown
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [TAG_BITS-1:0]   addr_tag;
    logic [INDEX_BITS-1:0] addr_index;
    logic [OFFSET_BITS-1:0] addr_offset;
    logic [1:0]            word_offset;     // Word within cache line
    
    assign addr_tag    = l2_addr[31:31-TAG_BITS+1];
    assign addr_index  = l2_addr[31-TAG_BITS:OFFSET_BITS];
    assign addr_offset = l2_addr[OFFSET_BITS-1:0];
    assign word_offset = addr_offset[3:2];
    
    //////////////////////////////////////////////////////////////////////////////////
    // Cache State Machine
    //////////////////////////////////////////////////////////////////////////////////
    
    typedef enum logic [3:0] {
        IDLE,
        MISS_FETCH_W0,
        MISS_FETCH_W1,
        MISS_FETCH_W2,
        MISS_FETCH_W3,
        MISS_UPDATE,
        WRITEBACK_W0,
        WRITEBACK_W1,
        WRITEBACK_W2,
        WRITEBACK_W3,
        WRITEBACK_DONE
    } state_t;
    
    state_t state, next_state;
    logic [1:0] fetch_word_count;
    logic [127:0] fetch_data;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Hit/Miss Detection Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    logic way0_hit, way1_hit;
    logic cache_hit;
    logic [127:0] hit_data;
    logic hit_way;
    logic victim_way;
    logic victim_dirty;
    logic [127:0] victim_data;
    logic [31:0] victim_addr;
    
    always_comb begin
        // Check way 0
        way0_hit = cache_way0[addr_index].valid && 
                  (cache_way0[addr_index].tag == addr_tag);
        
        // Check way 1
        way1_hit = cache_way1[addr_index].valid && 
                  (cache_way1[addr_index].tag == addr_tag);
        
        // Overall hit
        cache_hit = way0_hit || way1_hit;
        hit_way = way1_hit;
        
        // Select data from hitting way
        if (way0_hit) begin
            hit_data = cache_way0[addr_index].data;
        end else if (way1_hit) begin
            hit_data = cache_way1[addr_index].data;
        end else begin
            hit_data = 128'h0;
        end
        
        // Victim selection for replacement
        victim_way = lru_bits[addr_index];
        if (victim_way == 1'b0) begin
            victim_dirty = cache_way0[addr_index].dirty;
            victim_data = cache_way0[addr_index].data;
            victim_addr = {cache_way0[addr_index].tag, addr_index, {OFFSET_BITS{1'b0}}};
        end else begin
            victim_dirty = cache_way1[addr_index].dirty;
            victim_data = cache_way1[addr_index].data;
            victim_addr = {cache_way1[addr_index].tag, addr_index, {OFFSET_BITS{1'b0}}};
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Memory Interface Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        mem_req = 1'b0;
        mem_we = 1'b0;
        mem_addr = 32'h0;
        mem_wdata = 32'h0;
        mem_be = 4'b1111;  // Always full word access
        
        case (state)
            MISS_FETCH_W0, MISS_FETCH_W1, MISS_FETCH_W2, MISS_FETCH_W3: begin
                mem_req = 1'b1;
                mem_we = 1'b0;
                mem_addr = {l2_addr[31:4], fetch_word_count, 2'b00};
            end
            
            WRITEBACK_W0, WRITEBACK_W1, WRITEBACK_W2, WRITEBACK_W3: begin
                mem_req = 1'b1;
                mem_we = 1'b1;
                mem_addr = {victim_addr[31:4], fetch_word_count, 2'b00};
                case (fetch_word_count)
                    2'b00: mem_wdata = victim_data[31:0];
                    2'b01: mem_wdata = victim_data[63:32];
                    2'b10: mem_wdata = victim_data[95:64];
                    2'b11: mem_wdata = victim_data[127:96];
                endcase
            end
        endcase
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Cache State Machine Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            fetch_word_count <= 2'b00;
            fetch_data <= 128'h0;
        end else begin
            state <= next_state;
            
            // Update fetch data and counter
            case (state)
                MISS_FETCH_W0: if (mem_ready) begin
                    fetch_data[31:0] <= mem_rdata;
                    fetch_word_count <= 2'b01;
                end
                MISS_FETCH_W1: if (mem_ready) begin
                    fetch_data[63:32] <= mem_rdata;
                    fetch_word_count <= 2'b10;
                end
                MISS_FETCH_W2: if (mem_ready) begin
                    fetch_data[95:64] <= mem_rdata;
                    fetch_word_count <= 2'b11;
                end
                MISS_FETCH_W3: if (mem_ready) begin
                    fetch_data[127:96] <= mem_rdata;
                    fetch_word_count <= 2'b00;
                end
                
                WRITEBACK_W0, WRITEBACK_W1, WRITEBACK_W2: if (mem_ready) begin
                    fetch_word_count <= fetch_word_count + 1;
                end
                WRITEBACK_W3: if (mem_ready) begin
                    fetch_word_count <= 2'b00;
                end
                
                default: begin
                    fetch_word_count <= 2'b00;
                end
            endcase
        end
    end
    
    always_comb begin
        next_state = state;
        l2_rdata = 128'h0;
        l2_valid = 1'b0;
        
        case (state)
            IDLE: begin
                if (l2_req) begin
                    if (cache_hit) begin
                        // Cache hit - respond immediately
                        l2_rdata = hit_data;
                        l2_valid = 1'b1;
                        next_state = IDLE;
                    end else begin
                        // Cache miss - check if victim needs writeback
                        if (victim_dirty) begin
                            next_state = WRITEBACK_W0;
                        end else begin
                            next_state = MISS_FETCH_W0;
                        end
                    end
                end
            end
            
            // Writeback dirty victim
            WRITEBACK_W0: begin
                if (mem_ready) next_state = WRITEBACK_W1;
                else next_state = WRITEBACK_W0;
            end
            
            WRITEBACK_W1: begin
                if (mem_ready) next_state = WRITEBACK_W2;
                else next_state = WRITEBACK_W1;
            end
            
            WRITEBACK_W2: begin
                if (mem_ready) next_state = WRITEBACK_W3;
                else next_state = WRITEBACK_W2;
            end
            
            WRITEBACK_W3: begin
                if (mem_ready) next_state = MISS_FETCH_W0;
                else next_state = WRITEBACK_W3;
            end
            
            // Fetch new cache line from memory
            MISS_FETCH_W0: begin
                if (mem_ready) next_state = MISS_FETCH_W1;
                else next_state = MISS_FETCH_W0;
            end
            
            MISS_FETCH_W1: begin
                if (mem_ready) next_state = MISS_FETCH_W2;
                else next_state = MISS_FETCH_W1;
            end
            
            MISS_FETCH_W2: begin
                if (mem_ready) next_state = MISS_FETCH_W3;
                else next_state = MISS_FETCH_W2;
            end
            
            MISS_FETCH_W3: begin
                if (mem_ready) next_state = MISS_UPDATE;
                else next_state = MISS_FETCH_W3;
            end
            
            MISS_UPDATE: begin
                // Respond to L2 with fetched data
                l2_rdata = fetch_data;
                l2_valid = 1'b1;
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
                cache_way0[i].dirty <= 1'b0;
                cache_way1[i].valid <= 1'b0;
                cache_way1[i].tag <= '0;
                cache_way1[i].data <= 128'h0;
                cache_way1[i].dirty <= 1'b0;
            end
            lru_bits <= '0;
        end else begin
            // Update LRU on hit
            if (state == IDLE && l2_req && cache_hit) begin
                lru_bits[addr_index] <= !hit_way;
                
                // Handle write hit from L2
                if (l2_we) begin
                    if (way0_hit) begin
                        cache_way0[addr_index].data <= l2_wdata;
                        cache_way0[addr_index].dirty <= 1'b1;
                    end else if (way1_hit) begin
                        cache_way1[addr_index].data <= l2_wdata;
                        cache_way1[addr_index].dirty <= 1'b1;
                    end
                end
            end
            
            // Update cache on miss
            if (state == MISS_UPDATE) begin
                // Replace victim way
                if (victim_way == 1'b0) begin
                    cache_way0[addr_index].valid <= 1'b1;
                    cache_way0[addr_index].tag <= addr_tag;
                    cache_way0[addr_index].data <= fetch_data;
                    cache_way0[addr_index].dirty <= 1'b0;
                    lru_bits[addr_index] <= 1'b1;
                end else begin
                    cache_way1[addr_index].valid <= 1'b1;
                    cache_way1[addr_index].tag <= addr_tag;
                    cache_way1[addr_index].data <= fetch_data;
                    cache_way1[addr_index].dirty <= 1'b0;
                    lru_bits[addr_index] <= 1'b0;
                end
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Debug Output (simulation only)
    //////////////////////////////////////////////////////////////////////////////////
    
    `ifdef SIMULATION
    always @(posedge clk) begin
        if (state == IDLE && l2_req && cache_hit) begin
            $display("Time %t: L3 Cache HIT - Addr: 0x%08x", $time, l2_addr);
        end
        if (state == MISS_FETCH_W0) begin
            $display("Time %t: L3 Cache MISS - Addr: 0x%08x, Fetching from memory", $time, l2_addr);
        end
    end
    `endif
    
endmodule