#################################################################################
# UVM Verification Makefile for RISC-V CPU
# Description: Comprehensive makefile for running UVM tests
#################################################################################

# Default simulator (change to your preferred simulator)
SIM ?= verilator

# Simulator specific settings
ifeq ($(SIM),questa)
    VLOG = vlog
    VSIM = vsim
    VLOG_FLAGS = +incdir+$(UVM_HOME)/src +define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR
    VSIM_FLAGS = -c -do "run -all; quit -f"
else ifeq ($(SIM),vcs)
    VLOG = vcs
    VSIM = ./simv
    VLOG_FLAGS = +incdir+$(UVM_HOME)/src +define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR
    VSIM_FLAGS = +UVM_TESTNAME
else ifeq ($(SIM),xcelium)
    VLOG = xmvlog
    VSIM = xmsim
    VLOG_FLAGS = +incdir+$(UVM_HOME)/src +define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR
    VSIM_FLAGS = -R
else ifeq ($(SIM),verilator)
    VLOG = verilator
    VSIM = ./obj_dir/V
    VLOG_FLAGS = --lint-only -Wno-EOFNEWLINE -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-MULTITOP -Wno-CASEINCOMPLETE -Wno-WIDTHCONCAT -Wno-DECLFILENAME
    VSIM_FLAGS = 
else ifeq ($(SIM),iverilog)
    VLOG = iverilog
    VSIM = vvp
    VLOG_FLAGS = -g2012 -I
    VSIM_FLAGS = 
endif

# Paths
RTL_PATH = ../../rtl
UVM_PATH = .
TB_PATH = $(UVM_PATH)/testbench
PKG_PATH = $(UVM_PATH)/packages
IF_PATH = $(UVM_PATH)/interfaces
MODEL_PATH = $(UVM_PATH)/models
ENV_PATH = $(UVM_PATH)/env
AGENT_PATH = $(UVM_PATH)/agents
SEQ_PATH = $(UVM_PATH)/sequences
TEST_PATH = $(UVM_PATH)/tests

# RTL source files
RTL_CACHE_FILES = \
    $(RTL_PATH)/cache/l1_dcache.sv \
    $(RTL_PATH)/cache/l2_cache.sv \
    $(RTL_PATH)/cache/l3_cache.sv

RTL_MMU_FILES = \
    $(RTL_PATH)/mmu/tlb.sv \
    $(RTL_PATH)/mmu/mmu.sv \
    $(RTL_PATH)/mmu/page_table_walk.sv \
    $(RTL_PATH)/mmu/exception_handler.sv

# UVM package files
CACHE_PKG_FILES = \
    $(SEQ_PATH)/cache_transaction.sv \
    $(ENV_PATH)/cache_config.sv \
    $(AGENT_PATH)/cache_sequencer.sv \
    $(AGENT_PATH)/cache_driver.sv \
    $(AGENT_PATH)/cache_monitor.sv \
    $(AGENT_PATH)/cache_agent.sv \
    $(ENV_PATH)/cache_scoreboard.sv \
    $(ENV_PATH)/cache_env.sv \
    $(SEQ_PATH)/cache_sequences.sv \
    $(TEST_PATH)/cache_test.sv

MMU_PKG_FILES = \
    $(SEQ_PATH)/mmu_transaction.sv \
    $(ENV_PATH)/mmu_config.sv \
    $(AGENT_PATH)/mmu_sequencer.sv \
    $(AGENT_PATH)/mmu_driver.sv \
    $(AGENT_PATH)/mmu_monitor.sv \
    $(AGENT_PATH)/mmu_agent.sv \
    $(ENV_PATH)/mmu_scoreboard.sv \
    $(ENV_PATH)/mmu_env.sv \
    $(SEQ_PATH)/mmu_sequences.sv \
    $(TEST_PATH)/mmu_test.sv

# Interface files
INTERFACE_FILES = \
    $(IF_PATH)/cache_if.sv \
    $(IF_PATH)/mmu_if.sv

# Model files
MODEL_FILES = \
    $(MODEL_PATH)/l2_cache_model.sv \
    $(MODEL_PATH)/memory_model.sv

# Testbench files
TB_FILES = \
    $(TB_PATH)/cache_tb.sv \
    $(TB_PATH)/mmu_tb.sv

# Test targets
.PHONY: all clean cache_tests mmu_tests tlb_tests help

# Default target
all: cache_tests mmu_tests

