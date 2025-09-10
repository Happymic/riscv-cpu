# RISC-V CPU Makefile
# Author: Auto-generated
# Date: 2025-09-03
# -----------------------------------------------------------------------------
# What this Makefile does:
# - Wraps common development tasks: compile, sim, test, synth, lint, docs, etc.
# - Delegates to scripts/simulation/run_sim.sh for multi-simulator flows.
# - Provides convenience targets for cleaning and environment checks.
#
# How to use:
# - make            # default compile with $(SIM)
# - make sim        # compile then run
# - make lint       # verilator lint if available
# - make clean      # remove build artifacts and waves
# - make help       # list targets
#
# Variables:
# - SIM=verilator|vcs|iverilog
# - SYNTH_TOOL=vivado|dc
# -----------------------------------------------------------------------------

# Project configuration
PROJECT_NAME = riscv_cpu
TOP_MODULE = riscv_top
TESTBENCH = riscv_core_tb

# Directories
RTL_DIR = rtl
TB_DIR = tb
BUILD_DIR = build
DOCS_DIR = docs
SCRIPTS_DIR = scripts

# Tool configuration
SIM ?= verilator
SYNTH_TOOL ?= vivado

# RTL source files
RTL_SOURCES = $(shell find $(RTL_DIR) -name "*.sv")
TB_SOURCES = $(shell find $(TB_DIR) -name "*.sv")

# Default target
.PHONY: all
all: compile

# Help target
.PHONY: help
help:
	@echo "RISC-V CPU Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  compile    - Compile RTL using default simulator"
	@echo "  sim        - Run simulation"
	@echo "  test       - Run all tests"
	@echo "  synth      - Run synthesis"
	@echo "  clean      - Clean build directory"
	@echo "  docs       - Generate documentation"
	@echo "  lint       - Run linting checks"
	@echo ""
	@echo "Variables:"
	@echo "  SIM        - Simulator to use (verilator, vcs, iverilog)"
	@echo "  SYNTH_TOOL - Synthesis tool (vivado, dc)"

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile RTL
.PHONY: compile
compile: $(BUILD_DIR)
	@echo "Compiling RTL with $(SIM)..."
	$(SCRIPTS_DIR)/simulation/run_sim.sh $(SIM)

# Run simulation
.PHONY: sim
sim: compile
	@echo "Running simulation..."
	@cd $(BUILD_DIR) && ./riscv_sim

# Run tests
.PHONY: test
test:
	@echo "Running tests..."
	@$(MAKE) -C $(TB_DIR)/core_tb test
	@$(MAKE) -C $(TB_DIR)/cache_tb test
	@$(MAKE) -C $(TB_DIR)/mmu_tb test
	@$(MAKE) -C $(TB_DIR)/integration_tb test

# Run synthesis
.PHONY: synth
synth: $(BUILD_DIR)
	@echo "Running synthesis with $(SYNTH_TOOL)..."
	$(SCRIPTS_DIR)/synthesis/synth_$(SYNTH_TOOL).tcl

# Linting
.PHONY: lint
lint:
	@echo "Running linting checks..."
	@if command -v verilator >/dev/null 2>&1; then \
		verilator --lint-only --Wall -I$(RTL_DIR)/common $(RTL_SOURCES); \
	else \
		echo "Verilator not found, skipping lint"; \
	fi

# Documentation
.PHONY: docs
docs:
	@echo "Generating documentation..."
	@if command -v sphinx-build >/dev/null 2>&1; then \
		cd $(DOCS_DIR) && sphinx-build -b html . _build; \
	else \
		echo "Sphinx not found, skipping documentation generation"; \
	fi

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
.PHONY: clean
clean:
	@echo "Cleaning build directory..."
	rm -rf $(BUILD_DIR)
	find . -name "*.vcd" -delete
	find . -name "*.vpd" -delete
	find . -name "*.fsdb" -delete
	find . -name "*.log" -delete
	find . -name "simv*" -delete
	find . -name "csrc" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name ".simvision" -type d -exec rm -rf {} + 2>/dev/null || true

# Deep clean (including tool-generated files)
.PHONY: distclean
distclean: clean
	rm -rf vivado.*
	rm -rf .Xil
	rm -rf work
	find . -name "*.jou" -delete
	find . -name "*.str" -delete

# Install dependencies
.PHONY: install-deps
install-deps:
	@echo "Installing dependencies..."
	@if [ -f requirements.txt ]; then pip3 install -r requirements.txt; fi

# Git hooks setup
.PHONY: setup-hooks
setup-hooks:
	@echo "Setting up git hooks..."
	@cp scripts/git-hooks/* .git/hooks/
	@chmod +x .git/hooks/*

# Check environment
.PHONY: check-env
check-env:
	@echo "Checking environment..."
	@echo "SystemVerilog simulators:"
	@command -v verilator >/dev/null && echo "  ✓ Verilator found" || echo "  ✗ Verilator not found"
	@command -v vcs >/dev/null && echo "  ✓ VCS found" || echo "  ✗ VCS not found"
	@command -v iverilog >/dev/null && echo "  ✓ Icarus Verilog found" || echo "  ✗ Icarus Verilog not found"
	@echo "Synthesis tools:"
	@command -v vivado >/dev/null && echo "  ✓ Vivado found" || echo "  ✗ Vivado not found"
	@echo "Verification tools:"
	@command -v python3 >/dev/null && echo "  ✓ Python3 found" || echo "  ✗ Python3 not found"

# Development workflow
.PHONY: dev
dev: lint compile sim test
	@echo "Development workflow completed successfully!"

# Continuous integration
.PHONY: ci
ci: check-env lint compile test coverage
	@echo "CI pipeline completed!"

# Print project statistics
.PHONY: stats
stats:
	@echo "Project Statistics:"
	@echo "RTL files: $(shell find $(RTL_DIR) -name "*.sv" | wc -l)"
	@echo "RTL lines: $(shell find $(RTL_DIR) -name "*.sv" -exec wc -l {} + | tail -1)"
	@echo "Test files: $(shell find $(TB_DIR) -name "*.sv" | wc -l)"
	@echo "Test lines: $(shell find $(TB_DIR) -name "*.sv" -exec wc -l {} + | tail -1)"
