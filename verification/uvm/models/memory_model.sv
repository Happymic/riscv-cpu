//////////////////////////////////////////////////////////////////////////////////
// Module: memory_model
// Description: Simple memory model for MMU page table walks
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module memory_model #(
    parameter RESPONSE_DELAY = 2    // Cycles to simulate memory access delay
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // Page table walk interface
    input  logic        ptw_req,
    input  logic [31:0] ptw_addr,
    output logic [31:0] ptw_rdata,
    output logic        ptw_ready
);

    // Memory storage
    logic [31:0] memory [logic [31:0]];
    
    // Response generation
    logic [7:0] delay_counter;
    logic pending_req;
    logic [31:0] pending_addr;
    
    // Initialize some page table entries for testing
    initial begin
        // Level 1 page table at physical address 0x1000
        memory[32'h1000] = 32'h00002001;  // Points to level 0 table at 0x2000, valid
        memory[32'h1004] = 32'h00003001;  // Points to level 0 table at 0x3000, valid
        
        // Level 0 page table at physical address 0x2000
        memory[32'h2000] = 32'h0000400F;  // Maps to physical page 0x4000, valid, R,W,X,U
        memory[32'h2004] = 32'h0000500F;  // Maps to physical page 0x5000, valid, R,W,X,U
        
        // Level 0 page table at physical address 0x3000
        memory[32'h3000] = 32'h0000600F;  // Maps to physical page 0x6000, valid, R,W,X,U
        memory[32'h3004] = 32'h0000700F;  // Maps to physical page 0x7000, valid, R,W,X,U
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_counter <= 8'h0;
            pending_req <= 1'b0;
            pending_addr <= 32'h0;
            ptw_ready <= 1'b0;
            ptw_rdata <= 32'h0;
        end else begin
            ptw_ready <= 1'b0;
            
            if (ptw_req && !pending_req) begin
                // Start new request
                pending_req <= 1'b1;
                pending_addr <= ptw_addr;
                delay_counter <= RESPONSE_DELAY;
            end else if (pending_req) begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    // Complete request
                    pending_req <= 1'b0;
                    ptw_ready <= 1'b1;
                    
                    if (memory.exists(pending_addr)) begin
                        ptw_rdata <= memory[pending_addr];
                    end else begin
                        // Return invalid PTE for unmapped addresses
                        ptw_rdata <= 32'h00000000;
                    end
                end
            end
        end
    end
    
    // Debug output
    `ifdef SIMULATION
    always @(posedge clk) begin
        if (ptw_req && !pending_req) begin
            $display("Time %t: Memory Model - PTW request for addr 0x%08x", 
                    $time, ptw_addr);
        end
        if (ptw_ready) begin
            $display("Time %t: Memory Model - PTW response data=0x%08x", 
                    $time, ptw_rdata);
        end
    end
    `endif
    
endmodule