help:
	@echo "==================================================================="
	@echo "UVM Verification Makefile for RISC-V CPU"
	@echo "==================================================================="
	@echo "🚀 QUICK START FOR MAC USERS:"
	@echo "  1. Install tools: brew install verilator"
	@echo "  2. Check files:   python3 ../simple_check.py"
	@echo "  3. Test syntax:   make compile_cache"
	@echo "  4. Test syntax:   make compile_mmu"
	@echo ""
	@echo "Available targets:"
	@echo "  all           - Run all tests"
	@echo "  cache_tests   - Run all cache tests"
	@echo "  mmu_tests     - Run all MMU tests"
	@echo "  tlb_tests     - Run TLB specific tests"
	@echo "  clean         - Clean up generated files"
	@echo ""
	@echo "Compilation Tests (No UVM needed):"
	@echo "  compile_cache - Test cache module compilation"
	@echo "  compile_mmu   - Test MMU module compilation"
	@echo "  lint          - Run lint checks on RTL"
	@echo ""
	@echo "Cache Tests:"
	@echo "  cache_random  - Random cache operations test"
	@echo "  cache_seq     - Sequential cache access test"
	@echo "  cache_wr      - Write-read coherency test"
	@echo "  cache_stress  - Cache stress test"
	@echo ""
	@echo "MMU Tests:"
	@echo "  mmu_basic     - Basic MMU translation test"
	@echo "  mmu_fault     - Page fault test"
	@echo "  mmu_stress    - MMU stress test"
	@echo ""
	@echo "Simulator Options:"
	@echo "  SIM=verilator              - Verilator (default, good for Mac)"
	@echo "  SIM=iverilog               - Icarus Verilog (open source)"
	@echo "  SIM=questa|vcs|xcelium     - Commercial simulators"
	@echo "  WAVES=1                    - Enable waveform dumping"
	@echo "  VERBOSE=1                  - Enable verbose output"
	@echo ""
	@echo "📋 Install simulators on Mac:"
	@echo "  brew install verilator     - Best for synthesis/lint checking"
	@echo "  brew install icarus-verilog - Good for simulation"
	@echo "==================================================================="

# Cache tests
cache_tests: cache_random cache_seq cache_wr cache_stress

cache_random:
	@echo "Running Cache Random Test..."
	@$(MAKE) run_test TEST=cache_random_test TB=cache_tb

cache_seq:
	@echo "Running Cache Sequential Test..."
	@$(MAKE) run_test TEST=cache_sequential_test TB=cache_tb

cache_wr:
	@echo "Running Cache Write-Read Test..."
	@$(MAKE) run_test TEST=cache_write_read_test TB=cache_tb

cache_stress:
	@echo "Running Cache Stress Test..."
	@$(MAKE) run_test TEST=cache_stress_test TB=cache_tb

# MMU tests
mmu_tests: mmu_basic mmu_fault mmu_stress

mmu_basic:
	@echo "Running MMU Basic Test..."
	@$(MAKE) run_test TEST=mmu_basic_test TB=mmu_tb

mmu_fault:
	@echo "Running MMU Page Fault Test..."
	@$(MAKE) run_test TEST=mmu_fault_test TB=mmu_tb

mmu_stress:
	@echo "Running MMU Stress Test..."
	@$(MAKE) run_test TEST=mmu_stress_test TB=mmu_tb

# TLB tests
tlb_tests:
	@echo "Running TLB Tests..."
	@$(MAKE) run_test TEST=tlb_basic_test TB=mmu_tb

# Generic test runner
run_test:
	@echo "Compiling $(TB) with test $(TEST)..."
	@mkdir -p work logs
ifeq ($(SIM),questa)
	$(VLOG) $(VLOG_FLAGS) \
		+incdir+$(PKG_PATH) \
		+incdir+$(IF_PATH) \
		+incdir+$(ENV_PATH) \
		+incdir+$(AGENT_PATH) \
		+incdir+$(SEQ_PATH) \
		+incdir+$(TEST_PATH) \
		-work work \
		$(INTERFACE_FILES) \
		$(MODEL_FILES) \
		$(RTL_CACHE_FILES) \
		$(RTL_MMU_FILES) \
		$(PKG_PATH)/cache_pkg.sv \
		$(PKG_PATH)/mmu_pkg.sv \
		$(TB_PATH)/$(TB).sv
	$(VSIM) $(VSIM_FLAGS) \
		+UVM_TESTNAME=$(TEST) \
		$(if $(WAVES),+UVM_DUMP_ALL,) \
		$(if $(VERBOSE),+UVM_VERBOSITY=UVM_HIGH,+UVM_VERBOSITY=UVM_MEDIUM) \
		-l logs/$(TEST).log \
		work.$(TB)
else ifeq ($(SIM),vcs)
	$(VLOG) $(VLOG_FLAGS) \
		+incdir+$(PKG_PATH) \
		+incdir+$(IF_PATH) \
		+incdir+$(ENV_PATH) \
		+incdir+$(AGENT_PATH) \
		+incdir+$(SEQ_PATH) \
		+incdir+$(TEST_PATH) \
		-o simv_$(TEST) \
		$(INTERFACE_FILES) \
		$(MODEL_FILES) \
		$(RTL_CACHE_FILES) \
		$(RTL_MMU_FILES) \
		$(PKG_PATH)/cache_pkg.sv \
		$(PKG_PATH)/mmu_pkg.sv \
		$(TB_PATH)/$(TB).sv
	./simv_$(TEST) \
		+UVM_TESTNAME=$(TEST) \
		$(if $(WAVES),+UVM_DUMP_ALL,) \
		$(if $(VERBOSE),+UVM_VERBOSITY=UVM_HIGH,+UVM_VERBOSITY=UVM_MEDIUM) \
		-l logs/$(TEST).log
