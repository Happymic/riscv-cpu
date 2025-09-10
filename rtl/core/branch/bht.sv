// Branch History Table (BHT)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Per-index 2-bit saturating counters to predict conditional branches as
//   taken/not-taken based on recent history.
//
// Interface:
// - lookup_pc -> prediction: combinational read, predicts taken when MSB=1.
// - update_pc/actual_taken/update_valid: on commit/resolve, bump the counter
//   toward taken/not-taken, saturating at 00/11.
//
// Indexing:
// - Uses bits [BHT_ADDR_BITS+1:2] to index, discarding byte offset and some
//   higher bits. This is a simple direct-mapped predictor.
//
// Reset:
// - Initializes all entries to WEAKLY_NOT_TAKEN to reduce early mispredicts.
// -----------------------------------------------------------------------------

module bht #(
    parameter XLEN = 64,
    parameter BHT_SIZE = 4096,
    parameter BHT_ADDR_BITS = 12
) (
    input  logic clk,
    input  logic rst_n,
    
    // Lookup interface
    input  logic [XLEN-1:0] lookup_pc,
    output logic            prediction,
    
    // Update interface
    input  logic [XLEN-1:0] update_pc,
    input  logic            actual_taken,
    input  logic            update_valid
);

    // 2-bit saturating counter states
    typedef enum logic [1:0] {
        STRONGLY_NOT_TAKEN = 2'b00,
        WEAKLY_NOT_TAKEN   = 2'b01,
        WEAKLY_TAKEN       = 2'b10,
        STRONGLY_TAKEN     = 2'b11
    } prediction_state_t;

    prediction_state_t bht_table [BHT_SIZE-1:0];

    // Address indexing
    logic [BHT_ADDR_BITS-1:0] lookup_index;
    logic [BHT_ADDR_BITS-1:0] update_index;

    assign lookup_index = lookup_pc[BHT_ADDR_BITS+1:2];
    assign update_index = update_pc[BHT_ADDR_BITS+1:2];

    // Prediction logic (taken if weakly or strongly taken)
    assign prediction = bht_table[lookup_index][1];

    // Update logic with 2-bit saturating counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < BHT_SIZE; i++) begin
                bht_table[i] <= WEAKLY_NOT_TAKEN; // Initialize to weakly not taken
            end
        end else if (update_valid) begin
            case (bht_table[update_index])
                STRONGLY_NOT_TAKEN: begin
                    if (actual_taken)
                        bht_table[update_index] <= WEAKLY_NOT_TAKEN;
                end
                WEAKLY_NOT_TAKEN: begin
                    if (actual_taken)
                        bht_table[update_index] <= WEAKLY_TAKEN;
                    else
                        bht_table[update_index] <= STRONGLY_NOT_TAKEN;
                end
                WEAKLY_TAKEN: begin
                    if (actual_taken)
                        bht_table[update_index] <= STRONGLY_TAKEN;
                    else
                        bht_table[update_index] <= WEAKLY_NOT_TAKEN;
                end
                STRONGLY_TAKEN: begin
                    if (!actual_taken)
                        bht_table[update_index] <= WEAKLY_TAKEN;
                end
            endcase
        end
    end

endmodule
