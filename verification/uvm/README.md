# UVM Verification Environment for RISC-V CPU

## Overview

This verification environment provides comprehensive UVM-based testing for the RISC-V CPU modules, focusing on:
- L1 Data Cache verification
- Memory Management Unit (MMU) verification  
- Translation Lookaside Buffer (TLB) verification

## Directory Structure

```
verification/uvm/
├── README.md              # This file
├── Makefile              # Main makefile for running tests
├── packages/             # UVM packages
│   ├── cache_pkg.sv      # Cache verification package
│   └── mmu_pkg.sv        # MMU verification package
├── interfaces/           # SystemVerilog interfaces
│   ├── cache_if.sv       # Cache interface
│   └── mmu_if.sv         # MMU interface
├── models/               # Behavioral models
│   ├── l2_cache_model.sv # L2 cache behavioral model
│   └── memory_model.sv   # Memory model for page table walks
├── testbench/            # Top-level testbenches
│   ├── cache_tb.sv       # Cache testbench
│   └── mmu_tb.sv         # MMU testbench
├── env/                  # UVM environments
│   ├── cache_config.sv   # Cache configuration
│   ├── cache_env.sv      # Cache environment
│   ├── cache_scoreboard.sv # Cache scoreboard
│   ├── mmu_config.sv     # MMU configuration
│   ├── mmu_env.sv        # MMU environment
│   └── mmu_scoreboard.sv # MMU scoreboard
├── agents/               # UVM agents
│   ├── cache_agent.sv    # Cache agent
│   ├── cache_driver.sv   # Cache driver
│   ├── cache_monitor.sv  # Cache monitor
│   ├── cache_sequencer.sv # Cache sequencer
│   ├── mmu_agent.sv      # MMU agent
│   ├── mmu_driver.sv     # MMU driver
│   ├── mmu_monitor.sv    # MMU monitor
│   └── mmu_sequencer.sv  # MMU sequencer
├── sequences/            # UVM sequences and transactions
│   ├── cache_transaction.sv # Cache transaction
│   ├── cache_sequences.sv   # Cache sequences
│   ├── mmu_transaction.sv   # MMU transaction
│   └── mmu_sequences.sv     # MMU sequences
└── tests/                # UVM tests
    ├── cache_test.sv     # Cache tests
    └── mmu_test.sv       # MMU tests
```

## Prerequisites

### Required Tools
- **Simulator**: Questa/ModelSim, VCS, or Xcelium
- **UVM Library**: UVM 1.2 or later
- **SystemVerilog**: IEEE 1800-2017 compliant

### Environment Setup

1. **Set UVM_HOME environment variable:**
   ```bash
   export UVM_HOME=/path/to/uvm/library
   ```

2. **Ensure simulator is in PATH:**
   ```bash
   export PATH=$PATH:/path/to/simulator/bin
   ```

3. **Clone or access the repository:**
   ```bash
   cd /Users/michaelli/Documents/GitHub/riscv-cpu-1/verification/uvm
   ```

## Running Tests

### Quick Start

To run all tests:
```bash
make all
```

To see available options:
```bash
make help
```

### Cache Tests

Run individual cache tests:
```bash
make cache_random    # Random cache operations
make cache_seq       # Sequential cache access
make cache_wr        # Write-read coherency test
make cache_stress    # Cache stress test
```

Run all cache tests:
```bash
make cache_tests
```

### MMU Tests

Run individual MMU tests:
```bash
make mmu_basic       # Basic MMU translation
make mmu_fault       # Page fault testing
make mmu_stress      # MMU stress test
```

Run all MMU tests:
```bash
make mmu_tests
```

### TLB Tests

Run TLB-specific tests:
```bash
make tlb_tests
```

### Test Options

**Select Simulator:**
```bash
make all SIM=questa     # Use Questa/ModelSim (default)
make all SIM=vcs        # Use VCS
make all SIM=xcelium    # Use Xcelium
```

**Enable Waveforms:**
```bash
make cache_random WAVES=1
```

**Verbose Output:**
```bash
make mmu_basic VERBOSE=1
```

### Debug Mode

Run tests with GUI (Questa):
```bash
make debug_cache     # Cache tests with GUI
make debug_mmu       # MMU tests with GUI
```

## Test Descriptions

### Cache Tests

#### cache_random_test
- **Purpose**: Validates cache functionality with random read/write operations
- **Features**: 
  - Random addresses and data patterns
  - All byte enable combinations
  - Mixed read/write operations
- **Duration**: ~200 transactions

#### cache_sequential_test
- **Purpose**: Tests cache behavior with sequential memory access patterns
- **Features**: 
  - Sequential address access
  - Cache line filling validation
  - Spatial locality testing
- **Duration**: ~128 transactions

#### cache_write_read_test
- **Purpose**: Validates write-read coherency and data integrity
- **Features**: 
  - Write followed by read verification
  - Data coherency checks
  - Write-back policy validation
