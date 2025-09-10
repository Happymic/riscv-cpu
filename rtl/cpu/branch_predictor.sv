//////////////////////////////////////////////////////////////////////////////////
// Module: branch_predictor
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Branch predictor with Branch Target Buffer (BTB) and 2-bit saturating counter
//              Implements dynamic branch prediction to reduce control hazards
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module branch_predictor #(
    parameter BTB_SIZE = 64,                // Number of BTB entries
    parameter BTB_INDEX_BITS = 6            // log2(BTB_SIZE)
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // Prediction interface
    input  logic [31:0] pc,                 // Current PC for prediction
    output logic        btb_hit,            // BTB hit signal
    output logic [31:0] btb_target,         // Predicted branch target
    
    // Update interface
    input  logic        update_en,          // Update enable
    input  logic [31:0] update_pc,          // PC of branch to update
    input  logic [31:0] update_target,      // Actual branch target
    input  logic        update_taken        // Actual branch outcome
);

    //////////////////////////////////////////////////////////////////////////////////
    // BTB Entry Structure
    //////////////////////////////////////////////////////////////////////////////////
    
    typedef struct packed {
        logic        valid;                 // Entry valid bit
        logic [31:0] tag;                   // PC tag
        logic [31:0] target;                // Branch target address
        logic [1:0]  state;                 // 2-bit saturating counter state
    } btb_entry_t;
    
    // BTB storage
    btb_entry_t btb [0:BTB_SIZE-1];
    
    // 2-bit saturating counter states
    localparam STRONGLY_NOT_TAKEN = 2'b00;
    localparam WEAKLY_NOT_TAKEN   = 2'b01;
    localparam WEAKLY_TAKEN       = 2'b10;
    localparam STRONGLY_TAKEN     = 2'b11;
    
    // Internal signals
    logic [BTB_INDEX_BITS-1:0] predict_index;
    logic [BTB_INDEX_BITS-1:0] update_index;
    logic [31:0] predict_tag;
    logic [31:0] update_tag;
    logic        predict_taken;
    logic [1:0]  next_state;
    
    // Integer for initialization
    integer i;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Index and Tag Extraction
    //////////////////////////////////////////////////////////////////////////////////
    
    // Extract index and tag from PC (simple direct-mapped)
    assign predict_index = pc[BTB_INDEX_BITS+1:2];  // Ignore lowest 2 bits (word aligned)
    assign predict_tag = pc;
    
    assign update_index = update_pc[BTB_INDEX_BITS+1:2];
    assign update_tag = update_pc;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Branch Prediction Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Default: no prediction
        btb_hit = 1'b0;
        btb_target = 32'h0;
        predict_taken = 1'b0;
        
        // Check BTB entry
        if (btb[predict_index].valid && (btb[predict_index].tag == predict_tag)) begin
            // BTB hit
            btb_hit = 1'b1;
            btb_target = btb[predict_index].target;
            
            // Check 2-bit counter state
            predict_taken = (btb[predict_index].state >= WEAKLY_TAKEN);
            
            // Only predict branch if counter predicts taken
            if (!predict_taken) begin
                btb_hit = 1'b0;  // Don't redirect if predicting not taken
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // State Machine Update Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Default: maintain current state
        next_state = btb[update_index].state;
        
        if (update_taken) begin
            // Branch was taken - increment counter (saturating)
            case (btb[update_index].state)
                STRONGLY_NOT_TAKEN: next_state = WEAKLY_NOT_TAKEN;
                WEAKLY_NOT_TAKEN:   next_state = WEAKLY_TAKEN;
                WEAKLY_TAKEN:       next_state = STRONGLY_TAKEN;
                STRONGLY_TAKEN:     next_state = STRONGLY_TAKEN;
            endcase
        end else begin
            // Branch was not taken - decrement counter (saturating)
            case (btb[update_index].state)
                STRONGLY_NOT_TAKEN: next_state = STRONGLY_NOT_TAKEN;
                WEAKLY_NOT_TAKEN:   next_state = STRONGLY_NOT_TAKEN;
                WEAKLY_TAKEN:       next_state = WEAKLY_NOT_TAKEN;
                STRONGLY_TAKEN:     next_state = WEAKLY_TAKEN;
            endcase
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // BTB Update Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset BTB
            for (i = 0; i < BTB_SIZE; i = i + 1) begin
                btb[i].valid <= 1'b0;
                btb[i].tag <= 32'h0;
                btb[i].target <= 32'h0;
                btb[i].state <= WEAKLY_TAKEN;  // Initial prediction: weakly taken
            end
        end else if (update_en) begin
            // Update BTB entry
            if (btb[update_index].valid && (btb[update_index].tag == update_tag)) begin
                // Existing entry - update state and target
                btb[update_index].state <= next_state;
                btb[update_index].target <= update_target;
            end else if (update_taken) begin
                // New entry - only allocate if branch was taken
                btb[update_index].valid <= 1'b1;
                btb[update_index].tag <= update_tag;
                btb[update_index].target <= update_target;
                btb[update_index].state <= WEAKLY_TAKEN;
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Debug Output (simulation only)
    //////////////////////////////////////////////////////////////////////////////////
    
    `ifdef SIMULATION
    always @(posedge clk) begin
        if (update_en) begin
            $display("Time %t: BTB update - PC: 0x%08x, Target: 0x%08x, Taken: %b, State: %b", 
                    $time, update_pc, update_target, update_taken, next_state);
        end
        if (btb_hit) begin
            $display("Time %t: BTB hit - PC: 0x%08x, Predicted target: 0x%08x", 
                    $time, pc, btb_target);
        end
    end
    `endif
    
endmodule