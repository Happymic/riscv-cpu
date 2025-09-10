// Branch Predictor Top Module
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Role:
// - Front-end predictor combining BTB (target), BHT (direction), and RAS
//   (return targets). It also includes lightweight instruction decode to
//   categorize branches vs calls vs returns for proper predictor usage.
//
// Inputs:
// - pc/instruction: current fetch PC and instruction word for pre-decode.
// - Update sideband (from execute/commit): update_pc, actual_target,
//   actual_taken, plus type hints (is_branch/is_call/is_return).
//
// Outputs:
// - predicted_taken: whether to redirect fetch away from pc+4.
// - predicted_target: target address to fetch when predicted_taken=1.
//
// Policy:
// - JAL is always taken. JALR/RET rely on BTB/RAS. Conditional branches use
//   BHT to predict taken and require BTB hit to provide target.
// -----------------------------------------------------------------------------

module branch_predictor #(
    parameter XLEN = 64
) (
    input  logic clk,
    input  logic rst_n,
    
    // Prediction interface
    input  logic [XLEN-1:0] pc,
    input  logic [31:0]     instruction,
    output logic [XLEN-1:0] predicted_target,
    output logic            predicted_taken,
    
    // Update interface
    input  logic [XLEN-1:0] update_pc,
    input  logic [XLEN-1:0] actual_target,
    input  logic            actual_taken,
    input  logic            is_branch,
    input  logic            is_call,
    input  logic            is_return,
    input  logic            update_valid
);

    // Internal signals
    logic btb_hit;
    logic [XLEN-1:0] btb_target;
    logic bht_prediction;
    logic [XLEN-1:0] ras_target;
    logic ras_empty;

    // Instruction decode for branch type detection
    logic [6:0] opcode;
    logic [4:0] rs1, rd;
    logic is_jal, is_jalr, is_branch_instr;
    logic is_call_instr, is_return_instr;

    assign opcode = instruction[6:0];
    assign rs1 = instruction[19:15];
    assign rd = instruction[11:7];

    // Decode branch types
    assign is_jal = (opcode == 7'b1101111);
    assign is_jalr = (opcode == 7'b1100111);
    assign is_branch_instr = (opcode == 7'b1100011);

    // Call detection: JAL/JALR with rd != x0
    assign is_call_instr = (is_jal || is_jalr) && (rd != 5'b00000);

    // Return detection: JALR with rs1 == x1 (ra) and rd == x0
    assign is_return_instr = is_jalr && (rs1 == 5'b00001) && (rd == 5'b00000);

    // BTB instance
    btb u_btb (
        .clk(clk),
        .rst_n(rst_n),
        .lookup_pc(pc),
        .predicted_target(btb_target),
        .hit(btb_hit),
        .update_pc(update_pc),
        .update_target(actual_target),
        .update_taken(actual_taken),
        .update_valid(update_valid && (is_branch || is_call || is_return))
    );

    // BHT instance
    bht u_bht (
        .clk(clk),
        .rst_n(rst_n),
        .lookup_pc(pc),
        .prediction(bht_prediction),
        .update_pc(update_pc),
        .actual_taken(actual_taken),
        .update_valid(update_valid && is_branch)
    );

    // RAS instance
    ras u_ras (
        .clk(clk),
        .rst_n(rst_n),
        .push_addr(update_pc + 4),
        .push_valid(update_valid && is_call),
        .pop_addr(ras_target),
        .pop_valid(update_valid && is_return),
        .empty(ras_empty),
        .full()
    );

    // Prediction logic
    always_comb begin
        predicted_taken = 1'b0;
        predicted_target = pc + 4;

        if (is_jal) begin
            // JAL is always taken
            predicted_taken = 1'b1;
            predicted_target = btb_hit ? btb_target : (pc + 4);
        end else if (is_return_instr) begin
            // Return prediction from RAS
            predicted_taken = !ras_empty;
            predicted_target = ras_empty ? (pc + 4) : ras_target;
        end else if (is_jalr) begin
            // JALR prediction from BTB
            predicted_taken = btb_hit;
            predicted_target = btb_hit ? btb_target : (pc + 4);
        end else if (is_branch_instr) begin
            // Conditional branch prediction
            predicted_taken = bht_prediction && btb_hit;
            predicted_target = (bht_prediction && btb_hit) ? btb_target : (pc + 4);
        end
    end

endmodule