- **Duration**: ~64 write-read pairs

#### cache_stress_test
- **Purpose**: Stress tests cache with intensive operations
- **Features**: 
  - High transaction volume
  - Large address range
  - Performance validation
- **Duration**: ~1000 transactions

### MMU Tests

#### mmu_basic_test
- **Purpose**: Basic MMU translation functionality
- **Features**: 
  - Virtual to physical address translation
  - TLB hit/miss scenarios
  - Page table walk validation
- **Duration**: ~100 translations

#### mmu_fault_test
- **Purpose**: Page fault and exception handling
- **Features**: 
  - Invalid page access
  - Permission violations
  - Fault recovery mechanisms
- **Duration**: ~50 fault scenarios

#### mmu_stress_test
- **Purpose**: MMU performance and robustness testing
- **Features**: 
  - High-frequency translations
  - TLB thrashing scenarios
  - Multi-level page table walks
- **Duration**: ~500 translations

## Understanding Test Results

### Log Files
Test logs are stored in the `logs/` directory:
- `logs/cache_random_test.log`
- `logs/mmu_basic_test.log`
- etc.

### Waveform Files
When WAVES=1 is used:
- `cache_test.vcd` for cache tests
- `mmu_test.vcd` for MMU tests

### Coverage Reports
Coverage data is collected automatically and reported at test completion.

## Test Status Interpretation

### Successful Test Output
```
UVM_INFO: Test completed successfully
UVM_INFO: Cache hits: 156 (78.0%)
UVM_INFO: Cache misses: 44 (22.0%)
UVM_INFO: Total transactions: 200
```

### Failed Test Output
```
UVM_ERROR: Cache hit returned unknown data
UVM_FATAL: Virtual interface not found
```

## Debugging Failed Tests

1. **Check Log Files**: Look in `logs/` directory for detailed error messages
2. **Enable Waveforms**: Run with `WAVES=1` to generate VCD files
3. **Increase Verbosity**: Use `VERBOSE=1` for detailed transaction logs
4. **Run in GUI Mode**: Use `make debug_cache` or `make debug_mmu`

## Common Issues and Solutions

### Compilation Errors

**Issue**: UVM library not found
```
Solution: Set UVM_HOME environment variable correctly
export UVM_HOME=/path/to/uvm
```

**Issue**: RTL files not found
```
Solution: Ensure RTL files exist in ../../rtl/ directory
Check: ls ../../rtl/cache/l1_dcache.sv
```

### Runtime Errors

**Issue**: Virtual interface not found
```
Solution: Check that interfaces are properly connected in testbench
Verify: uvm_config_db settings in testbench
```

**Issue**: Test timeout
```
Solution: Increase timeout or check for infinite loops
Check: DUT reset and clock generation
```

## Customizing Tests

### Adding New Test Cases

1. Create new test class in `tests/` directory
2. Add test to appropriate package file
3. Update Makefile with new test target
4. Example:
   ```systemverilog
   class my_cache_test extends cache_base_test;
       `uvm_component_utils(my_cache_test)
       // Implementation
   endclass
   ```

### Modifying Test Parameters

Edit configuration objects in test files:
```systemverilog
// In cache test
seq.num_transactions = 500;  // Increase transaction count
seq.addr_range_end = 32'h200000;  // Increase address range
```

### Creating Custom Sequences

1. Extend base sequence class
2. Implement `body()` task
3. Register sequence in package
4. Use in test files

## Regression Testing

Run comprehensive regression:
```bash
make regression
```

This runs all tests and generates a summary report.

## Performance Analysis

### Cache Performance Metrics
- Hit Rate: Percentage of cache hits
- Miss Rate: Percentage of cache misses  
- Average Access Time: Including miss penalty

### MMU Performance Metrics
- TLB Hit Rate: Percentage of TLB hits
- Page Table Walk Frequency
- Translation Latency

## Troubleshooting

### Environment Issues
1. Verify UVM_HOME is set correctly
2. Check simulator licensing
3. Ensure adequate disk space for waveforms

### Test Failures
1. Review UVM error messages carefully
2. Check DUT connectivity in testbench
3. Verify clock and reset generation
4. Examine transaction randomization constraints

## Support and Contributions

For issues or improvements:
1. Check existing documentation
2. Review test logs for error details
3. Create detailed bug reports with:
   - Test command used
   - Complete error messages
   - Environment details

## Advanced Usage

### Custom Simulator Settings

Modify Makefile for simulator-specific options:
```makefile
# Add custom VCS flags
VCS_FLAGS += +vcs+vcdpluson
```

### Coverage-Driven Verification

Enable coverage collection:
```bash
make coverage
```

### Constrained Random Testing

Modify transaction constraints:
```systemverilog
constraint c_addr_range {
    address inside {[32'h1000:32'h2000]};
}
```