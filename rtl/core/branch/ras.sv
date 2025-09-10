// Return Address Stack (RAS)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Track call/return nesting to predict return targets (JAL/JALR to ra/x1).
//   Push return addresses on calls; pop on returns.
//
// Interface:
// - push_addr/push_valid: push PC+4 upon a call.
// - pop_addr/pop_valid  : pop and present the top return address on a return.
// - empty/full          : stack status to guard operations and prediction.
//
// Notes:
// - Simultaneous push+pop keeps depth when not empty; behavior on empty pop is
//   guarded to avoid underflow and simply returns 0.
// -----------------------------------------------------------------------------

module ras #(
    parameter XLEN = 64,
    parameter RAS_DEPTH = 16,
    parameter RAS_ADDR_BITS = 4
) (
    input  logic clk,
    input  logic rst_n,
    
    // Push interface (for function calls)
    input  logic [XLEN-1:0] push_addr,
    input  logic            push_valid,
    
    // Pop interface (for function returns)
    output logic [XLEN-1:0] pop_addr,
    input  logic            pop_valid,
    
    // Status
    output logic            empty,
    output logic            full
);

    // RAS storage
    logic [XLEN-1:0] ras_stack [RAS_DEPTH-1:0];
    logic [RAS_ADDR_BITS:0] ras_pointer; // Extra bit for full detection

    // Status signals
    assign empty = (ras_pointer == '0);
    assign full = (ras_pointer == RAS_DEPTH);
    assign pop_addr = empty ? '0 : ras_stack[ras_pointer-1];

    // Stack operations
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ras_pointer <= '0;
            for (int i = 0; i < RAS_DEPTH; i++) begin
                ras_stack[i] <= '0;
            end
        end else begin
            case ({push_valid, pop_valid})
                2'b10: begin // Push only
                    if (!full) begin
                        ras_stack[ras_pointer] <= push_addr;
                        ras_pointer <= ras_pointer + 1;
                    end
                end
                2'b01: begin // Pop only
                    if (!empty) begin
                        ras_pointer <= ras_pointer - 1;
                    end
                end
                2'b11: begin // Push and pop simultaneously
                    if (!empty) begin
                        ras_stack[ras_pointer-1] <= push_addr;
                        // Pointer stays the same
                    end else begin
                        // Stack was empty, just push
                        ras_stack[0] <= push_addr;
                        ras_pointer <= 1;
                    end
                end
                default: begin
                    // No operation
                end
            endcase
        end
    end

endmodule
