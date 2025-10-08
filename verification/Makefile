# -------- Tools --------
IVERILOG ?= iverilog
VVP      ?= vvp

# -------- Dirs --------
RTL_DIR := rtl/cpu
TB_DIR  := verification/unit_tests
BUILD   := build
WAVES   := waves

# -------- Files --------
RTL := $(RTL_DIR)/regfile.sv
TB  := $(TB_DIR)/regfile_tb.sv

TOP      := regfile_tb
OUT_ELF  := $(BUILD)/$(TOP).out

# 让 run_all_unit_tests 可扩展：后续加更多 *_tb.sv 会自动纳入
UNIT_TBS   := $(wildcard $(TB_DIR)/*_tb.sv)
UNIT_OUTS  := $(patsubst $(TB_DIR)/%_tb.sv, $(BUILD)/%_tb.out, $(UNIT_TBS))

# -------- Phonies --------
.PHONY: all run clean waves run_all_unit_tests regfile_test

all: run

# 单测聚合（所有 *_tb.sv）
run_all_unit_tests: $(UNIT_OUTS)
	@echo "Running all unit tests..."
	@for sim in $(UNIT_OUTS); do \
	  echo "==> $$sim"; \
	  $(VVP) $$sim || exit $$?; \
	done
	@echo "All unit tests completed."

# 专门的 regfile 测试（与你给的目标名保持一致）
regfile_test: $(OUT_ELF)
	$(VVP) $(OUT_ELF)

# 编译规则（SystemVerilog-2012）
$(OUT_ELF): $(TB) $(RTL) | $(BUILD) $(WAVES)
	$(IVERILOG) -g2012 -o $@ -s $(TOP) $(TB) $(RTL)

# 针对所有 *_tb.sv 的通用规则
$(BUILD)/%_tb.out: $(TB_DIR)/%_tb.sv $(RTL) | $(BUILD) $(WAVES)
	$(IVERILOG) -g2012 -o $@ -s $*_tb $^
	@# 提示：波形将输出到 waves/ 目录（testbench 内部控制 dumpfile 名）

# 便捷目标：编译+运行当前 regfile_tb
run: regfile_test

# 目录
$(BUILD):
	mkdir -p $(BUILD)

$(WAVES):
	mkdir -p $(WAVES)

# 清理
clean:
	rm -rf $(BUILD) $(WAVES)