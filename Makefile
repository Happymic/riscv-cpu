#################################################################################
# Makefile for RISC-V CPU Project
# Supports simulation with multiple simulators and synthesis
#################################################################################

# Project configuration
PROJECT_NAME = riscv_cpu
TOP_MODULE = top
TB_MODULE = cpu_tb

# Directory structure
RTL_DIR = rtl
TB_DIR = testbench
SCRIPTS_DIR = scripts
BUILD_DIR = build

# Source files
RTL_SOURCES = $(RTL_DIR)/top.sv \
              $(RTL_DIR)/cpu/cpu_types.sv \
              $(RTL_DIR)/cpu/cpu_core.sv \
              $(RTL_DIR)/cpu/if_stage.sv \
              $(RTL_DIR)/cpu/id_stage.sv \
              $(RTL_DIR)/cpu/ex_stage.sv \
              $(RTL_DIR)/cpu/mem_stage.sv \
              $(RTL_DIR)/cpu/wb_stage.sv \
              $(RTL_DIR)/cpu/regfile.sv \
              $(RTL_DIR)/cpu/control_unit.sv \
              $(RTL_DIR)/cpu/hazard_unit.sv \
              $(RTL_DIR)/cpu/branch_predictor.sv \
              $(RTL_DIR)/cpu/csr.sv \
              $(RTL_DIR)/cache/l1_icache.sv \
              $(RTL_DIR)/cache/l1_dcache.sv \
              $(RTL_DIR)/cache/l2_cache.sv \
              $(RTL_DIR)/cache/l3_cache.sv \
              $(RTL_DIR)/mmu/mmu.sv \
              $(RTL_DIR)/mmu/tlb.sv \
              $(RTL_DIR)/mmu/page_table_walk.sv \
              $(RTL_DIR)/mmu/exception_handler.sv \
              $(RTL_DIR)/memory/dram_model.sv

TB_SOURCES = $(TB_DIR)/cpu_tb.sv

ALL_SOURCES = $(RTL_SOURCES) $(TB_SOURCES)

# Simulator configuration
SIMULATOR ?= iverilog

# Simulator-specific settings
ifeq ($(SIMULATOR),iverilog)
    COMPILE_CMD = iverilog -g2012 -o $(BUILD_DIR)/$(TB_MODULE) $(ALL_SOURCES)
    SIMULATE_CMD = vvp $(BUILD_DIR)/$(TB_MODULE)
    WAVE_FILE = $(BUILD_DIR)/cpu_tb.vcd
endif

ifeq ($(SIMULATOR),verilator)
    COMPILE_CMD = verilator --cc --exe --build -j 0 -Wall --trace \
                  --top-module $(TB_MODULE) $(ALL_SOURCES) --exe /dev/null
    SIMULATE_CMD = ./obj_dir/V$(TB_MODULE)
    WAVE_FILE = $(BUILD_DIR)/cpu_tb.vcd
endif

ifeq ($(SIMULATOR),modelsim)
    COMPILE_CMD = vlog -work work $(ALL_SOURCES)
    SIMULATE_CMD = vsim -c -do "run -all; exit" work.$(TB_MODULE)
    WAVE_FILE = $(BUILD_DIR)/cpu_tb.wlf
endif

ifeq ($(SIMULATOR),xsim)
    COMPILE_CMD = xvlog --sv $(ALL_SOURCES) && xelab $(TB_MODULE) -s $(TB_MODULE)_sim
    SIMULATE_CMD = xsim $(TB_MODULE)_sim -runall
    WAVE_FILE = $(BUILD_DIR)/cpu_tb.wdb
endif

# Default target
all: simulate

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile design
compile: $(BUILD_DIR)
	@echo "Compiling with $(SIMULATOR)..."
	cd $(BUILD_DIR) && $(COMPILE_CMD)
	@echo "Compilation completed."

# Run simulation
simulate: compile
	@echo "Running simulation with $(SIMULATOR)..."
	cd $(BUILD_DIR) && $(SIMULATE_CMD)
	@echo "Simulation completed."

# Run simulation with waveform dumping
simulate_wave: compile
	@echo "Running simulation with waveform dump..."
	cd $(BUILD_DIR) && $(COMPILE_CMD) -DDUMP_VCD && $(SIMULATE_CMD)
	@echo "Simulation completed. Waveform saved to $(WAVE_FILE)"

# Quick test with Icarus Verilog
quick_test: $(BUILD_DIR)
	@echo "Running quick test with Icarus Verilog..."
	cd $(BUILD_DIR) && iverilog -g2012 -DDUMP_VCD -o $(TB_MODULE) $(addprefix ../,$(ALL_SOURCES))
	cd $(BUILD_DIR) && vvp $(TB_MODULE)
	@echo "Quick test completed."

# View waveforms
wave:
	@if [ -f "$(BUILD_DIR)/cpu_tb.vcd" ]; then \
		gtkwave $(BUILD_DIR)/cpu_tb.vcd; \
	else \
		echo "No VCD file found. Run 'make simulate_wave' first."; \
	fi

