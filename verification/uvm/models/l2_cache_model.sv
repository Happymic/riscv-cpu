//////////////////////////////////////////////////////////////////////////////////
// Module: l2_cache_model
// Description: Simple L2 cache model for testing L1 cache
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module l2_cache_model #(
    parameter RESPONSE_DELAY = 5    // Cycles to simulate L2 access delay
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // L1 cache interface
    input  logic        l2_req,
    input  logic        l2_we,
    input  logic [31:0] l2_addr,
    input  logic [127:0] l2_wdata,
    output logic [127:0] l2_rdata,
    output logic        l2_valid
);

    // Simple memory model
    logic [127:0] memory [logic [31:0]];
    
    // Response generation
    logic [7:0] delay_counter;
    logic pending_req;
    logic [31:0] pending_addr;
    logic pending_we;
    logic [127:0] pending_wdata;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_counter <= 8'h0;
            pending_req <= 1'b0;
            pending_addr <= 32'h0;
            pending_we <= 1'b0;
            pending_wdata <= 128'h0;
            l2_valid <= 1'b0;
            l2_rdata <= 128'h0;
        end else begin
            l2_valid <= 1'b0;
            
            if (l2_req && !pending_req) begin
                // Start new request
                pending_req <= 1'b1;
                pending_addr <= l2_addr;
                pending_we <= l2_we;
                pending_wdata <= l2_wdata;
                delay_counter <= RESPONSE_DELAY;
            end else if (pending_req) begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    // Complete request
                    pending_req <= 1'b0;
                    l2_valid <= 1'b1;
                    
                    if (pending_we) begin
                        // Write operation
                        memory[{pending_addr[31:4], 4'h0}] <= pending_wdata;
                        l2_rdata <= 128'h0;
                    end else begin
                        // Read operation
                        if (memory.exists({pending_addr[31:4], 4'h0})) begin
                            l2_rdata <= memory[{pending_addr[31:4], 4'h0}];
                        end else begin
                            // Generate pseudo-random data for uninitialized memory
                            l2_rdata <= {4{pending_addr}} ^ {4{$random()}};
                            memory[{pending_addr[31:4], 4'h0}] <= l2_rdata;
                        end
                    end
                end
            end
        end
    end
    
    // Debug output
    `ifdef SIMULATION
    always @(posedge clk) begin
        if (l2_req && !pending_req) begin
            $display("Time %t: L2 Model - %s request for addr 0x%08x", 
                    $time, l2_we ? "WRITE" : "READ", l2_addr);
        end
        if (l2_valid) begin
            $display("Time %t: L2 Model - Response valid, data=0x%032x", 
                    $time, l2_rdata);
        end
    end
    `endif
    
endmodule