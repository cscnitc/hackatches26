#!/bin/bash
export VCS_HOME=/home/synopsys/tools/vcs/U-2023.03
export SNPSLMD_LICENSE_FILE=27020@14.139.1.126
# Add g++ to PATH (bundled with Synopsys tools, gcc 9.2.0)
export PATH=$VCS_HOME/bin:/home/synopsys/tools/finesim/U-2023.03/GNU/linux64/gcc-9.2.0/bin:$PATH

cd /home/nitc2026/vcs_work/morfuzz_ibex
IBEX_RTL=/home/nitc2026/vcs_work/hw/vendor/lowrisc_ibex/rtl
INC_DIR=/home/nitc2026/vcs_work/include
PRIM_DIR=/home/nitc2026/vcs_work/rtl/prim

PRIM_STUBS="$PRIM_DIR/prim_buf.sv $PRIM_DIR/prim_buf_alert_major_bus.sv $PRIM_DIR/prim_buf_alert_major_internal.sv $PRIM_DIR/prim_buf_alert_minor.sv $PRIM_DIR/prim_buf_data_wdata_intg.sv $PRIM_DIR/prim_clock_gating.sv $PRIM_DIR/prim_core_busy_flop.sv $PRIM_DIR/prim_flop.sv $PRIM_DIR/prim_ram_1p_pkg.sv $PRIM_DIR/prim_ram_1p_scr.sv $PRIM_DIR/prim_ram_1p.sv $PRIM_DIR/prim_secded_inv_39_32_dec.sv $PRIM_DIR/prim_secded_inv_39_32_enc.sv $PRIM_DIR/prim_secded_pkg.sv"

IBEX_FILES="$IBEX_RTL/ibex_pkg.sv $IBEX_RTL/ibex_register_file_ff.sv $IBEX_RTL/ibex_register_file_fpga.sv $IBEX_RTL/ibex_register_file_latch.sv $IBEX_RTL/ibex_alu.sv $IBEX_RTL/ibex_branch_predict.sv $IBEX_RTL/ibex_compressed_decoder.sv $IBEX_RTL/ibex_controller.sv $IBEX_RTL/ibex_core.sv $IBEX_RTL/ibex_counter.sv $IBEX_RTL/ibex_cs_registers.sv $IBEX_RTL/ibex_csr.sv $IBEX_RTL/ibex_decoder.sv $IBEX_RTL/ibex_dummy_instr.sv $IBEX_RTL/ibex_ex_block.sv $IBEX_RTL/ibex_fetch_fifo.sv $IBEX_RTL/ibex_id_stage.sv $IBEX_RTL/ibex_if_stage.sv $IBEX_RTL/ibex_load_store_unit.sv $IBEX_RTL/ibex_multdiv_fast.sv $IBEX_RTL/ibex_pmp.sv $IBEX_RTL/ibex_prefetch_buffer.sv $IBEX_RTL/ibex_wb_stage.sv $IBEX_RTL/ibex_top.sv"

echo "=== g++: $(which g++) ==="
echo "=== Building Ibex ==="

vcs -full64 -sverilog -timescale=1ns/1ps \
  +define+SYNTHESIS -assert svaext \
  +incdir+$PRIM_DIR +incdir+$IBEX_RTL +incdir+$INC_DIR \
  $PRIM_STUBS $IBEX_FILES $INC_DIR/dv_fcov_macros.svh \
  tb_ibex_fuzz.sv -o simv_ibex 2>&1 | tail -5

if [ -x simv_ibex ]; then
  echo "=== BUILD SUCCESS ==="
  ls -la simv_ibex
  echo "=== RUNNING ==="
  ./simv_ibex 2>&1 | tail -15
else
  echo "=== BUILD FAILED ==="
  ls -la simv_ibex 2>/dev/null
fi
