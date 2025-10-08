//////////////////////////////////////////////////////////////////////////////////
// Module: tlb
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Translation Lookaside Buffer (TLB) for virtual memory translation
//              16-entry fully associative TLB with LRU replacement
//              Caches virtual-to-physical address translations
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module tlb #(
    parameter TLB_ENTRIES = 16              // Number of TLB entries
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // Lookup interface
    input  logic        req,                // TLB lookup request
    input  logic [19:0] vpn,                // Virtual page number (20 bits for Sv32)
    output logic [21:0] ppn,                // Physical page number (22 bits)
    output logic        hit,                // TLB hit signal
    output logic        valid,              // Translation valid
    output logic [7:0]  pte_flags,          // PTE flags from TLB entry
    
    // Update interface
    input  logic        update_en,          // Update enable
    input  logic [19:0] update_vpn,         // VPN to update
    input  logic [21:0] update_ppn,         // PPN to update
    input  logic [7:0]  update_flags,       // Flags to update
    
    // Invalidation interface
    input  logic        invalidate_all,     // Invalidate all entries (SFENCE.VMA)
    input  logic [19:0] invalidate_vpn,     // VPN to invalidate
    input  logic        invalidate_en       // Single entry invalidation enable
);

    //////////////////////////////////////////////////////////////////////////////////
    // TLB Entry Structure
    //////////////////////////////////////////////////////////////////////////////////
    
    typedef struct packed {
        logic        valid;                 // Valid bit
        logic [19:0] vpn;                   // Virtual page number
        logic [21:0] ppn;                   // Physical page number
        logic [7:0]  flags;                 // PTE flags (V,R,W,X,U,G,A,D)
        logic        global;                // Global bit (G flag)
    } tlb_entry_t;
    
    // TLB storage array
    tlb_entry_t tlb_entries [TLB_ENTRIES];
    
    // LRU counters for replacement policy
    logic [$clog2(TLB_ENTRIES)-1:0] lru_counter [TLB_ENTRIES];
    
    //////////////////////////////////////////////////////////////////////////////////
    // TLB Lookup Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [TLB_ENTRIES-1:0] entry_match;
    logic [$clog2(TLB_ENTRIES)-1:0] hit_index;
    logic entry_hit;
    
    // Check all entries for match
    genvar i;
    generate
        for (i = 0; i < TLB_ENTRIES; i = i + 1) begin : gen_match_logic
            always_comb begin
                entry_match[i] = tlb_entries[i].valid && (tlb_entries[i].vpn == vpn);
            end
        end
    endgenerate
    
    // Priority encoder to find first matching entry
    always_comb begin
        hit_index = '0;
        entry_hit = 1'b0;
        
        for (int j = 0; j < TLB_ENTRIES; j = j + 1) begin
            if (entry_match[j]) begin
                hit_index = j;
                entry_hit = 1'b1;
                break;
            end
        end
    end
    
    // Output assignment
    always_comb begin
        if (req && entry_hit) begin
            hit = 1'b1;
            valid = tlb_entries[hit_index].valid;
            ppn = tlb_entries[hit_index].ppn;
            pte_flags = tlb_entries[hit_index].flags;
        end else begin
            hit = 1'b0;
            valid = 1'b0;
            ppn = 22'h0;
            pte_flags = 8'h0;
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // LRU Replacement Policy
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [$clog2(TLB_ENTRIES)-1:0] lru_victim;
    logic [$clog2(TLB_ENTRIES)-1:0] max_lru_value;
    
    // Find LRU victim (entry with highest counter value)
    always_comb begin
        lru_victim = 0;
        max_lru_value = lru_counter[0];
        
        for (int k = 1; k < TLB_ENTRIES; k = k + 1) begin
            if (lru_counter[k] > max_lru_value) begin
                max_lru_value = lru_counter[k];
                lru_victim = k;
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // TLB Update and Management Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    integer idx;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all TLB entries
            for (idx = 0; idx < TLB_ENTRIES; idx = idx + 1) begin
                tlb_entries[idx].valid <= 1'b0;
                tlb_entries[idx].vpn <= 20'h0;
                tlb_entries[idx].ppn <= 22'h0;
                tlb_entries[idx].flags <= 8'h0;
                tlb_entries[idx].global <= 1'b0;
                lru_counter[idx] <= idx;  // Initialize with different values
            end
        end else begin
            // Handle invalidation requests
            if (invalidate_all) begin
                // Invalidate all non-global entries (SFENCE.VMA without arguments)
                for (idx = 0; idx < TLB_ENTRIES; idx = idx + 1) begin
                    if (!tlb_entries[idx].global) begin
                        tlb_entries[idx].valid <= 1'b0;
                    end
                end
            end else if (invalidate_en) begin
                // Invalidate specific VPN (SFENCE.VMA with address)
                for (idx = 0; idx < TLB_ENTRIES; idx = idx + 1) begin
                    if (tlb_entries[idx].valid && (tlb_entries[idx].vpn == invalidate_vpn)) begin
                        tlb_entries[idx].valid <= 1'b0;
                    end
                end
            end
            
            // Update LRU counters on access
            if (req && entry_hit) begin
                // Reset accessed entry's counter to 0
                lru_counter[hit_index] <= '0;
                
                // Increment all other counters
                for (idx = 0; idx < TLB_ENTRIES; idx = idx + 1) begin
                    if (idx != hit_index) begin
                        lru_counter[idx] <= lru_counter[idx] + 1;
                    end
                end
            end
            
            // Handle TLB updates (new translation)
            if (update_en) begin
                // Check if VPN already exists in TLB
                logic update_existing;
                logic [$clog2(TLB_ENTRIES)-1:0] existing_index;
                
                update_existing = 1'b0;
                existing_index = '0;
                
                for (idx = 0; idx < TLB_ENTRIES; idx = idx + 1) begin
                    if (tlb_entries[idx].valid && (tlb_entries[idx].vpn == update_vpn)) begin
                        update_existing = 1'b1;
                        existing_index = idx;
                        break;
                    end
                end
                
                if (update_existing) begin
                    // Update existing entry
                    tlb_entries[existing_index].ppn <= update_ppn;
                    tlb_entries[existing_index].flags <= update_flags;
                    tlb_entries[existing_index].global <= update_flags[5];  // G bit
                    
                    // Reset LRU counter for updated entry
                    lru_counter[existing_index] <= '0;
                    for (idx = 0; idx < TLB_ENTRIES; idx = idx + 1) begin
                        if (idx != existing_index) begin
                            lru_counter[idx] <= lru_counter[idx] + 1;
                        end
                    end
                end else begin
                    // Install new entry in LRU victim slot
                    tlb_entries[lru_victim].valid <= 1'b1;
                    tlb_entries[lru_victim].vpn <= update_vpn;
                    tlb_entries[lru_victim].ppn <= update_ppn;
                    tlb_entries[lru_victim].flags <= update_flags;
                    tlb_entries[lru_victim].global <= update_flags[5];  // G bit
                    
                    // Reset LRU counter for new entry
                    lru_counter[lru_victim] <= '0;
                    for (idx = 0; idx < TLB_ENTRIES; idx = idx + 1) begin
                        if (idx != lru_victim) begin
                            lru_counter[idx] <= lru_counter[idx] + 1;
                        end
                    end
                end
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Debug Output (simulation only)
    //////////////////////////////////////////////////////////////////////////////////
    
    `ifdef SIMULATION
    always @(posedge clk) begin
        if (req && hit) begin
            $display("Time %t: TLB HIT - VPN: 0x%05x -> PPN: 0x%06x, Flags: 0x%02x", 
                    $time, vpn, ppn, pte_flags);
        end
        if (update_en) begin
            $display("Time %t: TLB UPDATE - VPN: 0x%05x -> PPN: 0x%06x, Victim: %0d", 
                    $time, update_vpn, update_ppn, lru_victim);
        end
        if (invalidate_all) begin
            $display("Time %t: TLB FLUSH ALL", $time);
        end
        if (invalidate_en) begin
            $display("Time %t: TLB INVALIDATE - VPN: 0x%05x", $time, invalidate_vpn);
        end
    end
    `endif
    
endmodule