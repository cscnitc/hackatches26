# Makefile — Bug #10 differential fuzzing target for keymgr key_vld_o
# Builds on CHES with Verilator + AFL instrumentation
#
# Paths
VLT_ROOT = /tools/verilator/4.210
VERILATOR = $(VLT_ROOT)/bin/verilator
CXX       = /usr/bin/afl-clang-fast++
CXXFLAGS  = -std=c++14 -O2 -I. -Iobj_dir -I$(VLT_ROOT)/share/verilator/include -I$(VLT_ROOT)/share/verilator/include/vltstd

# Top module
TOP = top
OBJDIR = obj_dir

# Sources
SV_SRCS = keymgr_key_check_buggy.sv keymgr_key_check_fixed.sv top.sv
CPP_SRC = tb_main.cpp

# AFL env
AFL_ENV = AFL_SKIP_CPUFREQ=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1

# --- Default target ---
.PHONY: all
all: bin/fuzz_top

# --- Step 1: Verilate (translate SystemVerilog → C++) ---
$(OBJDIR)/V$(TOP).mk: $(SV_SRCS)
	mkdir -p $(OBJDIR)
	$(VERILATOR) -Wno-fatal --prefix V$(TOP) --Mdir $(OBJDIR) \
		--top-module $(TOP) --cc --compiler clang \
		$(SV_SRCS)

# --- Step 2: Build Verilated model objects (no AFL instrumentation on RTL objects) ---
# Use regular make for Verilator's generated objects
$(OBJDIR)/V$(TOP)__ALL.a: $(OBJDIR)/V$(TOP).mk
	$(MAKE) -C $(OBJDIR) -f V$(TOP).mk

# --- Step 3: Compile C++ testbench with AFL instrumentation ---
$(OBJDIR)/tb_main.o: $(CPP_SRC) $(OBJDIR)/V$(TOP).mk
	$(CXX) $(CXXFLAGS) -c $(CPP_SRC) -o $(OBJDIR)/tb_main.o

# --- Step 4: Link final AFL-instrumented binary ---
bin/fuzz_top: $(OBJDIR)/tb_main.o $(OBJDIR)/V$(TOP)__ALL.a
	mkdir -p bin
	$(CXX) $(CXXFLAGS) \
		$(OBJDIR)/tb_main.o \
		$(OBJDIR)/V$(TOP)__ALL.a \
		$(VLT_ROOT)/share/verilator/include/verilated.cpp \
		$(VLT_ROOT)/share/verilator/include/verilated_vcd_c.cpp \
		-o bin/fuzz_top

# --- Clean ---
.PHONY: clean
clean:
	rm -rf $(OBJDIR) bin

# --- Fuzz ---
.PHONY: fuzz
fuzz: bin/fuzz_top
	mkdir -p seeds out
	$(AFL_ENV) /usr/bin/afl-fuzz -i seeds -o out -t 2000 -- bin/fuzz_top

# --- Quick test (single input) ---
.PHONY: test
test: bin/fuzz_top
	@echo "=== Quick sanity test ==="
	@echo -n "Testing all-zeros (should produce no diff)..."
	@dd if=/dev/zero bs=1 count=64 2>/dev/null | bin/fuzz_top && echo " PASS (no diff)" || echo " FAIL"
	@echo -n "Testing valid=1 keys=all-0xff (key_chk=0, buggy=0, fixed=0)..."
	@printf '\x01' > /tmp/test_input.bin
	@dd if=/dev/zero bs=32 count=2 >> /tmp/test_input.bin 2>/dev/null
	@cat /tmp/test_input.bin | bin/fuzz_top && echo " PASS" || echo " FAIL"
	@rm -f /tmp/test_input.bin

# --- Seed generation ---
.PHONY: seeds
seeds:
	mkdir -p seeds
	python3 gen_seeds.py
