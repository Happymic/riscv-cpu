# RISC-V CPU Testing Guide

## Repository Overview

This repository has been cleaned and organized with a comprehensive UVM verification environment for testing RISC-V CPU modules.

## What Was Cleaned

### Removed Files
- **Legacy RTL files**: Removed outdated cache controller, tag arrays, and core pipeline files
- **Old testbenches**: Removed basic testbenches that lacked proper verification methodology
- **Documentation**: Removed outdated docs that no longer matched the architecture

### Reorganized Structure
- **RTL consolidation**: Moved to streamlined CPU, cache, and MMU organization
- **New verification**: Created professional UVM-based verification environment
- **Better organization**: Clear separation of concerns between modules

## Current Repository Structure

```
riscv-cpu-1/
├── rtl/                    # RTL source files
│   ├── cache/              # Cache modules (L1, L2, L3)
│   ├── cpu/                # CPU core modules
│   ├── memory/             # Memory models
│   ├── mmu/                # Memory management unit
│   └── top.sv              # Top-level module
├── verification/           # Verification environment
│   ├── uvm/                # UVM testbenches (NEW)
│   └── unit_tests/         # Simple unit tests
├── testbench/              # Legacy testbenches
└── scripts/                # Build and simulation scripts
```

## UVM Verification Environment

The new UVM environment provides professional-grade verification for:

### Cache Verification
- **L1 D-Cache**: 2-way set associative with MESI protocol
- **Test Coverage**: Hit/miss scenarios, coherency, write-back policy
- **Performance**: Cache efficiency and timing validation

### MMU Verification  
- **Virtual Memory**: Sv32 translation with 2-level page tables
- **TLB Testing**: 16-entry fully associative with LRU replacement
- **Fault Testing**: Page faults, access violations, permission checks

## How to Run Tests

### Prerequisites

1. **Install Simulator** (one of):
   - Questa/ModelSim
   - Synopsys VCS  
   - Cadence Xcelium

2. **Set Environment**:
   ```bash
   export UVM_HOME=/path/to/uvm/library
   export PATH=$PATH:/path/to/simulator/bin
   ```

3. **Navigate to UVM Directory**:
   ```bash
   cd verification/uvm
   ```

### Quick Start Commands

**View available tests:**
```bash
make help
```

**Run all tests:**
```bash
make all
```

**Run specific test categories:**
```bash
make cache_tests    # All cache tests
make mmu_tests      # All MMU tests
make tlb_tests      # TLB-specific tests
```

### Individual Test Execution

**Cache Tests:**
```bash
make cache_random   # Random cache operations (200 transactions)
make cache_seq      # Sequential access patterns (128 transactions)  
make cache_wr       # Write-read coherency (64 pairs)
make cache_stress   # Stress testing (1000 transactions)
```

**MMU Tests:**
```bash
make mmu_basic      # Basic translation (100 operations)
make mmu_fault      # Page fault testing (50 scenarios)
make mmu_stress     # Performance testing (500 translations)
```

### Test Options

**Choose Simulator:**
```bash
make all SIM=questa    # Questa/ModelSim (default)
make all SIM=vcs       # Synopsys VCS
make all SIM=xcelium   # Cadence Xcelium
```

**Enable Debug Features:**
```bash
make cache_random WAVES=1 VERBOSE=1   # Waveforms + verbose logs
make debug_cache                      # GUI debugging mode
```

## Understanding Test Results

### Success Indicators
```
UVM_INFO: Test completed successfully
UVM_INFO: Cache hits: 156 (78.0%)
UVM_INFO: Cache misses: 44 (22.0%)
UVM_INFO: Total transactions: 200
```

### Performance Metrics

**Cache Performance:**
- **Hit Rate**: Should be >70% for sequential tests
- **Miss Penalty**: Should complete within timeout
- **Coherency**: No data corruption errors

**MMU Performance:**
- **TLB Hit Rate**: Should be >80% for locality tests
- **Translation Time**: Should complete within expected cycles
- **Fault Handling**: Proper exception generation

### Log Files
Results are saved in `verification/uvm/logs/`:
- `cache_random_test.log`
- `mmu_basic_test.log`
- etc.

## Test Coverage Areas

### Cache Module Testing

1. **Basic Functionality**
   - Read/write operations
   - Hit/miss detection
   - Cache line allocation

2. **Coherency Protocol**
   - MESI state transitions
   - Write-back policy
   - Dirty bit management

3. **Performance**
   - Sequential access patterns
   - Random access patterns
   - Cache thrashing scenarios

