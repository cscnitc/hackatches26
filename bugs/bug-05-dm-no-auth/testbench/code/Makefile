OT ?= $(HOME)/workspaces/ches/new-opentitan/opentitan
DBG = $(OT)/hw/vendor/pulp_riscv_dbg/src
all:
	verilator -Wno-fatal -Wno-UNUSED -Wno-UNDRIVEN --cc \
	  +incdir+$(DBG) $(DBG)/dm_pkg.sv $(DBG)/dm_csrs.sv tb.sv --exe tb.cpp
	make -C obj_dir -f Vtb.mk
	./obj_dir/Vtb
