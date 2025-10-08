//////////////////////////////////////////////////////////////////////////////////
// Module: dram_model
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Simple DRAM model for simulation and testing
//              Models basic DRAM timing characteristics and behavior
//              Implements parameterizable memory size and timing delays
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module dram_model #(
    parameter MEMORY_SIZE_MB = 256,         // Memory size in MB
    parameter ADDR_WIDTH = 32,              // Address width
    parameter DATA_WIDTH = 32,              // Data width
    parameter READ_LATENCY = 10,            // Read latency in cycles
    parameter WRITE_LATENCY = 5,            // Write latency in cycles
    parameter BURST_LENGTH = 1              // Burst length (words per access)
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // Memory interface
    input  logic        req,                // Memory request
    input  logic        we,                 // Write enable
    input  logic [ADDR_WIDTH-1:0] addr,     // Memory address
    input  logic [DATA_WIDTH-1:0] wdata,    // Write data
    input  logic [DATA_WIDTH/8-1:0] be,     // Byte enable
    output logic [DATA_WIDTH-1:0] rdata,    // Read data
    output logic        ready,              // Ready signal
    
    // Statistics and debug
    output logic [31:0] read_count,         // Number of reads performed
    output logic [31:0] write_count         // Number of writes performed
);

    //////////////////////////////////////////////////////////////////////////////////
    // Memory Parameters
    //////////////////////////////////////////////////////////////////////////////////
    
    localparam MEMORY_SIZE_BYTES = MEMORY_SIZE_MB * 1024 * 1024;
    localparam MEMORY_DEPTH = MEMORY_SIZE_BYTES / (DATA_WIDTH / 8);
    localparam ADDR_LSB = $clog2(DATA_WIDTH / 8);
    
    //////////////////////////////////////////////////////////////////////////////////
    // Memory Storage
    //////////////////////////////////////////////////////////////////////////////////
    
    // Memory array - using byte-addressable storage
    logic [7:0] memory [MEMORY_SIZE_BYTES];
    
    //////////////////////////////////////////////////////////////////////////////////
    // Timing Control
    //////////////////////////////////////////////////////////////////////////////////
    
    typedef enum logic [1:0] {
        IDLE,
        READ_WAIT,
        WRITE_WAIT,
        DONE
    } mem_state_t;
    
    mem_state_t state, next_state;
    logic [$clog2(READ_LATENCY):0] read_counter;
    logic [$clog2(WRITE_LATENCY):0] write_counter;
    logic [ADDR_WIDTH-1:0] stored_addr;
    logic [DATA_WIDTH-1:0] stored_wdata;
    logic [DATA_WIDTH/8-1:0] stored_be;
    logic stored_we;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Address Decoding
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [ADDR_WIDTH-ADDR_LSB-1:0] word_addr;
    logic [ADDR_WIDTH-1:0] byte_addr;
    logic addr_valid;
    
    assign word_addr = addr[ADDR_WIDTH-1:ADDR_LSB];
    assign byte_addr = {addr[ADDR_WIDTH-1:ADDR_LSB], {ADDR_LSB{1'b0}}};
    assign addr_valid = (byte_addr < MEMORY_SIZE_BYTES);
    
    //////////////////////////////////////////////////////////////////////////////////
    // State Machine
    //////////////////////////////////////////////////////////////////////////////////
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            read_counter <= '0;
            write_counter <= '0;
            stored_addr <= '0;
            stored_wdata <= '0;
            stored_be <= '0;
            stored_we <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (req && addr_valid) begin
                        stored_addr <= addr;
                        stored_wdata <= wdata;
                        stored_be <= be;
                        stored_we <= we;
                        
                        if (we) begin
                            write_counter <= WRITE_LATENCY;
                        end else begin
                            read_counter <= READ_LATENCY;
                        end
                    end
                end
                
                READ_WAIT: begin
                    if (read_counter > 0) begin
                        read_counter <= read_counter - 1;
                    end
                end
                
                WRITE_WAIT: begin
                    if (write_counter > 0) begin
                        write_counter <= write_counter - 1;
                    end
                end
                
                DONE: begin
                    // Stay in DONE for one cycle
                end
            endcase
        end
    end
    
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (req && addr_valid) begin
                    if (we) begin
                        next_state = WRITE_WAIT;
                    end else begin
                        next_state = READ_WAIT;
                    end
                end
            end
            
            READ_WAIT: begin
                if (read_counter == 0) begin
                    next_state = DONE;
                end
            end
            
            WRITE_WAIT: begin
                if (write_counter == 0) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Memory Access Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    logic [DATA_WIDTH-1:0] read_data;
    
    // Read logic
    always_comb begin
        read_data = '0;
        
        if (addr_valid) begin
            // Read word from byte-addressable memory
            for (int i = 0; i < (DATA_WIDTH / 8); i = i + 1) begin
                read_data[i*8 +: 8] = memory[byte_addr + i];
            end
        end
    end
    
    // Write logic
    always_ff @(posedge clk) begin
        if (state == WRITE_WAIT && write_counter == 0) begin
            if (addr_valid) begin
                // Write word to byte-addressable memory with byte enables
                for (int i = 0; i < (DATA_WIDTH / 8); i = i + 1) begin
                    if (stored_be[i]) begin
                        memory[{stored_addr[ADDR_WIDTH-1:ADDR_LSB], {ADDR_LSB{1'b0}}} + i] <= stored_wdata[i*8 +: 8];
                    end
                end
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Output Logic
    //////////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        ready = (state == DONE);
        rdata = read_data;
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Statistics Counters
    //////////////////////////////////////////////////////////////////////////////////
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_count <= 32'h0;
            write_count <= 32'h0;
        end else begin
            if (state == DONE) begin
                if (stored_we) begin
                    write_count <= write_count + 1;
                end else begin
                    read_count <= read_count + 1;
                end
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Memory Initialization (for simulation)
    //////////////////////////////////////////////////////////////////////////////////
    
    `ifdef SIMULATION
    integer init_i;
    initial begin
        // Initialize memory to zero
        for (init_i = 0; init_i < MEMORY_SIZE_BYTES; init_i = init_i + 1) begin
            memory[init_i] = 8'h0;
        end
        
        $display("DRAM Model initialized: %0d MB (%0d bytes)", MEMORY_SIZE_MB, MEMORY_SIZE_BYTES);
    end
    
    // Debug output
    always @(posedge clk) begin
        if (req && addr_valid && state == IDLE) begin
            if (we) begin
                $display("Time %t: DRAM WRITE - Addr: 0x%08x, Data: 0x%08x, BE: 0x%x", 
                        $time, addr, wdata, be);
            end else begin
                $display("Time %t: DRAM READ  - Addr: 0x%08x", $time, addr);
            end
        end
        
        if (ready && !stored_we) begin
            $display("Time %t: DRAM READ  - Data: 0x%08x", $time, rdata);
        end
    end
    `endif
    
    //////////////////////////////////////////////////////////////////////////////////
    // Error Checking
    //////////////////////////////////////////////////////////////////////////////////
    
    always @(posedge clk) begin
        if (req && !addr_valid) begin
            $error("Time %t: DRAM access to invalid address 0x%08x (max: 0x%08x)", 
                   $time, addr, MEMORY_SIZE_BYTES-1);
        end
    end
    
endmodule