endif

# Individual test compilation (for debugging)
compile_cache:
	@echo "Compiling cache verification environment..."
	@mkdir -p work
ifeq ($(SIM),verilator)
	@echo "Using Verilator for syntax checking..."
	$(VLOG) $(VLOG_FLAGS) \
		-I$(PKG_PATH) \
		-I$(IF_PATH) \
		-I$(ENV_PATH) \
		-I$(AGENT_PATH) \
		-I$(SEQ_PATH) \
		-I$(TEST_PATH) \
		$(RTL_CACHE_FILES)
else ifeq ($(SIM),iverilog)
	@echo "Using Icarus Verilog..."
	$(VLOG) $(VLOG_FLAGS) \
		$(PKG_PATH) \
		$(IF_PATH) \
		$(ENV_PATH) \
		$(AGENT_PATH) \
		$(SEQ_PATH) \
		$(TEST_PATH) \
		-o work/cache_test \
		$(RTL_CACHE_FILES) \
		$(TB_PATH)/cache_tb.sv
else
	$(VLOG) $(VLOG_FLAGS) \
		+incdir+$(PKG_PATH) \
		+incdir+$(IF_PATH) \
		+incdir+$(ENV_PATH) \
		+incdir+$(AGENT_PATH) \
		+incdir+$(SEQ_PATH) \
		+incdir+$(TEST_PATH) \
		-work work \
		$(IF_PATH)/cache_if.sv \
		$(MODEL_PATH)/l2_cache_model.sv \
		$(RTL_CACHE_FILES) \
		$(PKG_PATH)/cache_pkg.sv \
		$(TB_PATH)/cache_tb.sv
endif

compile_mmu:
	@echo "Compiling MMU verification environment..."
	@mkdir -p work
ifeq ($(SIM),verilator)
	@echo "Using Verilator for syntax checking..."
	$(VLOG) $(VLOG_FLAGS) \
		-I$(PKG_PATH) \
		-I$(IF_PATH) \
		-I$(ENV_PATH) \
		-I$(AGENT_PATH) \
		-I$(SEQ_PATH) \
		-I$(TEST_PATH) \
		$(RTL_MMU_FILES)
else ifeq ($(SIM),iverilog)
	@echo "Using Icarus Verilog..."
	$(VLOG) $(VLOG_FLAGS) \
		$(PKG_PATH) \
		$(IF_PATH) \
		$(ENV_PATH) \
		$(AGENT_PATH) \
		$(SEQ_PATH) \
		$(TEST_PATH) \
		-o work/mmu_test \
		$(RTL_MMU_FILES) \
		$(TB_PATH)/mmu_tb.sv
else
	$(VLOG) $(VLOG_FLAGS) \
		+incdir+$(PKG_PATH) \
		+incdir+$(IF_PATH) \
		+incdir+$(ENV_PATH) \
		+incdir+$(AGENT_PATH) \
		+incdir+$(SEQ_PATH) \
		+incdir+$(TEST_PATH) \
		-work work \
		$(IF_PATH)/mmu_if.sv \
		$(MODEL_PATH)/memory_model.sv \
		$(RTL_MMU_FILES) \
		$(PKG_PATH)/mmu_pkg.sv \
		$(TB_PATH)/mmu_tb.sv
endif

# Regression test suite
regression:
	@echo "Running regression test suite..."
	@$(MAKE) clean
	@$(MAKE) all
	@echo "Regression complete. Check logs/ directory for results."

# Clean up
clean:
	@echo "Cleaning up generated files..."
	@rm -rf work
	@rm -rf logs
	@rm -f *.vcd *.wlf *.log
	@rm -f transcript vsim.wlf
	@rm -f simv_* csrc/ simv.daidir/
	@rm -f *.vpd *.vdb
	@echo "Clean complete."

# Create necessary directories
setup:
	@mkdir -p work logs
	@echo "Directory structure created."

# Lint checks (if available)
lint:
	@echo "Running lint checks..."
ifeq ($(shell which verilator),)
	@echo "Verilator not found, skipping lint checks"
else
	verilator --lint-only $(RTL_CACHE_FILES) $(RTL_MMU_FILES)
endif

# Coverage collection (simulator specific)
coverage:
	@echo "Collecting coverage..."
	@$(MAKE) all COVERAGE=1

# Debug mode (with GUI)
debug_cache:
	@$(MAKE) run_test TEST=cache_random_test TB=cache_tb VSIM_FLAGS="-gui -do wave.do"

debug_mmu:
	@$(MAKE) run_test TEST=mmu_basic_test TB=mmu_tb VSIM_FLAGS="-gui -do wave.do"