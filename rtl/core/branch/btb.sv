// Branch Target Buffer (BTB)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Cache recently seen branch/jump target addresses keyed by PC. When the BTB
//   hits for the lookup PC, supply the predicted target to the IF stage.
//
// Organization:
// - Direct-mapped table indexed by middle bits of PC; each entry stores a tag
//   (upper PC bits), a valid bit, and the predicted target address.
//
// Update policy:
// - On taken branches/jumps (update_valid && update_taken), write the target.
// - Non-taken branches are not stored.
// -----------------------------------------------------------------------------

module btb #(
    parameter XLEN = 64,
    parameter BTB_SIZE = 256,
    parameter BTB_ADDR_BITS = 8
) (
    input  logic clk,
    input  logic rst_n,
    
    // Lookup interface
    input  logic [XLEN-1:0] lookup_pc,
    output logic [XLEN-1:0] predicted_target,
    output logic            hit,
    
    // Update interface
    input  logic [XLEN-1:0] update_pc,
    input  logic [XLEN-1:0] update_target,
    input  logic            update_taken,
    input  logic            update_valid
);

    // BTB entry structure
    typedef struct packed {
        logic valid;
        logic [XLEN-BTB_ADDR_BITS-1:0] tag;
        logic [XLEN-1:0] target;
    } btb_entry_t;

    btb_entry_t btb_table [BTB_SIZE-1:0];

    // Address indexing
    logic [BTB_ADDR_BITS-1:0] lookup_index;
    logic [BTB_ADDR_BITS-1:0] update_index;
    logic [XLEN-BTB_ADDR_BITS-1:0] lookup_tag;
    logic [XLEN-BTB_ADDR_BITS-1:0] update_tag;

    assign lookup_index = lookup_pc[BTB_ADDR_BITS+1:2];
    assign update_index = update_pc[BTB_ADDR_BITS+1:2];
    assign lookup_tag = lookup_pc[XLEN-1:BTB_ADDR_BITS+2];
    assign update_tag = update_pc[XLEN-1:BTB_ADDR_BITS+2];

    // Lookup logic
    assign hit = btb_table[lookup_index].valid && 
                 (btb_table[lookup_index].tag == lookup_tag);
    assign predicted_target = hit ? btb_table[lookup_index].target : '0;

    // Update logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < BTB_SIZE; i++) begin
                btb_table[i].valid <= 1'b0;
                btb_table[i].tag <= '0;
                btb_table[i].target <= '0;
            end
        end else if (update_valid && update_taken) begin
            btb_table[update_index].valid <= 1'b1;
            btb_table[update_index].tag <= update_tag;
            btb_table[update_index].target <= update_target;
        end
    end

endmodule