# Run synthesis
.PHONY: synth
synth: $(BUILD_DIR)
	@echo "Running synthesis with $(SYNTH_TOOL)..."
	$(SCRIPTS_DIR)/synthesis/synth_$(SYNTH_TOOL).tcl

# Lint the design
lint: $(BUILD_DIR)
	@echo "Linting design with Verilator..."
	verilator --lint-only --top-module $(TOP_MODULE) $(RTL_SOURCES)
	@echo "Linting completed."

# Synthesize with Yosys (if available)
synthesize: $(BUILD_DIR)
	@echo "Synthesizing design with Yosys..."
	cd $(BUILD_DIR) && yosys -p "read_verilog -sv $(addprefix ../,$(RTL_SOURCES)); synth -top $(TOP_MODULE); write_verilog $(PROJECT_NAME)_synth.v"
	@echo "Synthesis completed."

# Assembly test programs
assemble_tests:
	@echo "Assembling test programs..."
	@for test in $(TB_DIR)/test_programs/*.s; do \
		base=$$(basename $$test .s); \
		echo "Assembling $$test..."; \
		riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o $(BUILD_DIR)/$$base.o $$test; \
		riscv64-unknown-elf-ld -m elf32lriscv -Ttext 0x0 -o $(BUILD_DIR)/$$base.elf $(BUILD_DIR)/$$base.o; \
		riscv64-unknown-elf-objcopy -O binary $(BUILD_DIR)/$$base.elf $(BUILD_DIR)/$$base.bin; \
		riscv64-unknown-elf-objdump -d $(BUILD_DIR)/$$base.elf > $(BUILD_DIR)/$$base.dump; \
		xxd -g 4 $(BUILD_DIR)/$$base.bin > $(BUILD_DIR)/$$base.hex; \
	done
	@echo "Test programs assembled."

# Generate documentation
docs:
	@echo "Generating documentation..."
	@mkdir -p docs/generated
	@echo "# RISC-V CPU Documentation" > docs/generated/README.md
	@echo "" >> docs/generated/README.md
	@echo "## Module Hierarchy" >> docs/generated/README.md
	@find $(RTL_DIR) -name "*.sv" -exec echo "- {}" \; >> docs/generated/README.md
	@echo "Documentation generated in docs/generated/"

# Format code
.PHONY: format
format:
	@echo "Formatting SystemVerilog code..."
	@if command -v verible-verilog-format >/dev/null 2>&1; then \
		find $(RTL_DIR) -name "*.sv" -exec verible-verilog-format --inplace {} \; ; \
		find $(TB_DIR) -name "*.sv" -exec verible-verilog-format --inplace {} \; ; \
	else \
		echo "verible-verilog-format not found, skipping formatting"; \
	fi

# UVM tests
.PHONY: uvm
uvm:
	@echo "Running UVM tests..."
	@$(MAKE) -C uvm/test run

# Formal verification
.PHONY: formal
formal:
	@echo "Running formal verification..."
	@$(SCRIPTS_DIR)/formal/run_formal.sh

# Performance analysis
.PHONY: perf
perf: sim
	@echo "Running performance analysis..."
	@python3 $(SCRIPTS_DIR)/analysis/perf_analysis.py $(BUILD_DIR)/sim.log

# Coverage analysis
.PHONY: coverage
coverage:
	@echo "Running coverage analysis..."
	@$(SCRIPTS_DIR)/verification/coverage.sh

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -rf obj_dir
	rm -f *.vcd *.wlf *.log

# Clean everything including documentation
distclean: clean
	rm -rf docs/generated

# Run regression tests
regression: clean quick_test
	@echo "All regression tests passed!"

# Show help
help:
	@echo "Available targets:"
	@echo "  all          - Default target (same as simulate)"
	@echo "  compile      - Compile the design"
	@echo "  simulate     - Run simulation"
	@echo "  simulate_wave- Run simulation with waveform dump"
	@echo "  quick_test   - Quick test with Icarus Verilog"
	@echo "  wave         - View waveforms with GTKWave"
	@echo "  lint         - Lint design with Verilator"
	@echo "  synthesize   - Synthesize design with Yosys"
	@echo "  assemble_tests - Assemble test programs"
	@echo "  docs         - Generate documentation"
	@echo "  clean        - Clean build artifacts"
	@echo "  distclean    - Clean everything"
	@echo "  regression   - Run regression tests"
	@echo "  help         - Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  SIMULATOR    - Choose simulator: iverilog, verilator, modelsim, xsim"
	@echo ""
	@echo "Examples:"
	@echo "  make SIMULATOR=verilator simulate"
	@echo "  make quick_test"
	@echo "  make simulate_wave && make wave"

# Phony targets
.PHONY: all compile simulate simulate_wave quick_test wave lint synthesize assemble_tests docs clean distclean regression help

#################################################################################
# End of Makefile
#################################################################################
