//////////////////////////////////////////////////////////////////////////////////
// Module: l1_dcache
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: L1 Data Cache - 2-way set associative
//              Supports both read and write operations with write-back policy
//              Implements MESI coherence protocol states
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module l1_dcache #(
    parameter CACHE_SIZE_KB   = 32,         // Cache size in KB
    parameter LINE_SIZE_BYTES = 16,         // Cache line size in bytes
    parameter ASSOCIATIVITY   = 2           // Number of ways (2-way set associative)
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // CPU interface
    input  logic        req,                // Cache request
    input  logic        we,                 // Write enable
    input  logic [31:0] addr,               // Request address
    input  logic [31:0] wdata,              // Write data
    input  logic [3:0]  be,                 // Byte enable
    output logic [31:0] rdata,              // Read data
    output logic        hit,                // Cache hit signal
    output logic        stall,              // Stall signal (miss handling)
    
    // L2 cache interface
    output logic        l2_req,             // L2 cache request
    output logic        l2_we,              // L2 cache write enable
    output logic [31:0] l2_addr,            // L2 cache address
    output logic [127:0] l2_wdata,          // L2 cache write data (full line)
    input  logic [127:0] l2_rdata,          // L2 cache read data (full line)
    input  logic        l2_valid            // L2 data valid
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
    localparam WORDS_PER_LINE    = LINE_SIZE_BYTES / 4;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Cache Line Structure with MESI States
    //////////////////////////////////////////////////////////////////////////////////
    
    typedef enum logic [1:0] {
        INVALID = 2'b00,
        SHARED  = 2'b01,
        EXCLUSIVE = 2'b10,
        MODIFIED = 2'b11
    } mesi_state_t;
    
    typedef struct packed {
        logic               valid;          // Valid bit
        mesi_state_t        state;          // MESI coherence state
        logic [TAG_BITS-1:0] tag;           // Tag bits
        logic [127:0]       data;           // 128-bit data (4 words)
        logic               dirty;          // Dirty bit for write-back
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
    logic [1:0]            word_offset;
    
    assign addr_tag    = addr[31:31-TAG_BITS+1];
    assign addr_index  = addr[31-TAG_BITS:OFFSET_BITS];
    assign addr_offset = addr[OFFSET_BITS-1:0];
    assign word_offset = addr_offset[3:2];
    
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
                  (cache_way0[addr_index].tag == addr_tag) &&
                  (cache_way0[addr_index].state != INVALID);
        
        // Check way 1
        way1_hit = cache_way1[addr_index].valid && 
                  (cache_way1[addr_index].tag == addr_tag) &&
                  (cache_way1[addr_index].state != INVALID);
        
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
    // Data Read/Write Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [127:0] updated_data;
    logic [31:0] write_word;
    
    // Data read multiplexer
    always_comb begin
        case (word_offset)
            2'b00: rdata = hit_data[31:0];
            2'b01: rdata = hit_data[63:32];
            2'b10: rdata = hit_data[95:64];
            2'b11: rdata = hit_data[127:96];
        endcase
    end
    
    // Data write update logic
    always_comb begin
        updated_data = hit_data;
        
        // Apply byte enables for write
        case (word_offset)
            2'b00: begin
                if (be[0]) updated_data[7:0]   = wdata[7:0];
                if (be[1]) updated_data[15:8]  = wdata[15:8];
                if (be[2]) updated_data[23:16] = wdata[23:16];
                if (be[3]) updated_data[31:24] = wdata[31:24];
            end
            2'b01: begin
                if (be[0]) updated_data[39:32] = wdata[7:0];
                if (be[1]) updated_data[47:40] = wdata[15:8];
                if (be[2]) updated_data[55:48] = wdata[23:16];
                if (be[3]) updated_data[63:56] = wdata[31:24];
            end
            2'b10: begin
                if (be[0]) updated_data[71:64] = wdata[7:0];
                if (be[1]) updated_data[79:72] = wdata[15:8];
                if (be[2]) updated_data[87:80] = wdata[23:16];
                if (be[3]) updated_data[95:88] = wdata[31:24];
            end
            2'b11: begin
                if (be[0]) updated_data[103:96]  = wdata[7:0];
                if (be[1]) updated_data[111:104] = wdata[15:8];
                if (be[2]) updated_data[119:112] = wdata[23:16];
                if (be[3]) updated_data[127:120] = wdata[31:24];
            end
        endcase
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
        l2_req = 1'b0;
        l2_we = 1'b0;
        l2_addr = 32'h0;
        l2_wdata = 128'h0;
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
                        // Cache miss - check if victim needs writeback
                        stall = 1'b1;
                        if (victim_dirty) begin
                            next_state = WRITEBACK_REQUEST;
                        end else begin
                            next_state = MISS_REQUEST;
                        end
                    end
                end
            end
            
            WRITEBACK_REQUEST: begin
                // Write back dirty victim
                stall = 1'b1;
                l2_req = 1'b1;
                l2_we = 1'b1;
                l2_addr = victim_addr;
                l2_wdata = victim_data;
                next_state = WRITEBACK_WAIT;
            end
            
            WRITEBACK_WAIT: begin
                stall = 1'b1;
                if (l2_valid) begin
                    next_state = MISS_REQUEST;
                end else begin
                    next_state = WRITEBACK_WAIT;
                end
            end
            
            MISS_REQUEST: begin
                // Request data from L2
                stall = 1'b1;
                l2_req = 1'b1;
                l2_we = 1'b0;
                l2_addr = {addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
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
                cache_way0[i].state <= INVALID;
                cache_way0[i].tag <= '0;
                cache_way0[i].data <= 128'h0;
                cache_way0[i].dirty <= 1'b0;
                cache_way1[i].valid <= 1'b0;
                cache_way1[i].state <= INVALID;
                cache_way1[i].tag <= '0;
                cache_way1[i].data <= 128'h0;
                cache_way1[i].dirty <= 1'b0;
            end
            lru_bits <= '0;
        end else begin
            // Update LRU on hit
            if (state == IDLE && req && cache_hit) begin
                lru_bits[addr_index] <= !hit_way;
                
                // Handle write hit
                if (we) begin
                    if (way0_hit) begin
                        cache_way0[addr_index].data <= updated_data;
                        cache_way0[addr_index].dirty <= 1'b1;
                        cache_way0[addr_index].state <= MODIFIED;
                    end else if (way1_hit) begin
                        cache_way1[addr_index].data <= updated_data;
                        cache_way1[addr_index].dirty <= 1'b1;
                        cache_way1[addr_index].state <= MODIFIED;
                    end
                end
            end
            
            // Update cache on miss
            if (state == MISS_UPDATE) begin
                // Replace victim way
                if (victim_way == 1'b0) begin
                    cache_way0[addr_index].valid <= 1'b1;
                    cache_way0[addr_index].tag <= addr_tag;
                    cache_way0[addr_index].data <= l2_rdata;
                    cache_way0[addr_index].dirty <= 1'b0;
                    cache_way0[addr_index].state <= SHARED;
                    lru_bits[addr_index] <= 1'b1;
                end else begin
                    cache_way1[addr_index].valid <= 1'b1;
                    cache_way1[addr_index].tag <= addr_tag;
                    cache_way1[addr_index].data <= l2_rdata;
                    cache_way1[addr_index].dirty <= 1'b0;
                    cache_way1[addr_index].state <= SHARED;
                    lru_bits[addr_index] <= 1'b0;
                end
            end
        end
    end
    
endmodule