4. **Edge Cases**
   - Cache flush operations
   - Concurrent accesses
   - Error injection

### MMU Module Testing

1. **Address Translation**
   - Virtual to physical mapping
   - Multi-level page table walks
   - TLB hit/miss scenarios

2. **Permission Checking**
   - User vs supervisor mode
   - Read/write/execute permissions
   - Access fault generation

3. **Exception Handling**
   - Page fault exceptions
   - Invalid translations
   - Permission violations

4. **TLB Management**
   - Entry allocation/eviction
   - LRU replacement policy
   - TLB invalidation

## Debugging Failed Tests

### Step 1: Check Logs
```bash
# Look for errors in log files
grep -i error logs/*.log
grep -i fatal logs/*.log
```

### Step 2: Enable Waveforms
```bash
# Generate VCD files for analysis
make cache_random WAVES=1
# View with: gtkwave cache_test.vcd
```

### Step 3: Increase Verbosity
```bash
# Get detailed transaction logs
make mmu_basic VERBOSE=1
```

### Step 4: Debug Mode
```bash
# Run with simulator GUI
make debug_cache    # For cache tests
make debug_mmu      # For MMU tests
```

## Common Issues and Solutions

### Compilation Issues

**Problem**: UVM not found
```bash
# Solution: Set UVM_HOME
export UVM_HOME=/opt/questasim/verilog_src/uvm-1.2
```

**Problem**: RTL files missing
```bash
# Solution: Verify RTL structure
ls rtl/cache/l1_dcache.sv
ls rtl/mmu/mmu.sv
```

### Runtime Issues

**Problem**: Test timeout
```bash
# Check for: infinite loops, missing reset, clock issues
# Solution: Review DUT connections in testbench
```

**Problem**: Interface not found
```bash
# Check uvm_config_db settings in testbench
# Verify interface instantiation
```

## Advanced Testing

### Regression Testing
```bash
# Run complete test suite
make regression
```

### Coverage Analysis
```bash
# Collect functional coverage
make coverage
```

### Custom Test Creation

1. **Create new test class**:
   ```systemverilog
   class my_custom_test extends cache_base_test;
       // Custom test implementation
   endclass
   ```

2. **Add to package file**
3. **Update Makefile**
4. **Run new test**

### Performance Benchmarking

Monitor key metrics:
- **Cache hit rates** (target: >75%)
- **TLB hit rates** (target: >85%)  
- **Translation latency** (target: <10 cycles)
- **Memory bandwidth utilization**

## Continuous Integration

### Automated Testing
```bash
# Add to CI pipeline
make regression
if [ $? -eq 0 ]; then
    echo "All tests passed"
else
    echo "Tests failed - check logs"
    exit 1
fi
```

### Nightly Regression
Set up automated runs of:
1. All cache tests
2. All MMU tests  
3. Stress tests
4. Coverage collection

## Module-Specific Testing Details

### L1 D-Cache Testing
- **Size**: 32KB, 2-way set associative
- **Line Size**: 16 bytes (4 words)
- **Policy**: Write-back with MESI coherence
- **Tests**: Hit/miss ratios, coherency, performance

### MMU Testing  
- **Architecture**: RISC-V Sv32 virtual memory
- **TLB**: 16 entries, fully associative, LRU
- **Page Size**: 4KB pages
- **Tests**: Translation accuracy, fault handling, TLB management

### TLB Testing
- **Capacity**: 16 translation entries
- **Replacement**: LRU (Least Recently Used)
- **Invalidation**: Single entry and global flush
- **Tests**: Hit rates, replacement policy, invalidation

## Quality Metrics

### Test Quality Indicators
- **Pass Rate**: >95% of tests should pass
- **Coverage**: >90% functional coverage
- **Performance**: Meet timing requirements
- **Stability**: Consistent results across runs

### Bug Finding Effectiveness  
- **Cache bugs**: Data corruption, coherency violations
- **MMU bugs**: Translation errors, permission failures
- **Performance bugs**: Excessive latency, poor hit rates

## Getting Help

### Documentation
- `verification/uvm/README.md` - Detailed UVM guide
- Individual test log files for debugging
- RTL module comments for implementation details

### Debug Resources
- Waveform analysis with VCD files
- UVM transaction logs
- Simulator GUI debugging
- Built-in assertions and checkers

### Best Practices
1. Always run tests after RTL changes
2. Use waveforms for complex debugging
3. Monitor coverage metrics regularly
4. Create targeted tests for new features
5. Maintain clean, passing regression suite

This comprehensive testing framework ensures your RISC-V CPU modules are thoroughly verified and ready for integration!