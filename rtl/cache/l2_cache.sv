//////////////////////////////////////////////////////////////////////////////////
// Module: l2_cache
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: L2 Unified Cache - 2-way set associative
//              Services both instruction and data requests from L1 caches
//              Implements inclusive cache hierarchy with write-back policy
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module l2_cache #(
    parameter CACHE_SIZE_KB   = 256,        // Cache size in KB
    parameter LINE_SIZE_BYTES = 16,         // Cache line size in bytes
    parameter ASSOCIATIVITY   = 2           // Number of ways (2-way set associative)
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // L1I cache interface
    input  logic        l1i_req,            // L1I cache request
    input  logic [31:0] l1i_addr,           // L1I cache address
    output logic [127:0] l1i_data,          // L1I cache data (full line)
    output logic        l1i_valid,          // L1I data valid
    
    // L1D cache interface
    input  logic        l1d_req,            // L1D cache request
    input  logic        l1d_we,             // L1D cache write enable
    input  logic [31:0] l1d_addr,           // L1D cache address
    input  logic [127:0] l1d_wdata,         // L1D cache write data (full line)
    output logic [127:0] l1d_rdata,         // L1D cache read data (full line)
    output logic        l1d_valid,          // L1D data valid
    
    // L3 cache interface
    output logic        l3_req,             // L3 cache request
    output logic        l3_we,              // L3 cache write enable
    output logic [31:0] l3_addr,            // L3 cache address
    output logic [127:0] l3_wdata,          // L3 cache write data (full line)
    input  logic [127:0] l3_rdata,          // L3 cache read data (full line)
    input  logic        l3_valid            // L3 data valid
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
    // Request Arbitration
    //////////////////////////////////////////////////////////////////////////////////
    
    typedef enum logic [1:0] {
        REQ_NONE,
        REQ_L1I,
        REQ_L1D
    } req_type_t;
    
    req_type_t current_req;
    logic [31:0] req_addr;
    logic        req_we;
    logic [127:0] req_wdata;
    
    // Simple priority arbitration: L1D has higher priority than L1I
    always_comb begin
        if (l1d_req) begin
            current_req = REQ_L1D;
            req_addr = l1d_addr;
            req_we = l1d_we;
            req_wdata = l1d_wdata;
        end else if (l1i_req) begin
            current_req = REQ_L1I;
            req_addr = l1i_addr;
            req_we = 1'b0;
            req_wdata = 128'h0;
        end else begin
            current_req = REQ_NONE;
            req_addr = 32'h0;
            req_we = 1'b0;
            req_wdata = 128'h0;
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Address Breakdown
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [TAG_BITS-1:0]   addr_tag;
    logic [INDEX_BITS-1:0] addr_index;
    logic [OFFSET_BITS-1:0] addr_offset;
    
    assign addr_tag    = req_addr[31:31-TAG_BITS+1];
    assign addr_index  = req_addr[31-TAG_BITS:OFFSET_BITS];
    assign addr_offset = req_addr[OFFSET_BITS-1:0];
    
    //////////////////////////////////////////////////////////////////////////////////
    // Cache State Machine
    //////////////////////////////////////////////////////////////////////////////////
    
    typedef enum logic [2:0] {
        IDLE,
        MISS_REQUEST,
        MISS_WAIT,
        MISS_UPDATE,
        WRITEBACK_REQUEST,
        WRITEBACK_WAIT
    } state_t;
    
    state_t state, next_state;
    
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
    // Cache State Machine Logic
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
        l3_req = 1'b0;
        l3_we = 1'b0;
        l3_addr = 32'h0;
        l3_wdata = 128'h0;
        l1i_data = 128'h0;
        l1i_valid = 1'b0;
        l1d_rdata = 128'h0;
        l1d_valid = 1'b0;
        
        case (state)
            IDLE: begin
                if (current_req != REQ_NONE) begin
                    if (cache_hit) begin
                        // Cache hit - respond immediately
                        if (current_req == REQ_L1I) begin
                            l1i_data = hit_data;
                            l1i_valid = 1'b1;
                        end else if (current_req == REQ_L1D) begin
                            l1d_rdata = hit_data;
                            l1d_valid = 1'b1;
                        end
                        next_state = IDLE;
                    end else begin
                        // Cache miss - check if victim needs writeback
                        if (victim_dirty) begin
                            next_state = WRITEBACK_REQUEST;
                        end else begin
                            next_state = MISS_REQUEST;
                        end
                    end
                end
            end
            
            WRITEBACK_REQUEST: begin
                // Write back dirty victim to L3
                l3_req = 1'b1;
                l3_we = 1'b1;
                l3_addr = victim_addr;
                l3_wdata = victim_data;
                next_state = WRITEBACK_WAIT;
            end
            
            WRITEBACK_WAIT: begin
                if (l3_valid) begin
                    next_state = MISS_REQUEST;
                end else begin
                    next_state = WRITEBACK_WAIT;
                end
            end
            
            MISS_REQUEST: begin
                // Request data from L3
                l3_req = 1'b1;
                l3_we = 1'b0;
                l3_addr = {req_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
                next_state = MISS_WAIT;
            end
            
            MISS_WAIT: begin
                if (l3_valid) begin
                    next_state = MISS_UPDATE;
                end else begin
                    next_state = MISS_WAIT;
                end
            end
            
            MISS_UPDATE: begin
                // Respond to L1 with data
                if (current_req == REQ_L1I) begin
                    l1i_data = l3_rdata;
                    l1i_valid = 1'b1;
                end else if (current_req == REQ_L1D) begin
                    l1d_rdata = l3_rdata;
                    l1d_valid = 1'b1;
                end
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
            if (state == IDLE && (current_req != REQ_NONE) && cache_hit) begin
                lru_bits[addr_index] <= !hit_way;
                
                // Handle write hit from L1D
                if (current_req == REQ_L1D && req_we) begin
                    if (way0_hit) begin
                        cache_way0[addr_index].data <= req_wdata;
                        cache_way0[addr_index].dirty <= 1'b1;
                    end else if (way1_hit) begin
                        cache_way1[addr_index].data <= req_wdata;
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
                    cache_way0[addr_index].data <= l3_rdata;
                    cache_way0[addr_index].dirty <= 1'b0;
                    lru_bits[addr_index] <= 1'b1;
                end else begin
                    cache_way1[addr_index].valid <= 1'b1;
                    cache_way1[addr_index].tag <= addr_tag;
                    cache_way1[addr_index].data <= l3_rdata;
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
        if (state == IDLE && (current_req != REQ_NONE) && cache_hit) begin
            if (current_req == REQ_L1I) begin
                $display("Time %t: L2 Cache I-HIT - Addr: 0x%08x", $time, req_addr);
            end else begin
                $display("Time %t: L2 Cache D-HIT - Addr: 0x%08x", $time, req_addr);
            end
        end
        if (state == MISS_REQUEST) begin
            $display("Time %t: L2 Cache MISS - Addr: 0x%08x, Requesting from L3", $time, req_addr);
        end
    end
    `endif
    
endmodule