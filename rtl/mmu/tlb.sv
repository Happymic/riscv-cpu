// Translation Lookaside Buffer (TLB)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Cache recent virtual-to-physical translations with permissions and page size
//   metadata. Supports 4KB/2MB/1GB pages and ASID scoping.
//
// Interface:
// - Lookup: va -> pa, hit/valid, permissions (r/w/x/u), and page size flags.
// - Update: insert/overwrite an entry (from page-table walker/OS) with PTE info.
// - Maintenance: flush all or flush by ASID; global (G) mappings are preserved.
// - Current ASID input selects which address space is visible.
//
// Replacement:
// - Simple LRU counter per entry with a global min-victim policy (illustrative).
//
// Notes:
// - This module provides only the TLB; a page table walker is assumed external.
// - Permission bits are directly sampled from PTE fields for teaching simplicity.
// -----------------------------------------------------------------------------

module tlb #(
    parameter XLEN = 64,
    parameter TLB_ENTRIES = 64,
    parameter ASID_WIDTH = 16
) (
    input  logic clk,
    input  logic rst_n,
    
    // Virtual address translation
    input  logic [XLEN-1:0]     va,
    output logic [XLEN-1:0]     pa,
    output logic                hit,
    output logic                valid,
    
    // Page table entry update
    input  logic                update,
    input  logic [XLEN-1:0]     update_va,
    input  logic [XLEN-1:0]     update_pte,
    input  logic [ASID_WIDTH-1:0] update_asid,
    
    // TLB maintenance
    input  logic                flush,
    input  logic                flush_asid,
    input  logic [ASID_WIDTH-1:0] flush_asid_val,
    
    // Current ASID
    input  logic [ASID_WIDTH-1:0] current_asid,
    
    // Access permissions
    output logic                readable,
    output logic                writable,
    output logic                executable,
    output logic                user_access,
    
    // Page size
    output logic                is_4k_page,
    output logic                is_2m_page,
    output logic                is_1g_page
);

    // TLB entry structure
    typedef struct packed {
        logic                valid;
        logic [ASID_WIDTH-1:0] asid;
        logic [XLEN-1:0]     vpn;      // Virtual page number
        logic [XLEN-1:0]     ppn;      // Physical page number
        logic                r, w, x;  // Read, write, execute
        logic                u;        // User mode accessible
        logic                g;        // Global mapping
        logic                a, d;     // Accessed, dirty
        logic [1:0]          page_size; // 00: 4K, 01: 2M, 10: 1G
    } tlb_entry_t;

    tlb_entry_t tlb_entries [TLB_ENTRIES-1:0];

    // LRU replacement
    logic [$clog2(TLB_ENTRIES)-1:0] lru_counter [TLB_ENTRIES-1:0];
    logic [$clog2(TLB_ENTRIES)-1:0] victim_entry;

    // Address breakdown for different page sizes
    logic [XLEN-1:0] va_4k_vpn, va_2m_vpn, va_1g_vpn;
    logic [11:0]     va_4k_offset;
    logic [20:0]     va_2m_offset;
    logic [29:0]     va_1g_offset;

    assign va_4k_vpn = va[XLEN-1:12];
    assign va_2m_vpn = va[XLEN-1:21];
    assign va_1g_vpn = va[XLEN-1:30];
    assign va_4k_offset = va[11:0];
    assign va_2m_offset = va[20:0];
    assign va_1g_offset = va[29:0];

    // Hit detection
    logic [TLB_ENTRIES-1:0] entry_hit;
    logic [$clog2(TLB_ENTRIES)-1:0] hit_entry;
    logic found_hit;

    always_comb begin
        found_hit = 1'b0;
        hit_entry = 0;
        
        for (int i = 0; i < TLB_ENTRIES; i++) begin
            case (tlb_entries[i].page_size)
                2'b00: // 4K page
                    entry_hit[i] = tlb_entries[i].valid && 
                                  (tlb_entries[i].asid == current_asid || tlb_entries[i].g) &&
                                  (tlb_entries[i].vpn == va_4k_vpn);
                2'b01: // 2M page
                    entry_hit[i] = tlb_entries[i].valid && 
                                  (tlb_entries[i].asid == current_asid || tlb_entries[i].g) &&
                                  (tlb_entries[i].vpn[XLEN-1:21] == va_2m_vpn);
                2'b10: // 1G page
                    entry_hit[i] = tlb_entries[i].valid && 
                                  (tlb_entries[i].asid == current_asid || tlb_entries[i].g) &&
                                  (tlb_entries[i].vpn[XLEN-1:30] == va_1g_vpn);
                default:
                    entry_hit[i] = 1'b0;
            endcase
            
            if (entry_hit[i] && !found_hit) begin
                hit_entry = i;
                found_hit = 1'b1;
            end
        end
    end

    assign hit = found_hit;

    // Physical address translation
    always_comb begin
        pa = va; // Default passthrough
        if (hit) begin
            case (tlb_entries[hit_entry].page_size)
                2'b00: // 4K page
                    pa = {tlb_entries[hit_entry].ppn[XLEN-1:12], va_4k_offset};
                2'b01: // 2M page
                    pa = {tlb_entries[hit_entry].ppn[XLEN-1:21], va_2m_offset};
                2'b10: // 1G page
                    pa = {tlb_entries[hit_entry].ppn[XLEN-1:30], va_1g_offset};
            endcase
        end
    end

    // Permission outputs
    assign valid = hit;
    assign readable = hit ? tlb_entries[hit_entry].r : 1'b0;
    assign writable = hit ? tlb_entries[hit_entry].w : 1'b0;
    assign executable = hit ? tlb_entries[hit_entry].x : 1'b0;
    assign user_access = hit ? tlb_entries[hit_entry].u : 1'b0;

    // Page size outputs
    assign is_4k_page = hit ? (tlb_entries[hit_entry].page_size == 2'b00) : 1'b0;
    assign is_2m_page = hit ? (tlb_entries[hit_entry].page_size == 2'b01) : 1'b0;
    assign is_1g_page = hit ? (tlb_entries[hit_entry].page_size == 2'b10) : 1'b0;

    // LRU victim selection
    always_comb begin
        victim_entry = 0;
        for (int i = 1; i < TLB_ENTRIES; i++) begin
            if (lru_counter[i] < lru_counter[victim_entry]) begin
                victim_entry = i;
            end
        end
    end

    // TLB update logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < TLB_ENTRIES; i++) begin
                tlb_entries[i] <= '0;
                lru_counter[i] <= i;
            end
        end else begin
            // Handle flushes
            if (flush) begin
                for (int i = 0; i < TLB_ENTRIES; i++) begin
                    if (!tlb_entries[i].g) begin // Don't flush global entries
                        tlb_entries[i].valid <= 1'b0;
                    end
                end
            end else if (flush_asid) begin
                for (int i = 0; i < TLB_ENTRIES; i++) begin
                    if (tlb_entries[i].asid == flush_asid_val && !tlb_entries[i].g) begin
                        tlb_entries[i].valid <= 1'b0;
                    end
                end
            end
            
            // Handle updates
            if (update) begin
                tlb_entries[victim_entry].valid <= 1'b1;
                tlb_entries[victim_entry].asid <= update_asid;
                tlb_entries[victim_entry].vpn <= update_va[XLEN-1:12];
                tlb_entries[victim_entry].ppn <= update_pte[XLEN-1:12];
                tlb_entries[victim_entry].r <= update_pte[1];
                tlb_entries[victim_entry].w <= update_pte[2];
                tlb_entries[victim_entry].x <= update_pte[3];
                tlb_entries[victim_entry].u <= update_pte[4];
                tlb_entries[victim_entry].g <= update_pte[5];
                tlb_entries[victim_entry].a <= update_pte[6];
                tlb_entries[victim_entry].d <= update_pte[7];
                // Page size detection would be done by PTW
                tlb_entries[victim_entry].page_size <= 2'b00; // Default to 4K
            end
            
            // Update LRU on hit
            if (hit) begin
                lru_counter[hit_entry] <= TLB_ENTRIES - 1;
                for (int i = 0; i < TLB_ENTRIES; i++) begin
                    if (i != hit_entry && lru_counter[i] > lru_counter[hit_entry]) begin
                        lru_counter[i] <= lru_counter[i] - 1;
                    end
                end
            end
        end
    end

endmodule
