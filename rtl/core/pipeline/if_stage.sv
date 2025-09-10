// Instruction Fetch Stage (IF)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Holds the Program Counter (PC), computes the next PC based on sequential
//   flow (PC+4) or branch/redirects, and issues instruction fetch requests.
// - Outputs the current PC and instruction to the ID stage.
//
// Interface summary:
// - Control in:
//   - stall: when 1, freeze PC and hold outputs stable (backpressure).
//   - flush: when 1, squash current instruction by outputting a NOP.
//   - branch_taken: redirect request; next PC becomes branch_target.
//   - branch_target[XLEN-1:0]: absolute target address for redirect.
// - IMEM interface:
//   - imem_addr[XLEN-1:0] (out): address of instruction fetch.
//   - imem_data[ILEN-1:0] (in) : instruction word returned by memory/cache.
//   - imem_valid (in): asserted when imem_data is valid for current address.
// - Outputs to ID:
//   - pc_out: PC of this instruction.
//   - instr_out: instruction word (or NOP when flush asserted).
//   - valid_out: 1 if this instruction is valid (not flushed) and imem_valid.
//
// Timing/Behavior:
// - PC is updated on clk rising edge when not stalled.
// - On flush, instr_out turns into NOP (ADDI x0,x0,0) to inject a bubble.
// - If branch_taken is asserted, next sequential address is overridden by target.
// -----------------------------------------------------------------------------

module if_stage #(
    parameter XLEN = 64,
    parameter ILEN = 32
) (
    input  logic clk,
    input  logic rst_n,
    
    // Control signals
    input  logic stall,
    input  logic flush,
    input  logic branch_taken,
    input  logic [XLEN-1:0] branch_target,
    
    // Memory interface
    output logic [XLEN-1:0] imem_addr,
    input  logic [ILEN-1:0] imem_data,
    input  logic            imem_valid,
    
    // Output to ID stage
    output logic [XLEN-1:0] pc_out,
    output logic [ILEN-1:0] instr_out,
    output logic            valid_out
);

    logic [XLEN-1:0] pc_reg;
    logic [XLEN-1:0] pc_next;
    
    // PC logic
    always_comb begin
        if (branch_taken) 
            pc_next = branch_target;
        else 
            pc_next = pc_reg + 4;
    end
    
    // PC register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_reg <= '0;
        else if (!stall)
            pc_reg <= pc_next;
    end
    
    // Output assignments
    assign imem_addr = pc_reg;
    assign pc_out = pc_reg;
    assign instr_out = flush ? 32'h00000013 : imem_data; // NOP on flush
    assign valid_out = !flush && imem_valid;

endmodule
