// Cache Controller
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Role:
// - Orchestrates multi-level cache maintenance (flush/invalidate) and handles
//   external snoop requests in a simplified form. Also exposes counters for
//   basic performance visibility.
//
// Interfaces:
// - Flush/invalidate: broadcast control to L1I/L1D/L2/L3 and wait until not busy.
// - Snoop: placeholder state machine that would look up tags and return data.
// - Perf counters: wires for hit/miss counts expected from the caches.
//
// Notes:
// - The snoop path here is a stub (always miss); integrate with real tag/data
//   RAMs to support coherency.
// -----------------------------------------------------------------------------

module cache_ctrl #(
    parameter XLEN = 64
) (
    input  logic clk,
    input  logic rst_n,
    
    // CPU control interface
    input  logic        cache_flush,
    input  logic        cache_invalidate,
    input  logic [XLEN-1:0] flush_addr,
    output logic        flush_complete,
    
    // L1 I-Cache control
    output logic        l1i_flush,
    input  logic        l1i_busy,
    
    // L1 D-Cache control
    output logic        l1d_flush,
    input  logic        l1d_busy,
    
    // L2 Cache control
    output logic        l2_flush,
    input  logic        l2_busy,
    
    // L3 Cache control
    output logic        l3_flush,
    input  logic        l3_busy,
    
    // Cache coherency interface
    input  logic        snoop_req,
    input  logic [XLEN-1:0] snoop_addr,
    input  logic [2:0]  snoop_type, // 000: read, 001: write, 010: invalidate
    output logic        snoop_ack,
    output logic        snoop_hit,
    output logic [511:0] snoop_data,
    
    // Performance counters
    output logic [31:0] l1i_hit_count,
    output logic [31:0] l1i_miss_count,
    output logic [31:0] l1d_hit_count,
    output logic [31:0] l1d_miss_count,
    output logic [31:0] l2_hit_count,
    output logic [31:0] l2_miss_count
);

    // State machine for cache operations
    typedef enum logic [2:0] {
        IDLE,
        FLUSH_L1I,
        FLUSH_L1D,
        FLUSH_L2,
        FLUSH_L3,
        FLUSH_COMPLETE
    } ctrl_state_t;
    
    ctrl_state_t ctrl_state, next_ctrl_state;

    // State machine logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_state <= IDLE;
        end else begin
            ctrl_state <= next_ctrl_state;
        end
    end

    always_comb begin
        next_ctrl_state = ctrl_state;
        case (ctrl_state)
            IDLE: begin
                if (cache_flush || cache_invalidate) begin
                    next_ctrl_state = FLUSH_L1I;
                end
            end
            FLUSH_L1I: begin
                if (!l1i_busy) begin
                    next_ctrl_state = FLUSH_L1D;
                end
            end
            FLUSH_L1D: begin
                if (!l1d_busy) begin
                    next_ctrl_state = FLUSH_L2;
                end
            end
            FLUSH_L2: begin
                if (!l2_busy) begin
                    next_ctrl_state = FLUSH_L3;
                end
            end
            FLUSH_L3: begin
                if (!l3_busy) begin
                    next_ctrl_state = FLUSH_COMPLETE;
                end
            end
            FLUSH_COMPLETE: begin
                next_ctrl_state = IDLE;
            end
        endcase
    end

    // Control signal generation
    assign l1i_flush = (ctrl_state == FLUSH_L1I);
    assign l1d_flush = (ctrl_state == FLUSH_L1D);
    assign l2_flush = (ctrl_state == FLUSH_L2);
    assign l3_flush = (ctrl_state == FLUSH_L3);
    assign flush_complete = (ctrl_state == FLUSH_COMPLETE);

    // Snoop handling (simplified)
    typedef enum logic [1:0] {
        SNOOP_IDLE,
        SNOOP_PROCESS,
        SNOOP_RESPOND
    } snoop_state_t;
    
    snoop_state_t snoop_state, next_snoop_state;
    logic snoop_hit_reg;
    logic [511:0] snoop_data_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            snoop_state <= SNOOP_IDLE;
            snoop_hit_reg <= 1'b0;
            snoop_data_reg <= '0;
        end else begin
            snoop_state <= next_snoop_state;
            
            case (snoop_state)
                SNOOP_PROCESS: begin
                    // Simplified snoop hit detection
                    snoop_hit_reg <= 1'b0; // Would need actual cache lookup
                    snoop_data_reg <= '0;   // Would return actual data
                end
            endcase
        end
    end

    always_comb begin
        next_snoop_state = snoop_state;
        case (snoop_state)
            SNOOP_IDLE: begin
                if (snoop_req) begin
                    next_snoop_state = SNOOP_PROCESS;
                end
            end
            SNOOP_PROCESS: begin
                next_snoop_state = SNOOP_RESPOND;
            end
            SNOOP_RESPOND: begin
                if (!snoop_req) begin
                    next_snoop_state = SNOOP_IDLE;
                end
            end
        endcase
    end

    assign snoop_ack = (snoop_state == SNOOP_RESPOND);
    assign snoop_hit = snoop_hit_reg;
    assign snoop_data = snoop_data_reg;

    // Performance counters (simplified - would connect to actual cache signals)
    logic [31:0] l1i_hits, l1i_misses;
    logic [31:0] l1d_hits, l1d_misses;
    logic [31:0] l2_hits, l2_misses;

    // These would be driven by actual hit/miss signals from caches
    assign l1i_hit_count = l1i_hits;
    assign l1i_miss_count = l1i_misses;
    assign l1d_hit_count = l1d_hits;
    assign l1d_miss_count = l1d_misses;
    assign l2_hit_count = l2_hits;
    assign l2_miss_count = l2_misses;

    // Performance counter update logic (placeholder)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l1i_hits <= '0;
            l1i_misses <= '0;
            l1d_hits <= '0;
            l1d_misses <= '0;
            l2_hits <= '0;
            l2_misses <= '0;
        end else begin
            // Would increment based on actual cache hit/miss signals
        end
    end

endmodule
