#!/bin/bash
# RISC-V CPU Simulation Script
# Author: Auto-generated
# Date: 2025-09-03
#
# What this script does (plain language):
# - Compiles and runs the RISC-V CPU testbench with a chosen simulator.
# - Supports Verilator, Synopsys VCS, and Icarus Verilog.
# - Collects all RTL and testbench sources, sets include paths, builds to ./build.
#
# How to use:
#   ./scripts/simulation/run_sim.sh            # default (verilator)
#   ./scripts/simulation/run_sim.sh verilator  # explicit verilator
#   ./scripts/simulation/run_sim.sh vcs        # Synopsys VCS
#   ./scripts/simulation/run_sim.sh iverilog   # Icarus Verilog
#
# Key paths:
# - PROJECT_ROOT: repo root
# - RTL_DIR: RTL sources grouped by subsystem
# - TB_DIR: testbench sources (top module: riscv_core_tb)
# - BUILD_DIR: tool-generated binaries and intermediates
#
# Output artifacts:
# - BUILD_DIR/verilator/* (Verilator build products)
# - BUILD_DIR/riscv_sim   (sim binary for vcs/iverilog)
# - tb waveform: riscv_core_tb.vcd (dumped by TB itself)
#
# Notes:
# - For Verilator we use --cc --exe: Verilator generates a C++ sim; TB must be SystemVerilog-compatible or wrapped.
# - The globbing "*.sv" picks all modules; adjust if you later partition by filelists.
# - Exit codes: non-zero on compilation failures.

# Set default simulator
SIM=${1:-"verilator"}

# Project directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RTL_DIR="$PROJECT_ROOT/rtl"
TB_DIR="$PROJECT_ROOT/tb"
BUILD_DIR="$PROJECT_ROOT/build"

echo "RISC-V CPU Simulation Script"
echo "Project Root: $PROJECT_ROOT"
echo "Using simulator: $SIM"

# Create build directory
mkdir -p "$BUILD_DIR"

case $SIM in
    "verilator")
        echo "Running Verilator simulation..."
        # Verilator flags:
        #  -Wall        : enable common warnings
        #  --cc --exe   : generate and build C++ simulation
        #  -I<dir>      : add include path for `include files and common headers
        #  --top-module : explicit testbench top (SystemVerilog TB drives the DUT)
        verilator -Wall --cc --exe --no-timing \
            -I"$RTL_DIR/common" \
            "$RTL_DIR/core"/*.sv \
            "$RTL_DIR/core/pipeline"/*.sv \
            "$RTL_DIR/core/hazard"/*.sv \
            "$RTL_DIR/core/branch"/*.sv \
            "$RTL_DIR/core/regfile"/*.sv \
            "$RTL_DIR/core/decode"/*.sv \
            "$RTL_DIR/cache"/*.sv \
            "$RTL_DIR/mmu"/*.sv \
            "$RTL_DIR/execute"/*.sv \
            "$RTL_DIR/common"/*.sv \
            "$TB_DIR/core_tb"/*.sv \
            --top-module riscv_core_tb \
            -Mdir "$BUILD_DIR/verilator" \
            -o riscv_sim
        
        if [ $? -eq 0 ]; then
            cd "$BUILD_DIR/verilator"
            # Generated makefile name is derived from top name; run build then execute
            make -f Vriscv_core_tb.mk
            ./riscv_sim
        else
            echo "Verilator compilation failed"
            exit 1
        fi
        ;;
    
    "vcs")
        echo "Running VCS simulation..."
        cd "$BUILD_DIR"
        vcs -sverilog -timescale=1ns/1ps \
            -I"$RTL_DIR/common" \
            "$RTL_DIR/core"/*.sv \
            "$RTL_DIR/core/pipeline"/*.sv \
            "$RTL_DIR/core/hazard"/*.sv \
            "$RTL_DIR/core/branch"/*.sv \
            "$RTL_DIR/core/regfile"/*.sv \
            "$RTL_DIR/core/decode"/*.sv \
            "$RTL_DIR/cache"/*.sv \
            "$RTL_DIR/mmu"/*.sv \
            "$RTL_DIR/execute"/*.sv \
            "$RTL_DIR/common"/*.sv \
            "$TB_DIR/core_tb"/*.sv \
            -o riscv_sim
        # VCS will emit ./build/riscv_sim; if compilation succeeds, we run it.
        if [ $? -eq 0 ]; then
            ./riscv_sim
        else
            echo "VCS compilation failed"
            exit 1
        fi
        ;;
        
    "iverilog")
        echo "Running Icarus Verilog simulation..."
        cd "$BUILD_DIR"
        iverilog -g2012 \
            -I"$RTL_DIR/common" \
            -o riscv_sim \
            "$RTL_DIR/core"/*.sv \
            "$RTL_DIR/core/pipeline"/*.sv \
            "$RTL_DIR/core/hazard"/*.sv \
            "$RTL_DIR/core/branch"/*.sv \
            "$RTL_DIR/core/regfile"/*.sv \
            "$RTL_DIR/core/decode"/*.sv \
            "$RTL_DIR/cache"/*.sv \
            "$RTL_DIR/mmu"/*.sv \
            "$RTL_DIR/execute"/*.sv \
            "$RTL_DIR/common"/*.sv \
            "$TB_DIR/core_tb"/*.sv
        # vvp executes the compiled simulation image and produces VCD via TB $dumpvars
        if [ $? -eq 0 ]; then
            vvp riscv_sim
        else
            echo "Icarus Verilog compilation failed"
            exit 1
        fi
        ;;
    
    *)
        echo "Unknown simulator: $SIM"
        echo "Supported simulators: verilator, vcs, iverilog"
        exit 1
        ;;
esac

echo "Simulation completed"
