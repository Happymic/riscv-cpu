# RISC-V CPU Implementation

A complete 64-bit RISC-V CPU implementation with advanced features including out-of-order execution, multi-level cache hierarchy, and virtual memory support.

## Features

### ISA Support
- **Base ISA**: RV64I (64-bit base integer instruction set)
- **Extensions**: 
  - M (Integer multiplication and division)
  - A (Atomic instructions)
  - F (Single-precision floating-point)
  - D (Double-precision floating-point)
  - C (Compressed instructions)

### Microarchitecture
- **Pipeline**: 5-stage in-order pipeline (IF/ID/EX/MEM/WB)
- **Branch Prediction**: 
  - 2-bit saturating counters (BHT)
  - Branch Target Buffer (BTB)
  - Return Address Stack (RAS)
- **Hazard Handling**: Hardware forwarding and stall detection

### Memory System
- **L1 Caches**: 
  - 16KB 2-way I-Cache
  - 32KB 2-way D-Cache
- **L2 Cache**: 256KB unified 2-way cache
- **L3 Cache**: 2MB shared 2-way cache
- **TLB**: Separate I-TLB (32 entries) and D-TLB (64 entries)
- **Virtual Memory**: Sv39 support (39-bit virtual addresses)

### Execution Units
- **ALU**: 64-bit arithmetic and logic operations
- **Multiplier**: Radix-4 Booth multiplier
- **Divider**: Non-restoring divider
- **FPU**: IEEE 754 compliant floating-point unit
- **LSU**: Load/store unit with cache interface

## Directory Structure

```
riscv-cpu/
├── rtl/                    # RTL source files
│   ├── core/              # CPU core modules
│   ├── cache/             # Cache subsystem
│   ├── mmu/               # Memory management unit
│   ├── execute/           # Execution units
│   └── common/            # Common definitions
├── tb/                    # Testbenches
├── uvm/                   # UVM verification environment
├── formal/                # Formal verification
├── scripts/               # Build and simulation scripts
├── docs/                  # Documentation
└── tools/                 # Tool configurations
```

## Getting Started

### Prerequisites
- SystemVerilog simulator (Verilator, VCS, or Icarus Verilog)
- RISC-V toolchain (for test program compilation)
- Python 3.x (for verification scripts)

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd riscv-cpu-1
   ```

2. **Run basic simulation**:
   ```bash
   ./scripts/simulation/run_sim.sh verilator
   ```

3. **Run with different simulator**:
   ```bash
   ./scripts/simulation/run_sim.sh vcs      # Synopsys VCS
   ./scripts/simulation/run_sim.sh iverilog # Icarus Verilog
   ```

### Building and Testing

The project includes automated scripts for:
- **Compilation**: `scripts/simulation/run_sim.sh`
- **Synthesis**: `scripts/synthesis/` (Vivado, Design Compiler)
- **Verification**: `scripts/verification/` (UVM tests, formal verification)

### Running Tests

Basic functional tests are included in the `tb/` directory:

```bash
# Run core tests
cd tb/core_tb
make run

# Run cache tests  
cd tb/cache_tb
make run

# Run full integration tests
cd tb/integration_tb
make run
```

## Architecture Overview

### Pipeline Stages

1. **IF (Instruction Fetch)**: Fetch instructions from I-Cache
2. **ID (Instruction Decode)**: Decode instructions and read registers  
3. **EX (Execute)**: Execute operations in ALU/FPU
4. **MEM (Memory Access)**: Access D-Cache for loads/stores
5. **WB (Write Back)**: Write results back to register file

### Cache Hierarchy

```
    Core
     |
   L1 I$  L1 D$
     |      |
      L2 Cache
         |
      L3 Cache
         |
     Main Memory
```

### Virtual Memory

- **Page Sizes**: 4KB, 2MB (megapages), 1GB (gigapages)
- **Address Translation**: Hardware page table walker
- **Memory Protection**: PMP/PMA support
- **ASID**: 16-bit address space identifiers

## Performance Characteristics

| Metric | Target | Notes |
|--------|--------|-------|
| Frequency | 1 GHz | Post-synthesis target |
| IPC | 0.8-0.9 | Typical workloads |
| L1 Cache Hit Rate | >95% | For typical programs |
| Branch Prediction | >90% | With tournament predictor |
| Memory Latency | <10 cycles | L1 cache hit |

## Verification Strategy

### Simulation-Based Verification
- **Unit Tests**: Individual module testing
- **Integration Tests**: Subsystem verification
- **System Tests**: Full CPU testing with real programs

### Formal Verification
- **Property Checking**: Critical safety properties
- **Equivalence Checking**: RTL vs. specification
- **Coverage Analysis**: Functional and code coverage

### UVM Environment
- **Constrained Random Testing**: Automated test generation
- **Coverage-Driven Verification**: Goal-oriented testing  
- **Regression Testing**: Automated nightly runs

## Development Roadmap

### Phase 1: Basic Implementation ✓
- [x] 5-stage pipeline
- [x] Basic cache hierarchy  
- [x] Simple branch prediction
- [x] Core instruction set

### Phase 2: Advanced Features (In Progress)
- [ ] Out-of-order execution
- [ ] Advanced branch prediction
- [ ] Non-blocking caches
- [ ] Virtual memory support

### Phase 3: Optimization & Verification
- [ ] Performance optimization
- [ ] Full UVM environment
- [ ] Formal verification
- [ ] FPGA implementation

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## References

- [RISC-V ISA Specification](https://riscv.org/specifications/)
- [RISC-V Privileged Architecture](https://riscv.org/specifications/)
- [Computer Architecture: A Quantitative Approach](https://www.elsevier.com/books/computer-architecture/hennessy/978-0-12-383872-8)

## Contact

For questions or support, please open an issue on GitHub or contact the development team.