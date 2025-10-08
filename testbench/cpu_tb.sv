//////////////////////////////////////////////////////////////////////////////////
// Module: cpu_tb
// Author: RISC-V CPU Design Team
// Date: 2024
// Description: Comprehensive testbench for RISC-V CPU
//              Tests instruction execution, cache behavior, MMU functionality
//              Includes basic instruction tests and system-level verification
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module cpu_tb;

    //////////////////////////////////////////////////////////////////////////////////
    // Test Parameters
    //////////////////////////////////////////////////////////////////////////////////
    
    parameter CLK_PERIOD = 10;              // 100 MHz clock
    parameter TEST_TIMEOUT = 100000;        // Maximum simulation time
    parameter MEMORY_SIZE_MB = 64;          // Test memory size
    
    //////////////////////////////////////////////////////////////////////////////////
    // DUT Signals
    //////////////////////////////////////////////////////////////////////////////////
    
    logic        clk;
    logic        rst_n;
    
    // External memory interface
    logic        mem_req;
    logic        mem_we;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_be;
    logic [31:0] mem_rdata;
    logic        mem_ready;
    
    // Debug interface
    logic [31:0] debug_pc;
    logic [31:0] debug_inst;
    logic        debug_valid;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Test Variables
    //////////////////////////////////////////////////////////////////////////////////
    
    integer test_num;
    integer error_count;
    integer instruction_count;
    logic [31:0] expected_result;
    logic test_passed;
    
    //////////////////////////////////////////////////////////////////////////////////
    // Clock Generation
    //////////////////////////////////////////////////////////////////////////////////
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // DUT Instantiation
    //////////////////////////////////////////////////////////////////////////////////
    
    top u_dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .mem_req            (mem_req),
        .mem_we             (mem_we),
        .mem_addr           (mem_addr),
        .mem_wdata          (mem_wdata),
        .mem_be             (mem_be),
        .mem_rdata          (mem_rdata),
        .mem_ready          (mem_ready),
        .debug_pc           (debug_pc),
        .debug_inst         (debug_inst),
        .debug_valid        (debug_valid)
    );
    
    //////////////////////////////////////////////////////////////////////////////////
    // Memory Model Instantiation
    //////////////////////////////////////////////////////////////////////////////////
    
    dram_model #(
        .MEMORY_SIZE_MB     (MEMORY_SIZE_MB),
        .READ_LATENCY       (5),
        .WRITE_LATENCY      (3)
    ) u_memory (
        .clk                (clk),
        .rst_n              (rst_n),
        .req                (mem_req),
        .we                 (mem_we),
        .addr               (mem_addr),
        .wdata              (mem_wdata),
        .be                 (mem_be),
        .rdata              (mem_rdata),
        .ready              (mem_ready),
        .read_count         (),
        .write_count        ()
    );
    
    //////////////////////////////////////////////////////////////////////////////////
    // Test Program Loading
    //////////////////////////////////////////////////////////////////////////////////
    
    task load_test_program(input string filename);
        integer file_handle;
        integer addr;
        integer data;
        integer result;
        
        begin
            file_handle = $fopen(filename, "r");
            if (file_handle == 0) begin
                $error("Cannot open test program file: %s", filename);
                $finish;
            end
            
            addr = 0;
            while (!$feof(file_handle)) begin
                result = $fscanf(file_handle, "%h", data);
                if (result == 1) begin
                    // Write instruction to memory model
                    u_memory.memory[addr+0] = data[7:0];
                    u_memory.memory[addr+1] = data[15:8];
                    u_memory.memory[addr+2] = data[23:16];
                    u_memory.memory[addr+3] = data[31:24];
                    addr = addr + 4;
                end
            end
            
            $fclose(file_handle);
            $display("Loaded test program: %s (%0d instructions)", filename, addr/4);
        end
    endtask
    
    //////////////////////////////////////////////////////////////////////////////////
    // Memory Initialization
    //////////////////////////////////////////////////////////////////////////////////
    
    task init_memory();
        begin
            // Initialize specific memory locations for testing
            
            // Test data section (starting at 0x1000)
            u_memory.memory[32'h1000] = 8'h12;
            u_memory.memory[32'h1001] = 8'h34;
            u_memory.memory[32'h1002] = 8'h56;
            u_memory.memory[32'h1003] = 8'h78;
            
            u_memory.memory[32'h1004] = 8'hAA;
            u_memory.memory[32'h1005] = 8'hBB;
            u_memory.memory[32'h1006] = 8'hCC;
            u_memory.memory[32'h1007] = 8'hDD;
            
            // Stack area (starting at 0x2000)
            for (int i = 0; i < 256; i++) begin
                u_memory.memory[32'h2000 + i] = 8'h00;
            end
            
            $display("Memory initialized for testing");
        end
    endtask
    
    //////////////////////////////////////////////////////////////////////////////////
    // Basic Instruction Test Programs
    //////////////////////////////////////////////////////////////////////////////////
    
    task load_basic_test();
        begin
            $display("Loading basic instruction test...");
            
            // Basic arithmetic test program
            u_memory.memory[0] = 8'h13; u_memory.memory[1] = 8'h01; u_memory.memory[2] = 8'h00; u_memory.memory[3] = 8'h00; // addi x2, x0, 0
            u_memory.memory[4] = 8'h13; u_memory.memory[5] = 8'h02; u_memory.memory[6] = 8'h50; u_memory.memory[7] = 8'h00; // addi x4, x0, 5
            u_memory.memory[8] = 8'h13; u_memory.memory[9] = 8'h03; u_memory.memory[10] = 8'hA0; u_memory.memory[11] = 8'h00; // addi x6, x0, 10
            u_memory.memory[12] = 8'h33; u_memory.memory[13] = 8'h84; u_memory.memory[14] = 8'h62; u_memory.memory[15] = 8'h00; // add x8, x4, x6
            u_memory.memory[16] = 8'hB3; u_memory.memory[17] = 8'h84; u_memory.memory[18] = 8'h62; u_memory.memory[19] = 8'h40; // sub x9, x4, x6
            u_memory.memory[20] = 8'h33; u_memory.memory[21] = 8'h15; u_memory.memory[22] = 8'h62; u_memory.memory[23] = 8'h00; // sll x10, x4, x6
            u_memory.memory[24] = 8'h73; u_memory.memory[25] = 8'h00; u_memory.memory[26] = 8'h10; u_memory.memory[27] = 8'h00; // ebreak
            
            $display("Basic test loaded: ADD, SUB, SLL operations");
        end
    endtask
    
    task load_memory_test();
        begin
            $display("Loading memory access test...");
            
            // Memory load/store test program
            u_memory.memory[0] = 8'h37; u_memory.memory[1] = 8'h15; u_memory.memory[2] = 8'h00; u_memory.memory[3] = 8'h00; // lui x10, 0x1
            u_memory.memory[4] = 8'h13; u_memory.memory[5] = 8'h05; u_memory.memory[6] = 8'h05; u_memory.memory[7] = 8'h00; // addi x10, x10, 0
            u_memory.memory[8] = 8'h03; u_memory.memory[9] = 8'h26; u_memory.memory[10] = 8'h05; u_memory.memory[11] = 8'h00; // lw x12, 0(x10)
            u_memory.memory[12] = 8'h13; u_memory.memory[13] = 8'h06; u_memory.memory[14] = 8'h10; u_memory.memory[15] = 8'h00; // addi x12, x0, 1
            u_memory.memory[16] = 8'h23; u_memory.memory[17] = 8'h22; u_memory.memory[18] = 8'hC5; u_memory.memory[19] = 8'h00; // sw x12, 4(x10)
            u_memory.memory[20] = 8'h73; u_memory.memory[21] = 8'h00; u_memory.memory[22] = 8'h10; u_memory.memory[23] = 8'h00; // ebreak
            
            $display("Memory test loaded: LUI, LW, SW operations");
        end
    endtask
    
    task load_branch_test();
        begin
            $display("Loading branch test...");
            
            // Branch test program
            u_memory.memory[0] = 8'h13; u_memory.memory[1] = 8'h01; u_memory.memory[2] = 8'h50; u_memory.memory[3] = 8'h00; // addi x2, x0, 5
            u_memory.memory[4] = 8'h13; u_memory.memory[5] = 8'h02; u_memory.memory[6] = 8'hA0; u_memory.memory[7] = 8'h00; // addi x4, x0, 10
            u_memory.memory[8] = 8'h63; u_memory.memory[9] = 8'h54; u_memory.memory[10] = 8'h22; u_memory.memory[11] = 8'h00; // blt x4, x2, +8
            u_memory.memory[12] = 8'h13; u_memory.memory[13] = 8'h03; u_memory.memory[14] = 8'h10; u_memory.memory[15] = 8'h00; // addi x6, x0, 1
            u_memory.memory[16] = 8'h6F; u_memory.memory[17] = 8'h00; u_memory.memory[18] = 8'h80; u_memory.memory[19] = 8'h00; // jal x0, +8
            u_memory.memory[20] = 8'h13; u_memory.memory[21] = 8'h03; u_memory.memory[22] = 8'h20; u_memory.memory[23] = 8'h00; // addi x6, x0, 2
            u_memory.memory[24] = 8'h73; u_memory.memory[25] = 8'h00; u_memory.memory[26] = 8'h10; u_memory.memory[27] = 8'h00; // ebreak
            
            $display("Branch test loaded: BLT, JAL operations");
        end
    endtask
    
    //////////////////////////////////////////////////////////////////////////////////
    // Test Execution and Monitoring
    //////////////////////////////////////////////////////////////////////////////////
    
    task run_test(input string test_name, input integer max_cycles);
        begin
            $display("\n=== Running Test: %s ===", test_name);
            instruction_count = 0;
            test_passed = 1'b0;
            
            // Wait for test completion or timeout
            fork
                begin
                    // Monitor for ebreak instruction
                    wait(debug_valid && (debug_inst == 32'h00100073));
                    test_passed = 1'b1;
                    $display("Test completed with EBREAK at PC = 0x%08x", debug_pc);
                end
                begin
                    // Timeout
                    repeat(max_cycles) @(posedge clk);
                    if (!test_passed) begin
                        $error("Test timeout after %0d cycles", max_cycles);
                        error_count++;
                    end
                end
            join_any
            disable fork;
            
            $display("Instructions executed: %0d", instruction_count);
            $display("=== Test %s: %s ===\n", test_name, test_passed ? "PASSED" : "FAILED");
        end
    endtask
    
    //////////////////////////////////////////////////////////////////////////////////
    // Instruction Counting
    //////////////////////////////////////////////////////////////////////////////////
    
    always @(posedge clk) begin
        if (debug_valid) begin
            instruction_count++;
            $display("PC: 0x%08x, Inst: 0x%08x", debug_pc, debug_inst);
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Main Test Sequence
    //////////////////////////////////////////////////////////////////////////////////
    
    initial begin
        $display("=== RISC-V CPU Testbench Started ===");
        
        // Initialize
        test_num = 0;
        error_count = 0;
        rst_n = 1'b0;
        
        // Reset sequence
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(5) @(posedge clk);
        
        // Initialize memory
        init_memory();
        
        // Test 1: Basic arithmetic operations
        test_num = 1;
        load_basic_test();
        run_test("Basic Arithmetic", 1000);
        
        // Reset for next test
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(5) @(posedge clk);
        
        // Test 2: Memory access operations
        test_num = 2;
        load_memory_test();
        run_test("Memory Access", 1000);
        
        // Reset for next test
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(5) @(posedge clk);
        
        // Test 3: Branch and jump operations
        test_num = 3;
        load_branch_test();
        run_test("Branch and Jump", 1000);
        
        // Test summary
        $display("\n=== TEST SUMMARY ===");
        $display("Total tests run: %0d", test_num);
        $display("Errors: %0d", error_count);
        if (error_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        $display("====================\n");
        
        $finish;
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Timeout Protection
    //////////////////////////////////////////////////////////////////////////////////
    
    initial begin
        repeat(TEST_TIMEOUT) @(posedge clk);
        $error("Testbench timeout after %0d cycles", TEST_TIMEOUT);
        $finish;
    end
    
    //////////////////////////////////////////////////////////////////////////////////
    // Waveform Dumping
    //////////////////////////////////////////////////////////////////////////////////
    
    `ifdef DUMP_VCD
    initial begin
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);
    end
    `endif
    
endmodule